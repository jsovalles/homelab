# hermes

Installs [Hermes Agent](https://github.com/NousResearch/hermes-agent) on its own VM (own kernel – the agent runs arbitrary shell/browser commands):

- dedicated account `hermes` (locked password, no sudo); the agent runs as this user only,
- official installer, run once (`make hermes-update` runs `hermes update` later),
- `hermes_env_secrets` (SOPS) merged key by key into `~/.hermes/.env` (mode 0600),
- nftables owned by root: internet allowed, LAN blocked (except DNS and `hermes_lan_allow`),
  inbound SSH from the LAN only,
- optional messaging gateway as a system service (`hermes_gateway_enabled`).

One-time interactive setup (provider/model, messaging platforms):
`ssh ansible@<lan>.60` → `sudo -iu hermes` → `hermes setup`, then set `hermes_gateway_enabled = true` in the
guest's ansible vars (`terraform.tfvars`) and run `make hermes`.
`config.yaml`, memory and skills live in `~/.hermes` and are covered by the vzdump backup.

| Variable | Type | Description |
|---|---|---|
| `hermes_user` | str | Unprivileged account that owns and runs Hermes |
| `hermes_home` | path | Home directory of hermes_user |
| `hermes_installer_url` | str | Official install.sh URL |
| `hermes_commit` | str | Git commit to install ('' = latest) |
| `hermes_update` | bool | Run `hermes update` (make hermes-update) |
| `hermes_install_browser` | bool | Install agent-browser + Chromium |
| `hermes_install_computer_use` | bool | Install the computer-use driver |
| `hermes_env` | dict | Keys written to ~/.hermes/.env (default: hermes_env_secrets from SOPS) |
| `hermes_gateway_memory_max` | str | MemoryMax of the gateway service (agent commands included) |
| `hermes_gateway_tasks_max` | int | TasksMax of the gateway service |
| `hermes_gateway_cpu_quota` | str | CPUQuota of the gateway service |
| `hermes_ipv6_enabled` | bool | Keep IPv6 on the VM (off: link-local would bypass the IPv4 LAN block) |
| `hermes_gateway_enabled` | bool | Run the messaging gateway as a system service |
| `hermes_firewall_enabled` | bool | nftables: block LAN egress, inbound SSH from the LAN only |
| `hermes_lan_cidr` | str | LAN range the agent must not reach |
| `hermes_dns_servers` | list | Resolvers allowed on port 53 |
| `hermes_lan_allow` | list | LAN exceptions: list of {host, port} (TCP) |
| `hermes_ssh_allowed_cidrs` | list | Sources allowed to SSH in |

Defaults: `defaults/main.yml`.
