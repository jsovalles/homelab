# Scratch environment used by `make test` (workspace "test").
# Spare VMIDs 91xx and IPs from the test range in docs/network.md;
# no MAC pinning, no backup job. Images/nodes come from terraform.tfvars.

appliance_vms = {
  haos = {
    node      = "pve-01"
    vmid      = 9100
    name      = "test-haos"
    image     = "haos"
    cores     = 1
    memory    = 2048
    disk_size = 32
    tags      = ["test"]
    ansible   = { groups = ["homeassistant"] }
  }
}

cloud_vms = {
  docker = {
    node      = "pve-01"
    vmid      = 9102
    name      = "test-docker"
    image     = "debian-13"
    cores     = 2
    memory    = 2048 # ~1.2 GB in use (prod); keeps make test within pve-01 RAM
    disk_size = 20
    tags      = ["test"]
    # Test-only overrides live in group_vars/docker_test.yml (a group that exists only here).
    # Keeps ansible.vars out of cloud_vms: Terraform needs one common type for all VMs' vars.
    ansible = { groups = ["docker_hosts", "docker_test"] }
  }
  test-hermes = {
    node      = "pve-01"
    vmid      = 9106
    image     = "debian-13"
    cores     = 2
    memory    = 2048 # the installer's Node build is OOM-killed at 1.5 GB
    disk_size = 20
    tags      = ["test"]
    # Gateway stays off (role default) and group_vars/hermes_test.yml drops the production keys
    ansible = { groups = ["hermes_hosts", "hermes_test"] }
  }
}

lxcs = {
  test-myspeed = {
    ansible   = { groups = ["lxc_apps"], vars = { lxc_app = "myspeed" } }
    node      = "pve-01"
    vmid      = 9104
    template  = "debian-13"
    cores     = 1
    memory    = 1024
    swap      = 512
    disk_size = 4
    tags      = ["test"]
  }
  test-gotify = {
    ansible   = { groups = ["lxc_apps"], vars = { lxc_app = "gotify" } }
    node      = "pve-01"
    vmid      = 9105
    template  = "debian-13"
    cores     = 1
    memory    = 512
    swap      = 512
    disk_size = 2
    tags      = ["test"]
  }
}

backup_job     = null
protect_guests = false
