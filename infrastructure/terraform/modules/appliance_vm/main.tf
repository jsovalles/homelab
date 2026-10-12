terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# A VM that boots straight from a vendor disk image without cloud-init
# (Home Assistant OS today; OPNsense, TrueNAS… later).
variable "node_name" { type = string }
variable "vm_id" { type = number }
variable "name" { type = string }
variable "description" {
  type    = string
  default = ""
}
variable "tags" {
  type    = list(string)
  default = []
}
variable "cores" { type = number }
variable "memory" { type = number }
variable "disk_size" { type = number }
variable "vm_datastore" { type = string }
variable "image_file_id" {
  description = "Disk image (content type iso, .img) imported as scsi0"
  type        = string
}
variable "disk_cache" {
  type    = string
  default = "writethrough"
}
variable "bridge" { type = string }
variable "mac" {
  type    = string
  default = null
}
variable "machine" {
  description = "Chipset: q35 for new guests; \"default\" keeps Proxmox's default (i440fx) on adopted ones"
  type        = string
  default     = "q35"
}
variable "cpu_type" {
  description = "x86-64-v2-AES runs on any modern Intel/AMD host and allows live migration between them"
  type        = string
  default     = "x86-64-v2-AES"
}
variable "protection" {
  description = "Proxmox protection flag: blocks deletion of the guest and its disks"
  type        = bool
  default     = false
}
variable "startup_order" {
  type    = number
  default = 1
}

resource "proxmox_virtual_environment_vm" "this" {
  protection      = var.protection
  vm_id           = var.vm_id
  name            = var.name
  node_name       = var.node_name
  tags            = concat(var.tags, ["terraform"])
  description     = var.description
  on_boot         = true
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = var.machine == "default" ? null : var.machine
  scsi_hardware   = "virtio-scsi-pci"
  tablet_device   = false

  startup {
    order    = var.startup_order
    up_delay = 60
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  efi_disk {
    datastore_id      = var.vm_datastore
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    datastore_id = var.vm_datastore
    file_id      = var.image_file_id
    interface    = "scsi0"
    size         = var.disk_size
    cache        = var.disk_cache
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge      = var.bridge
    mac_address = var.mac
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # Appliances update themselves; a new image must not recreate the VM
    ignore_changes = [disk[0].file_id, description]
  }
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
