# pve_host

Baseline for the Proxmox VE host: no-subscription repos, packages, storage content types, OpenTofu API user/token (written to SOPS).

| Variable | Type | Description |
|---|---|---|
| `pve_host_manage_repos` | bool | Manage APT repository files |
| `pve_host_packages` | list | Packages to install |
| `pve_host_manage_network` | bool | Template /etc/network/interfaces (dangerous) |
| `pve_host_address` | str | vmbr0 CIDR address |
| `pve_host_gateway` | str | Default gateway |
| `pve_host_bridge_port` | str | Physical NIC behind vmbr0 |
| `pve_host_local_storage_content` | str | Content types for the 'local' storage |
| `pve_host_tf_user` | str | API user for OpenTofu |
| `pve_host_tf_token` | str | Token name |
| `pve_host_tf_role` | str | Role granted on / |
| `pve_host_sops_file` | path | SOPS file the new token is written to |

Defaults: `defaults/main.yml`.
