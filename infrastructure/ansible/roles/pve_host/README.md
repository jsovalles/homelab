# pve_host

Baseline for the Proxmox VE host: no-subscription repos, packages, storage content types, OpenTofu API user/token (written to SOPS).

| Variable | Type | Description |
|---|---|---|
| `pve_host_manage_repos` | bool | Manage APT repository files |
| `pve_host_apt_sources_absent` | list | Files in /etc/apt/sources.list.d to remove |
| `pve_host_install_microcode` | bool | Install CPU microcode via apt (vendor detected) |
| `pve_host_full_upgrade` | bool | Run apt full-upgrade (make pve-upgrade) |
| `pve_host_remove_subscription_nag` | bool | Hide the subscription dialog (apt hook re-applies) |
| `pve_host_disable_ha_single_node` | bool | Stop HA services while not clustered |
| `pve_host_ssh_keys_only` | bool | Root SSH login with keys only |
| `pve_host_sysctl` | dict | Kernel settings written to /etc/sysctl.d/90-homelab.conf |
| `pve_host_packages` | list | Packages to install |
| `pve_host_manage_network` | bool | Template /etc/network/interfaces (dangerous) |
| `pve_host_address` | str | vmbr0 CIDR address |
| `pve_host_gateway` | str | Default gateway |
| `pve_host_bridge_port` | str | Physical NIC behind vmbr0 |
| `pve_host_local_storage_content` | str | Content types for the 'local' storage |
| `pve_host_tf_user` | str | API user for OpenTofu |
| `pve_host_tf_token` | str | Token name |
| `pve_host_tf_privs` | list | Privileges of the OpenTofu role |
| `pve_host_tf_revoke_roles` | list | Roles to revoke from the OpenTofu user on / |
| `pve_host_tf_role` | str | Role granted on / |
| `pve_host_sops_file` | path | SOPS file the new token is written to |

Defaults: `defaults/main.yml`.
