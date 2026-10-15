# Unit tests for modules/lxc (mock provider: no Proxmox, no secrets). Run: make tf-test
mock_provider "proxmox" {}

variables {
  node_name        = "pve-01"
  vm_id            = 9300
  hostname         = "unit-lxc"
  tags             = ["app"]
  cores            = 1
  memory           = 512
  swap             = 256
  disk_size        = 4
  datastore        = "local-zfs"
  template_file_id = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
  bridge           = "vmbr0"
  ip               = "192.0.2.30"
  prefix_length    = 24
  gateway          = "192.0.2.1"
  dns_servers      = ["192.0.2.1"]
  password         = "unit-test-password"
  ssh_keys         = ["ssh-ed25519 AAAA unit"]
}

run "defaults" {
  command = plan
  module {
    source = "./modules/lxc"
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.unprivileged == true
    error_message = "Containers are unprivileged."
  }
  assert {
    condition     = proxmox_virtual_environment_container.this.console[0].type == "tty"
    error_message = "The console asks for a login (tty), it does not open a root shell."
  }
  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].nesting == true && proxmox_virtual_environment_container.this.features[0].keyctl == false
    error_message = "nesting is on (systemd in Debian 13), keyctl off unless requested."
  }
  assert {
    condition     = proxmox_virtual_environment_container.this.initialization[0].ip_config[0].ipv4[0].address == "192.0.2.30/24"
    error_message = "Static address is ip/prefix_length."
  }
  assert {
    condition     = contains(proxmox_virtual_environment_container.this.tags, "terraform") && contains(proxmox_virtual_environment_container.this.tags, "app")
    error_message = "The terraform tag is added to the guest's own tags."
  }
  assert {
    condition     = proxmox_virtual_environment_container.this.startup[0].order == 3 && proxmox_virtual_environment_container.this.start_on_boot == true
    error_message = "LXCs start on boot, after the VMs (order 3)."
  }
}

run "adopted_community_script_container" {
  command = plan
  module {
    source = "./modules/lxc"
  }
  variables {
    keyctl     = true
    protection = true
  }

  assert {
    condition     = proxmox_virtual_environment_container.this.features[0].keyctl == true
    error_message = "keyctl is kept for adopted community-script containers."
  }
  assert {
    condition     = proxmox_virtual_environment_container.this.protection == true
    error_message = "The protection flag is passed through."
  }
}
