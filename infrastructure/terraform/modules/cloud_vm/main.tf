terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

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
variable "snippets_datastore" { type = string }
variable "image_file_id" {
  description = "Cloud image (content type import) to import as the boot disk"
  type        = string
}
variable "bridge" { type = string }
variable "mac" {
  type    = string
  default = null
}
variable "ip" {
  description = "IPv4 address without prefix"
  type        = string
}
variable "prefix_length" { type = number }
variable "gateway" { type = string }
variable "dns_servers" { type = list(string) }
variable "username" { type = string }
variable "password" {
  type      = string
  sensitive = true
}
variable "ssh_keys" { type = list(string) }
variable "timezone" { type = string }
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
variable "scsi_hardware" {
  type    = string
  default = "virtio-scsi-single"
}
variable "iothread" {
  type    = bool
  default = true
}
variable "vendor_data" {
  description = "Attach the cloud-init vendor snippet (guest agent + python3). false for adopted VMs."
  type        = bool
  default     = true
}
variable "protection" {
  description = "Proxmox protection flag: blocks deletion of the guest and its disks"
  type        = bool
  default     = false
}
variable "startup_order" {
  type    = number
  default = 2
}

# Minimal cloud-init: guest agent + python3 for Ansible. Everything else is Ansible.
resource "proxmox_virtual_environment_file" "vendor" {
  count = var.vendor_data ? 1 : 0

  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "${var.name}-vendor.yaml"
    data      = <<-EOF
      #cloud-config
      timezone: ${var.timezone}
      package_update: true
      packages:
        - qemu-guest-agent
        - python3
      disable_root: false
      ssh_pwauth: false
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOF
  }
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
  scsi_hardware   = var.scsi_hardware
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
    floating  = var.memory
  }

  efi_disk {
    datastore_id = var.vm_datastore
    type         = "4m"
  }

  disk {
    datastore_id = var.vm_datastore
    import_from  = var.image_file_id
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = var.iothread
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge      = var.bridge
    mac_address = var.mac
  }

  serial_device {}

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.vm_datastore
    interface    = "ide2"
    ip_config {
      ipv4 {
        address = "${var.ip}/${var.prefix_length}"
        gateway = var.gateway
      }
    }
    dns {
      servers = var.dns_servers
    }
    user_account {
      username = var.username
      password = var.password
      keys     = var.ssh_keys
    }
    vendor_data_file_id = var.vendor_data ? proxmox_virtual_environment_file.vendor[0].id : null
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      disk[0].import_from,
    ]
  }
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
