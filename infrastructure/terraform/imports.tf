# Adopt guests that already exist on the nodes instead of creating them.
# Enable with `adopt_existing_guests = true` in terraform.tfvars, then review `make tf-plan`:
# it must show "0 to destroy" and only intended in-place changes.
# Imports are generated only in the default (production) workspace, so the scratch `test`
# workspace can never take ownership of production guests.
locals {
  adopt = var.adopt_existing_guests && terraform.workspace == "default"
}

import {
  for_each = local.adopt ? var.appliance_vms : {}
  to       = module.appliance_vm[each.key].proxmox_virtual_environment_vm.this
  id       = "${each.value.node}/${each.value.vmid}"
}

import {
  for_each = local.adopt ? var.cloud_vms : {}
  to       = module.cloud_vm[each.key].proxmox_virtual_environment_vm.this
  id       = "${each.value.node}/${each.value.vmid}"
}

import {
  for_each = local.adopt ? var.lxcs : {}
  to       = module.lxc[each.key].proxmox_virtual_environment_container.this
  id       = "${each.value.node}/${each.value.vmid}"
}
