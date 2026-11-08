resource "proxmox_backup_job" "all_guests" {
  count = var.backup_job == null ? 0 : 1

  id      = var.backup_job.id
  enabled = var.backup_job.enabled
  comment = "Production guests – managed by OpenTofu"
  # Explicit list (not `all`): only this environment's guests, never test guests on the same node
  vmid     = [for id in sort([for g in concat(values(var.cloud_vms), values(var.appliance_vms), values(var.lxcs)) : tostring(g.vmid)]) : id]
  storage  = var.backup_job.storage
  schedule = var.backup_job.schedule
  mode     = "snapshot"
  compress = "zstd"
  prune_backups = {
    keep-last = tostring(var.backup_job.keep_last)
  }
}
