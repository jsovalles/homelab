# Unit tests for modules/cloud_vm (mock provider: no Proxmox, no secrets). Run: make tf-test
mock_provider "proxmox" {
  # the provider validates file ids, so the mocked snippet needs a realistic one
  mock_resource "proxmox_virtual_environment_file" {
    defaults = {
      id = "local:snippets/unit-vm-vendor.yaml"
    }
  }
}

variables {
  node_name          = "pve-01"
  vm_id              = 9200
  name               = "unit-vm"
  tags               = ["docker"]
  cores              = 2
  memory             = 2048
  disk_size          = 20
  vm_datastore       = "local-zfs"
  snippets_datastore = "local"
  image_file_id      = "local:import/debian.qcow2"
  bridge             = "vmbr0"
  ip                 = "192.0.2.20"
  prefix_length      = 24
  gateway            = "192.0.2.1"
  dns_servers        = ["192.0.2.1"]
  username           = "ansible"
  password           = "unit-test-password"
  ssh_keys           = ["ssh-ed25519 AAAA unit"]
  timezone           = "UTC"
}

run "defaults" {
  command = plan
  module {
    source = "./modules/cloud_vm"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.machine == "q35"
    error_message = "New VMs use the q35 chipset."
  }
  assert {
    condition     = contains(proxmox_virtual_environment_vm.this.tags, "terraform") && contains(proxmox_virtual_environment_vm.this.tags, "docker")
    error_message = "The terraform tag is added to the guest's own tags."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.this.initialization[0].ip_config[0].ipv4[0].address == "192.0.2.20/24"
    error_message = "Static address is ip/prefix_length."
  }
  assert {
    condition     = length(proxmox_virtual_environment_file.vendor) == 1
    error_message = "The cloud-init vendor snippet is created by default."
  }
  assert {
    condition     = strcontains(proxmox_virtual_environment_file.vendor[0].source_raw[0].data, "qemu-guest-agent")
    error_message = "The vendor snippet installs the guest agent."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.this.protection == false && proxmox_virtual_environment_vm.this.on_boot == true
    error_message = "Protection is off unless requested; the VM starts on boot."
  }
}

run "adopted_guest_keeps_proxmox_defaults" {
  command = plan
  module {
    source = "./modules/cloud_vm"
  }
  variables {
    machine     = "default"
    vendor_data = false
    protection  = true
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.machine == null
    error_message = "machine = \"default\" leaves the chipset to Proxmox (i440fx)."
  }
  assert {
    # (vendor_data_file_id itself is computed, so the mock fills it in; the snippet count is the contract)
    condition     = length(proxmox_virtual_environment_file.vendor) == 0
    error_message = "vendor_data = false creates no vendor snippet."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.this.protection == true
    error_message = "The protection flag is passed through."
  }
}
