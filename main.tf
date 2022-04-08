terraform {
  required_version = ">= 1.1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "3.11.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "2.15.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "= 2.19.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.4.0"
    }
  }

  backend "consul" {
    path = "do/hah-consul-cluster"
  }
}

variable "ssh_key_name" {
  type        = string
  description = "Name of the SSH key to assign to this project"
  default     = "consul-key"
}

variable "ssh_key_path" {
  type        = string
  description = "Path to the SSH key to use"
  default     = "~/.ssh/dokey.pub"
}

variable "lb_name" {
  type        = string
  description = "Name of the load balancer"
  default     = "consul-lb"
}

variable "lb_size_unit" {
  type        = number
  description = "Size unit for the load balancer"
  default     = 1
}

variable "consul_ports" {
  type        = map(number)
  description = "Ports to expose Consul on. See https://www.consul.io/docs/install/ports"
  default = {
    "dns"      = 8600
    "http"     = 8500
    "serf_lan" = 8301
    "server"   = 8300
  }
}
variable "home_base_ip" {
  description = "Tailscale IP"
  type        = string
}

data "vault_generic_secret" "hashiathome" {
  path = "kv/hashiathome"
}

data "vault_generic_secret" "do_token" {
  path = "digitalocean/tokens"
}

# Look up ssh key secret in vault
data "vault_generic_secret" "ssh_key" {
  path = "digitalocean/ssh_key"
}

data "cloudflare_zone" "hashiathome" {
  name = "hashiatho.me"
}
provider "digitalocean" {
  token = data.vault_generic_secret.do_token.data["terraform"]
}

provider "cloudflare" {
  api_token            = data.vault_generic_secret.hashiathome.data["cloudflare_api_token"]
  api_user_service_key = data.vault_generic_secret.hashiathome.data["cloudflare_origin_ca_key"]
}

# Generate Certificate request
resource "tls_private_key" "csr" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# generate certificate request
resource "tls_cert_request" "consul" {
  key_algorithm   = tls_private_key.csr.algorithm
  private_key_pem = tls_private_key.csr.private_key_pem

  subject {
    common_name  = "consul-${terraform.workspace}.hashiatho.me"
    organization = "Hashi At Home"

  }
}

# Get cert from cloudflare
resource "cloudflare_origin_ca_certificate" "consul" {
  csr                = tls_cert_request.consul.cert_request_pem
  hostnames          = ["consul-${terraform.workspace}.hashiatho.me"]
  request_type       = "origin-rsa"
  requested_validity = 7
}

resource "digitalocean_certificate" "cert" {
  name              = "cloudflare-origin"
  type              = "custom"
  private_key       = tls_private_key.csr.private_key_pem
  leaf_certificate  = cloudflare_origin_ca_certificate.consul.certificate
  certificate_chain = cloudflare_origin_ca_certificate.consul.certificate
}

# Digital Ocean VPC for droplets
resource "digitalocean_vpc" "vpc" {
  name        = "terraform-consul-vpc"
  region      = "ams3"
  description = "VPC for Consul"
  ip_range    = "10.10.20.0/24"
}

data "digitalocean_ssh_key" "test" {
  name = "test-instances"
}

resource "digitalocean_loadbalancer" "consul" {
  name        = var.lb_name
  size_unit   = var.lb_size_unit
  region      = "ams3"
  vpc_uuid    = digitalocean_vpc.vpc.id
  droplet_tag = "consul-server"
  forwarding_rule {
    entry_port     = "80"
    entry_protocol = "http"

    target_port     = "8500"
    target_protocol = "http"
  }

  # HTTPS forwarding rule
  forwarding_rule {
    entry_port     = "443"
    entry_protocol = "https"

    target_port     = 8500
    target_protocol = "http"

    certificate_name = digitalocean_certificate.cert.name
  }

  # healthcheck {
  #   port     = 8500
  #   protocol = "http"
  #   path     = "/v1/health/service/consul"
  # }

  healthcheck {
    port     = 8300
    protocol = "tcp"
    # path     = "/"
  }

}

resource "cloudflare_record" "consul" {
  zone_id = data.cloudflare_zone.hashiathome.id
  name    = "consul-${terraform.workspace}"
  value   = digitalocean_loadbalancer.consul.ip
  type    = "A"
  ttl     = 60

}

data "digitalocean_image" "consul_server" {
  name = "consul-server-droplet"
}

# Create consul server cluster with 3 nodes
resource "digitalocean_droplet" "consul_server" {
  count             = 3
  name              = "consul-server-${terraform.workspace}-${count.index}"
  image             = data.digitalocean_image.consul_server.id
  region            = "ams3"
  ssh_keys          = [data.digitalocean_ssh_key.test.id]
  size              = "s-1vcpu-1gb"
  backups           = false
  monitoring        = false
  vpc_uuid          = digitalocean_vpc.vpc.id
  tags              = ["consul-server"]
  graceful_shutdown = false
}

# Add droplet firewalls
resource "digitalocean_firewall" "droplet_firewall" {
  name        = "consul-servers-firewall"
  droplet_ids = digitalocean_droplet.consul_server.*.id

  # For now, allow ssh from anywhere, until we get Tailscale VPN and a bastion
  inbound_rule {
    protocol   = "tcp"
    port_range = "22"
    # My tailscale address
    source_addresses = [var.home_base_ip]
  }

  # Allow communication on the internal IP range between consul servers
  # and the load balancer
  inbound_rule {
    protocol   = "tcp"
    port_range = "8500"

    source_addresses          = digitalocean_droplet.consul_server.*.id
    source_load_balancer_uids = [digitalocean_loadbalancer.consul.id]
  }

  # Allow all outgoing traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
