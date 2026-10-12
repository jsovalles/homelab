locals {
  # Non-default workspaces get their own copies of downloaded files so that
  # `tofu destroy` in the test workspace never removes production images.
  file_prefix = terraform.workspace == "default" ? "" : "${terraform.workspace}-"
  ssh_keys    = [trimspace(file(pathexpand(var.ssh_public_key_file)))]

  # "<node>/<image>" pairs actually needed by guests
  cloud_image_pairs = {
    for p in distinct([for k, v in var.cloud_vms : { node = v.node, image = v.image }]) :
    "${p.node}/${p.image}" => p
  }
  appliance_image_pairs = {
    for p in distinct([for k, v in var.appliance_vms : { node = v.node, image = v.image }]) :
    "${p.node}/${p.image}" => p
  }
  lxc_template_pairs = {
    for p in distinct([for k, v in var.lxcs : { node = v.node, image = v.template }]) :
    "${p.node}/${p.image}" => p
  }
}

resource "proxmox_download_file" "cloud_image" {
  for_each = local.cloud_image_pairs

  content_type       = "import"
  node_name          = each.value.node
  datastore_id       = var.nodes[each.value.node].file_datastore
  url                = local.cloud_images_resolved[each.value.image].url
  file_name          = "${local.file_prefix}${local.cloud_images_resolved[each.value.image].file_name}"
  checksum           = local.cloud_images_resolved[each.value.image].checksum
  checksum_algorithm = local.cloud_images_resolved[each.value.image].checksum_algorithm
  overwrite          = false
  upload_timeout     = 1800 # seconds; mirrors are occasionally slow
}

# Proxmox only decompresses for content "iso"; its "zst" path runs `zstd -d`,
# which also understands xz – that is how .qcow2.xz appliance images work.
resource "proxmox_download_file" "appliance_image" {
  for_each = local.appliance_image_pairs

  content_type            = "iso"
  node_name               = each.value.node
  datastore_id            = var.nodes[each.value.node].file_datastore
  url                     = local.appliance_images_resolved[each.value.image].url
  file_name               = "${local.file_prefix}${local.appliance_images_resolved[each.value.image].file_name}"
  checksum                = local.appliance_images_resolved[each.value.image].checksum
  checksum_algorithm      = local.appliance_images_resolved[each.value.image].checksum_algorithm
  decompression_algorithm = local.appliance_images_resolved[each.value.image].decompression_algorithm
  overwrite               = false
  upload_timeout          = 1800 # seconds; mirrors are occasionally slow
}

resource "proxmox_download_file" "lxc_template" {
  for_each = local.lxc_template_pairs

  content_type       = "vztmpl"
  node_name          = each.value.node
  datastore_id       = var.nodes[each.value.node].file_datastore
  url                = local.lxc_templates_resolved[each.value.image].url
  file_name          = "${local.file_prefix}${basename(local.lxc_templates_resolved[each.value.image].url)}"
  checksum           = local.lxc_templates_resolved[each.value.image].checksum
  checksum_algorithm = local.lxc_templates_resolved[each.value.image].checksum_algorithm
  overwrite          = false
  upload_timeout     = 1800 # seconds; mirrors are occasionally slow
}

# Image keys no longer carry a version (latest is resolved at plan time)
moved {
  from = proxmox_download_file.appliance_image["pve1/haos-18.3"]
  to   = proxmox_download_file.appliance_image["pve1/haos"]
}
