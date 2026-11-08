# `tflint --recursive` (CI). The bundled terraform ruleset is enough: there is no tflint
# ruleset for the bpg/proxmox provider.
config {
  # Modules are linted on their own by --recursive; evaluating module calls from the root would
  # need the site data (IPs) that only exists in SOPS.
  call_module_type = "none"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
