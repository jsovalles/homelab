output "guests" {
  description = "vmid / node / ip of every guest"
  sensitive   = true
  value = merge(
    { for k, v in var.cloud_vms : k => { vmid = v.vmid, node = v.node, ip = var.guest_network[k].ip } },
    { for k, v in var.appliance_vms : k => { vmid = v.vmid, node = v.node, ip = null } },
    { for k, v in var.lxcs : k => { vmid = v.vmid, node = v.node, ip = var.guest_network[k].ip } },
  )
}

output "guest_passwords" {
  description = "Per-guest root/console passwords"
  value       = { for k, v in random_password.guest : k => v.result }
  sensitive   = true
}
