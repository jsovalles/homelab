variable "state_passphrase" {
  description = "OpenTofu state encryption passphrase (from SOPS via Makefile)"
  type        = string
  sensitive   = true
}

# ----------------------------------------------------------------- cluster
variable "nodes" {
  description = "Proxmox VE nodes (storage/bridge). Addresses live in node_addresses (site.sops.yaml)."
  type = map(object({
    vm_datastore   = optional(string, "local-lvm") # disks (use a ZFS pool on new nodes for replication/HA)
    file_datastore = optional(string, "local")     # images, templates, snippets
    bridge         = optional(string, "vmbr0")
  }))
}

variable "api_node" {
  description = "Node whose API endpoint is used (any cluster member works)"
  type        = string
  default     = "pve1"
}

variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_file" {
  description = "Key used by the provider for SSH operations (falls back to ssh-agent)"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "timezone" {
  type    = string
  default = "America/Bogota"
}

# ----------------------------------------------------------------- site data
# Environment-identifying values come from infrastructure/ansible/inventory/group_vars/all/
# site.sops.yaml (exported as TF_VAR_* by scripts/tofu.sh) – never from files in git.
variable "node_addresses" {
  description = "Management IP of every Proxmox node (key = node name)"
  type        = map(string)
  sensitive   = true

  validation {
    condition     = alltrue([for n in keys(var.nodes) : contains(keys(var.node_addresses), n)])
    error_message = "Every node in var.nodes needs node_addresses.<node> in site.sops.yaml."
  }
}

variable "network" {
  description = "Static addressing shared by all guests"
  type = object({
    prefix_length = number
    gateway       = string
    # The docker VM runs AdGuard; guests must NOT depend on it to boot
    dns_servers = list(string)
  })
  sensitive = true
}

variable "guest_network" {
  description = "Per-guest ip (cloud VMs, LXCs) and optional pinned mac (key = guest key)"
  type = map(object({
    ip  = optional(string)
    mac = optional(string)
  }))
  sensitive = true
  default   = {}

  validation {
    condition = alltrue([
      for k in concat(keys(var.cloud_vms), keys(var.lxcs)) : try(var.guest_network[k].ip, null) != null
    ])
    error_message = "Every cloud VM and LXC needs guest_network.<key>.ip in site.sops.yaml."
  }
  validation {
    condition     = length(compact([for g in values(var.guest_network) : g.ip])) == length(distinct(compact([for g in values(var.guest_network) : g.ip])))
    error_message = "Duplicate IPs in guest_network (site.sops.yaml)."
  }
  validation {
    condition     = alltrue([for g in values(var.guest_network) : g.ip == null || can(cidrhost("${g.ip}/32", 0))])
    error_message = "guest_network IPs must be plain IPv4 addresses (no prefix)."
  }
}

# ----------------------------------------------------------------- images
# Downloaded only to the nodes that host a guest using them.
variable "cloud_images" {
  description = <<-EOT
    Cloud-init capable images (imported as VM disks). Either pin url/file_name/checksum, or set
    debian_latest = "<release>/<image>" (e.g. "trixie/debian-13-genericcloud-amd64") to follow the
    newest Debian build; its checksum is read from Debian's SHA512SUMS on every plan.
  EOT
  type = map(object({
    url                = optional(string)
    file_name          = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string, "sha256")
    debian_latest      = optional(string)
  }))
  default = {}
}

variable "appliance_images" {
  description = <<-EOT
    Vendor disk images booted as-is (stored as content 'iso', .img). Either pin url/file_name/checksum,
    or set haos_latest = true to follow the latest stable Home Assistant OS release (GitHub API).
  EOT
  type = map(object({
    url                     = optional(string)
    file_name               = optional(string) # must end in .img
    checksum                = optional(string)
    checksum_algorithm      = optional(string, "sha256")
    decompression_algorithm = optional(string) # "zst" also handles .xz (zstd -d)
    haos_latest             = optional(bool, false)
  }))
  default = {}
}

variable "lxc_templates" {
  description = <<-EOT
    LXC templates. Either pin url/checksum, or set pve_latest = "<package>" (e.g. "debian-13-standard")
    to follow the newest version in Proxmox's template index.
  EOT
  type = map(object({
    url                = optional(string)
    checksum           = optional(string)
    checksum_algorithm = optional(string, "sha512")
    pve_latest         = optional(string)
  }))
  default = {}
}

