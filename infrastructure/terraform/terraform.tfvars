# Production guests (rebuilt from scratch on Debian 13; adopt_existing_guests is no longer needed).
# The `test` workspace overrides guests via envs/test.tfvars.
# Adding a node or a guest is a change to this file only.

nodes = {
  "pve-01" = {
    vm_datastore = "local-zfs" # ZFS (rpool/data): supports replication/HA
  }
}

# ----------------------------------------------------------------- images
# Images track the latest stable release (resolved + checksum-verified at plan time).
# To pin one instead, replace the *_latest field with url/file_name/checksum.
cloud_images = {
  "debian-13" = { debian_latest = "trixie/debian-13-genericcloud-amd64" }
}

appliance_images = {
  "haos" = { haos_latest = true }
}

lxc_templates = {
  "debian-13" = { pve_latest = "debian-13-standard" }
}

# ----------------------------------------------------------------- guests
appliance_vms = {
  haos = {
    node        = "pve-01"
    vmid        = 101
    image       = "haos"
    cores       = 1
    memory      = 4096
    disk_size   = 32
    tags        = ["haos"]
    description = "Home Assistant OS – restore data from an HA backup"
    ansible     = { groups = ["homeassistant"] }
  }
}

cloud_vms = {
  docker = {
    node        = "pve-01"
    vmid        = 100
    image       = "debian-13"
    cores       = 2
    memory      = 4096
    disk_size   = 39
    tags        = ["docker"]
    description = "Docker host for the docker/ stack"
    ansible     = { groups = ["docker_hosts"] }
  }
}

lxcs = {
  myspeed = {
    ansible   = { groups = ["lxc_apps"], vars = { lxc_app = "myspeed" } }
    node      = "pve-01"
    vmid      = 102
    template  = "debian-13"
    cores     = 1
    memory    = 1024
    swap      = 512
    disk_size = 4
    tags      = ["tracking"]
  }
  gotify = {
    ansible   = { groups = ["lxc_apps"], vars = { lxc_app = "gotify" } }
    node      = "pve-01"
    vmid      = 103
    template  = "debian-13"
    cores     = 1
    memory    = 512
    swap      = 512
    disk_size = 2
    tags      = ["notification"]
  }
}

backup_job = {
  storage   = "local"
  schedule  = "02:00"
  keep_last = 7
}
