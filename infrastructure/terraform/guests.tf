# One random console/root password per guest (kept in the encrypted state).
# Read one with: make tf-output ARGS="-json guest_passwords"
resource "random_password" "guest" {
  for_each = merge(
    { for k, v in var.cloud_vms : "vm/${k}" => k },
    { for k, v in var.lxcs : "lxc/${k}" => k },
  )
  length  = 32
  special = false
}

module "cloud_vm" {
  source   = "./modules/cloud_vm"
  for_each = var.cloud_vms

  node_name          = each.value.node
  vm_id              = each.value.vmid
  name               = coalesce(each.value.name, each.key)
  description        = each.value.description
  tags               = each.value.tags
  cores              = each.value.cores
  memory             = each.value.memory
  disk_size          = each.value.disk_size
  vm_datastore       = var.nodes[each.value.node].vm_datastore
  snippets_datastore = var.nodes[each.value.node].file_datastore
  image_file_id      = proxmox_download_file.cloud_image["${each.value.node}/${each.value.image}"].id
  bridge             = var.nodes[each.value.node].bridge
  mac                = try(var.guest_network[each.key].mac, null)
  ip                 = var.guest_network[each.key].ip
  prefix_length      = var.network.prefix_length
  gateway            = var.network.gateway
  dns_servers        = var.network.dns_servers
  username           = each.value.username
  password           = random_password.guest["vm/${each.key}"].result
  ssh_keys           = local.ssh_keys
  timezone           = var.timezone
  machine            = each.value.hardware.machine
  cpu_type           = each.value.hardware.cpu_type
  scsi_hardware      = each.value.hardware.scsi_hardware
  iothread           = each.value.hardware.iothread
  vendor_data        = each.value.hardware.vendor_data
  startup_order      = each.value.startup_order
  protection         = var.protect_guests
}

module "appliance_vm" {
  source   = "./modules/appliance_vm"
  for_each = var.appliance_vms

  node_name     = each.value.node
  vm_id         = each.value.vmid
  name          = coalesce(each.value.name, each.key)
  description   = each.value.description
  tags          = each.value.tags
  cores         = each.value.cores
  memory        = each.value.memory
  disk_size     = each.value.disk_size
  vm_datastore  = var.nodes[each.value.node].vm_datastore
  image_file_id = proxmox_download_file.appliance_image["${each.value.node}/${each.value.image}"].id
  machine       = each.value.hardware.machine
  cpu_type      = each.value.hardware.cpu_type
  bridge        = var.nodes[each.value.node].bridge
  mac           = try(var.guest_network[each.key].mac, null)
  startup_order = each.value.startup_order
  protection    = var.protect_guests
}

module "lxc" {
  source   = "./modules/lxc"
  for_each = var.lxcs

  node_name        = each.value.node
  vm_id            = each.value.vmid
  hostname         = each.key
  description      = each.value.description
  tags             = each.value.tags
  cores            = each.value.cores
  memory           = each.value.memory
  swap             = each.value.swap
  disk_size        = each.value.disk_size
  datastore        = var.nodes[each.value.node].vm_datastore
  template_file_id = proxmox_download_file.lxc_template["${each.value.node}/${each.value.template}"].id
  keyctl           = each.value.keyctl
  bridge           = var.nodes[each.value.node].bridge
  mac              = try(var.guest_network[each.key].mac, null)
  ip               = var.guest_network[each.key].ip
  prefix_length    = var.network.prefix_length
  gateway          = var.network.gateway
  dns_servers      = var.network.dns_servers
  password         = random_password.guest["lxc/${each.key}"].result
  ssh_keys         = local.ssh_keys
  startup_order    = each.value.startup_order
  protection       = var.protect_guests
}