# ----------------------------------------------------------------- guests
variable "cloud_vms" {
  description = "Cloud-init VMs (key = guest id, name defaults to key)"
  type = map(object({
    node          = string
    vmid          = number
    name          = optional(string)
    image         = string # key of cloud_images
    cores         = number
    memory        = number
    disk_size     = number
    username      = optional(string, "ansible") # cloud-init user (passwordless sudo)
    tags          = optional(list(string), [])
    description   = optional(string, "")
    startup_order = optional(number, 2)
    # Hardware overrides, mainly for adopted guests (keep what they run today)
    hardware = optional(object({
      machine       = optional(string, "q35") # "default" = leave Proxmox's default (i440fx)
      cpu_type      = optional(string, "x86-64-v2-AES")
      scsi_hardware = optional(string, "virtio-scsi-single")
      iothread      = optional(bool, true)
      vendor_data   = optional(bool, true)
    }), {})
    ansible = optional(object({ groups = list(string), vars = optional(any, {}) }), { groups = [] })
  }))
  default = {}

  validation {
    condition     = alltrue([for v in values(var.cloud_vms) : contains(keys(var.nodes), v.node) && contains(keys(var.cloud_images), v.image)])
    error_message = "Every cloud VM must use a node from var.nodes and an image from var.cloud_images."
  }
}

variable "appliance_vms" {
  description = "VMs booting a vendor image without cloud-init (IP configured inside the appliance)"
  type = map(object({
    node          = string
    vmid          = number
    name          = optional(string)
    image         = string # key of appliance_images
    cores         = number
    memory        = number
    disk_size     = number
    tags          = optional(list(string), [])
    description   = optional(string, "")
    startup_order = optional(number, 1)
    hardware = optional(object({
      machine  = optional(string, "q35")
      cpu_type = optional(string, "x86-64-v2-AES")
    }), {})
    ansible = optional(object({ groups = list(string), vars = optional(any, {}) }), { groups = [] })
  }))
  default = {}

  validation {
    condition     = alltrue([for v in values(var.appliance_vms) : contains(keys(var.nodes), v.node) && contains(keys(var.appliance_images), v.image)])
    error_message = "Every appliance VM must use a node from var.nodes and an image from var.appliance_images."
  }
}

variable "lxcs" {
  description = "LXC containers (key = hostname)"
  type = map(object({
    node          = string
    vmid          = number
    template      = string # key of lxc_templates
    cores         = number
    memory        = number
    swap          = number
    disk_size     = number
    tags          = optional(list(string), [])
    description   = optional(string, "")
    startup_order = optional(number, 3)
    keyctl        = optional(bool, false) # community-script containers have it on
    ansible       = optional(object({ groups = list(string), vars = optional(any, {}) }), { groups = [] })
  }))
  default = {}

  validation {
    condition     = alltrue([for v in values(var.lxcs) : contains(keys(var.nodes), v.node) && contains(keys(var.lxc_templates), v.template)])
    error_message = "Every LXC must use a node from var.nodes and a template from var.lxc_templates."
  }
  validation {
    condition = length(concat(
      [for v in values(var.cloud_vms) : v.vmid], [for v in values(var.appliance_vms) : v.vmid], [for v in values(var.lxcs) : v.vmid]
      )) == length(distinct(concat(
        [for v in values(var.cloud_vms) : v.vmid], [for v in values(var.appliance_vms) : v.vmid], [for v in values(var.lxcs) : v.vmid]
    )))
    error_message = "Duplicate VMIDs across cloud_vms, appliance_vms and lxcs."
  }
}

variable "protect_guests" {
  description = "Set the Proxmox protection flag on every guest (blocks accidental deletion)"
  type        = bool
  default     = true
}

variable "adopt_existing_guests" {
  description = "Import the guests that already exist on the nodes (production workspace only)"
  type        = bool
  default     = false
}

variable "backup_job" {
  description = "vzdump schedule for this environment's guests (storage: use the NAS/PBS once it exists – `local` is the same disk)"
  type = object({
    id        = optional(string, "homelab-daily")
    enabled   = optional(bool, true)
    storage   = string
    schedule  = string
    keep_last = number
  })
  default = null
}
