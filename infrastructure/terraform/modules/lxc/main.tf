terraform {
  required_version = ">= 1.6" # OpenTofu

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.115.0" # exact pin lives in the root module
    }
  }
}

variable "node_name" { type = string }
variable "vm_id" { type = number }
variable "hostname" { type = string }
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
variable "swap" { type = number }
variable "disk_size" { type = number }
variable "datastore" { type = string }
variable "template_file_id" { type = string }
variable "os_type" {
  type    = string
  default = "debian"
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
variable "password" {
  type      = string
  sensitive = true
}
variable "ssh_keys" { type = list(string) }
variable "console_mode" {
  description = "Proxmox console mode: tty = login prompt; shell = root shell without login (avoid)"
  type        = string
  default     = "tty"
}
variable "keyctl" {
  description = "keyctl feature (set by community-scripts). Only root@pam may change it, so adopted containers keep their value."
  type        = bool
  default     = false
}
variable "protection" {
  description = "Proxmox protection flag: blocks deletion of the guest and its disks"
  type        = bool
  default     = false
}
variable "startup_order" {
  type    = number
  default = 3
}

resource "proxmox_virtual_environment_container" "this" {
  protection    = var.protection
  vm_id         = var.vm_id
  node_name     = var.node_name
  tags          = concat(var.tags, ["terraform"])
  description   = var.description
  unprivileged  = true
  start_on_boot = true

  startup {
    order = var.startup_order
  }

  console {
    type      = var.console_mode
    tty_count = 2
  }

  features {
    nesting = true
    keyctl  = var.keyctl
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.datastore
    size         = var.disk_size
  }

  network_interface {
    name        = "eth0"
    bridge      = var.bridge
    mac_address = var.mac
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  initialization {
    hostname = var.hostname
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
      password = var.password
      keys     = var.ssh_keys
    }
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
      operating_system[0].template_file_id,
    ]
  }
}

output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}
