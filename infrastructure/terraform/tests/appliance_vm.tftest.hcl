# Unit tests for modules/appliance_vm (mock provider: no Proxmox, no secrets). Run: make tf-test
mock_provider "proxmox" {}

variables {
  node_name     = "pve-01"
  vm_id         = 9400
  name          = "unit-haos"
  cores         = 2
  memory        = 4096
  disk_size     = 32
  vm_datastore  = "local-zfs"
  image_file_id = "local:iso/haos_ova-18.3.img"
  bridge        = "vmbr0"
}

run "defaults" {
  command = plan
  module {
    source = "./modules/appliance_vm"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].file_id == "local:iso/haos_ova-18.3.img" && proxmox_virtual_environment_vm.this.disk[0].interface == "scsi0"
    error_message = "The vendor image boots as scsi0."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.this.bios == "ovmf" && proxmox_virtual_environment_vm.this.efi_disk[0].pre_enrolled_keys == false
    error_message = "UEFI without pre-enrolled Secure Boot keys (HAOS does not boot with them)."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.this.machine == "q35" && proxmox_virtual_environment_vm.this.startup[0].order == 1
    error_message = "q35 by default; appliances start first (order 1)."
  }
  assert {
    condition     = proxmox_virtual_environment_vm.this.disk[0].cache == "writethrough"
    error_message = "Appliance disks use writethrough cache by default."
  }
}

run "adopted_guest_keeps_proxmox_defaults" {
  command = plan
  module {
    source = "./modules/appliance_vm"
  }
  variables {
    machine = "default"
  }

  assert {
    condition     = proxmox_virtual_environment_vm.this.machine == null
    error_message = "machine = \"default\" leaves the chipset to Proxmox (i440fx)."
  }
}
