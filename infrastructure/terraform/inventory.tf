# Ansible inventory rendered from the same variables that create the guests,
# so VMIDs, IPs and nodes are defined exactly once (terraform.tfvars).
# `make inventory` writes it to infrastructure/ansible/inventory/<env>.yml
# (evaluated with `tofu console`, no state needed).
locals {
  inventory_hosts = merge(
    { for k, v in var.cloud_vms : k => {
      groups = v.ansible.groups
      vars   = merge({ ansible_host = var.guest_network[k].ip, ansible_user = v.username }, v.ansible.vars)
    } },
    { for k, v in var.appliance_vms : k => {
      groups = v.ansible.groups
      vars   = merge({ proxmox_node = v.node, proxmox_vmid = v.vmid }, v.ansible.vars)
    } },
    { for k, v in var.lxcs : k => {
      groups = v.ansible.groups
      vars   = merge({ proxmox_node = v.node, proxmox_vmid = v.vmid }, v.ansible.vars)
    } },
  )

  inventory_groups = distinct(flatten([for h in local.inventory_hosts : h.groups]))

  ansible_inventory = {
    all = {
      # Site-wide facts for templates (Traefik routes, .env, monitoring) – never in git
      vars = {
        lan_gateway       = var.network.gateway
        lan_prefix_length = var.network.prefix_length
        lan_dns_servers   = var.network.dns_servers
        lan_cidr          = "${cidrhost("${var.network.gateway}/${var.network.prefix_length}", 0)}/${var.network.prefix_length}"
        guest_ips         = { for k, v in var.guest_network : k => v.ip if v.ip != null }
        node_ips          = var.node_addresses
      }
      children = merge(
        { proxmox = { hosts = { for n, v in var.nodes : n => { ansible_host = var.node_addresses[n] } } } },
        { for g in local.inventory_groups : g => {
          hosts = { for name, h in local.inventory_hosts : name => h.vars if contains(h.groups, g) }
        } },
      )
    }
  }
}

output "ansible_inventory" {
  value     = local.ansible_inventory
  sensitive = true
}
