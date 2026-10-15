# Resolve "latest stable" images (url + checksum) at plan time.
# Existing guests are never recreated by a new release: the modules ignore their source image
# after creation; a new release only replaces the downloaded file used by the next build.

# --- Debian cloud images: <release>/latest/SHA512SUMS -------------------------------------------
data "http" "debian_sums" {
  for_each = { for k, v in var.cloud_images : k => v if v.debian_latest != null }
  url      = "https://cloud.debian.org/images/cloud/${split("/", each.value.debian_latest)[0]}/latest/SHA512SUMS"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not read Debian's SHA512SUMS (${self.url})."
    }
  }
}

# --- Proxmox LXC template index ----------------------------------------------------------------
# Plain http on purpose: download.proxmox.com has no valid TLS certificate (its cert only covers
# *.cdn.proxmox.com / enterprise.proxmox.com). The index is GPG-signed (.asc), which OpenTofu cannot
# verify, so url + checksum both come from an unauthenticated source – pin url/checksum in
# terraform.tfvars if that matters for an environment.
data "http" "pve_aplinfo" {
  count = length([for v in values(var.lxc_templates) : v if v.pve_latest != null]) > 0 ? 1 : 0
  url   = "http://download.proxmox.com/images/aplinfo-pve-9.dat"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not read the Proxmox template index (${self.url})."
    }
  }
}

# --- Home Assistant OS: latest GitHub release (not a pre-release) ------------------------------
data "http" "haos_release" {
  count           = length([for v in values(var.appliance_images) : v if v.haos_latest]) > 0 ? 1 : 0
  url             = "https://api.github.com/repos/home-assistant/operating-system/releases/latest"
  request_headers = { Accept = "application/vnd.github+json", User-Agent = "homelab-opentofu" }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not read the latest HAOS release from GitHub (${self.url})."
    }
  }
}

locals {
  # Debian: "<release>/<image>" -> url, checksum, file name with the first 12 hex of the checksum
  cloud_images_resolved = {
    for k, v in var.cloud_images : k => v.debian_latest == null ? v : merge(v, {
      url = "https://cloud.debian.org/images/cloud/${split("/", v.debian_latest)[0]}/latest/${split("/", v.debian_latest)[1]}.qcow2"
      checksum = regex(
        "([0-9a-f]{128})  ${split("/", v.debian_latest)[1]}\\.qcow2",
        data.http.debian_sums[k].response_body
      )[0]
      file_name = "${split("/", v.debian_latest)[1]}-${substr(regex(
        "([0-9a-f]{128})  ${split("/", v.debian_latest)[1]}\\.qcow2",
        data.http.debian_sums[k].response_body
      )[0], 0, 12)}.qcow2"
      checksum_algorithm = "sha512"
    })
  }

  # Proxmox index: blocks separated by a blank line; the last block for the package wins
  pve_template_blocks = length(data.http.pve_aplinfo) == 0 ? [] : split("\n\n", data.http.pve_aplinfo[0].response_body)
  # Newest amd64 index block per pve_latest package
  pve_template_latest = {
    for k, v in var.lxc_templates : k => reverse([
      for b in local.pve_template_blocks : b if strcontains(b, "Package: ${v.pve_latest}\n") && strcontains(b, "_amd64.")
    ])[0] if v.pve_latest != null
  }
  lxc_templates_resolved = {
    for k, v in var.lxc_templates : k => v.pve_latest == null ? v : merge(v, {
      url                = "http://download.proxmox.com/images/${regex("Location: ([^\n]+)", local.pve_template_latest[k])[0]}"
      checksum           = regex("sha512sum: ([0-9a-f]+)", local.pve_template_latest[k])[0]
      checksum_algorithm = "sha512"
    })
  }

  # HAOS: tag + sha256 digest of haos_ova-<tag>.qcow2.xz from the release assets
  haos_release = length(data.http.haos_release) == 0 ? null : jsondecode(data.http.haos_release[0].response_body)
  appliance_images_resolved = {
    for k, v in var.appliance_images : k => !v.haos_latest ? v : merge(v, {
      url       = "https://github.com/home-assistant/operating-system/releases/download/${local.haos_release.tag_name}/haos_ova-${local.haos_release.tag_name}.qcow2.xz"
      file_name = "haos_ova-${local.haos_release.tag_name}.img"
      checksum = trimprefix([
        for a in local.haos_release.assets : a.digest if a.name == "haos_ova-${local.haos_release.tag_name}.qcow2.xz"
      ][0], "sha256:")
      checksum_algorithm      = "sha256"
      decompression_algorithm = coalesce(v.decompression_algorithm, "zst")
    })
  }
}
