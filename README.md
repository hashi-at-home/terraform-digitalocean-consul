# terraform-digitalocean-consul
Terraform module for Hashicorp Consul on Digital Ocean

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 4.50.0 |
| <a name="requirement_consul"></a> [consul](#requirement\_consul) | 2.21.0 |
| <a name="requirement_digitalocean"></a> [digitalocean](#requirement\_digitalocean) | 2.47.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.0.6 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | 4.5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 4.50.0 |
| <a name="provider_digitalocean"></a> [digitalocean](#provider\_digitalocean) | 2.47.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.6 |
| <a name="provider_vault"></a> [vault](#provider\_vault) | 4.5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [vault_generic_secret.do_token](https://registry.terraform.io/providers/hashicorp/vault/4.5.0/docs/data-sources/generic_secret) | data source |
| [vault_generic_secret.hashiathome](https://registry.terraform.io/providers/hashicorp/vault/4.5.0/docs/data-sources/generic_secret) | data source |
| [vault_generic_secret.ssh_key](https://registry.terraform.io/providers/hashicorp/vault/4.5.0/docs/data-sources/generic_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_consul_ports"></a> [consul\_ports](#input\_consul\_ports) | Ports to expose Consul on. See https://www.consul.io/docs/install/ports | `map(number)` | <pre>{<br/>  "dns": 8600,<br/>  "http": 8500,<br/>  "serf-lan": 8301,<br/>  "server": 8300<br/>}</pre> | no |
| <a name="input_home_base_ip"></a> [home\_base\_ip](#input\_home\_base\_ip) | Tailscale IP | `string` | n/a | yes |
| <a name="input_lb_name"></a> [lb\_name](#input\_lb\_name) | Name of the load balancer | `string` | `"consul-lb"` | no |
| <a name="input_lb_size_unit"></a> [lb\_size\_unit](#input\_lb\_size\_unit) | Size unit for the load balancer | `number` | `1` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | Name of the SSH key to assign to this project | `string` | `"consul-key"` | no |
| <a name="input_ssh_key_path"></a> [ssh\_key\_path](#input\_ssh\_key\_path) | Path to the SSH key to use | `string` | `"~/.ssh/dokey.pub"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC internal CIDR for the consul cluster | `string` | `"10.10.20.0/24"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->