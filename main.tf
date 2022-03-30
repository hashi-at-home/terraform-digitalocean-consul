terraform {
  required_version = ">= 1.1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
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

data "vault_generic_secret" "do_token" {
  path = "kv/do"
}

provider "digitalocean" {
  token             = data.vault_generic_secret.do_token.data["token"]
  spaces_access_id  = data.vault_generic_secret.do_token.data["access_key_hashi_at_home"]
  spaces_secret_key = data.vault_generic_secret.do_token.data["secret_key_hashi_at_home"]
}

module "test-space" {
  selected_region = "🇳🇱"
  bucket_name     = "terraform-backend-hah"
  source          = "github.com/hashi-at-home/tfmod-do-space"
}

# Digital Ocean VPC for droplets
resource "digitalocean_vpc" "vpc" {
  name        = "terraform-vpc-hah"
  region      = "ams3"
  description = "VPC for hashi at home"
  ip_range    = "10.10.10.0/24"
}



resource "digitalocean_ssh_key" "test_instance" {
  name       = var.ssh_key_name
  public_key = file(var.ssh_key_path)
}

resource "digitalocean_loadbalancer" "consul" {
  name      = var.lb_name
  size_unit = var.lb_size_unit
  region    = "ams3"
  vpc_uuid  = digitalocean_vpc.vpc.id
  forwarding_rule {
    entry_port     = "80"
    entry_protocol = "http"

    target_port     = "8500"
    target_protocol = "http"
  }

  healthcheck {
    port     = 8500
    protocol = "http"
    path     = "/v1/health/service/consul"
  }

}
