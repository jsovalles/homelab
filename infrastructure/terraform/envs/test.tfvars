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
    memory    = 4096
    disk_size = 20
    tags      = ["test"]
    ansible = {
      groups = ["docker_hosts"]
      vars = {
        # Real values from SOPS, but nothing with outside effects:
        # traefik without ACME (no TXT records / certificates on the real domain),
        # no duckdns (public DNS), no watchtower (Discord)
        traefik_acme_enabled = false
        homelab_compose_services = ["traefik", "unbound", "adguardhome", "wg-easy", "tinyauth", "beszel", "beszel-agent",
        "bentopdf", "uptime-kuma"]
      }
    }
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
