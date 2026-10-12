# Docker stack

The services on the docker VM. **Deployed by `make docker-host` from the repo root – never edit
files on the VM.** The `.env`, Traefik config and app config seeds are rendered by Ansible
(see the main [README](../README.md)).

Every web UI is reachable as `https://<name>.<domain>` (Let's Encrypt via Traefik, LAN-only) and
`http://<name>.home.arpa` (resolved by AdGuard, LAN-only).

| Service | Name | Purpose | Image tag |
|---|---|---|---|
| Traefik | `traefik` | Reverse proxy, TLS (DNS-01 via DuckDNS), LAN allowlist | `v3` (latest 3.x) |
| wg-easy | `wg` | WireGuard VPN (UDP port in `WG_PORT`) + web UI | `15` (major pin) |
| AdGuard Home | `adguard` | LAN DNS, ad blocking, `*.home.arpa` rewrite | latest |
| Unbound | – | DNS-over-TLS upstream for AdGuard (`unbound/forward-records.conf`) | latest |
| DuckDNS | – | Keeps the public DNS name pointed at the home IP | latest |
| TinyAuth | `tinyauth` | Login (Google OAuth) in front of selected routes | latest |
| Beszel + agent | `beszel` | Host/container metrics | latest |
| Uptime Kuma | `uptime` | Uptime monitoring (monitors are set up in its UI) | latest |
| BentoPDF | `bentopdf` | PDF tools | latest |
| Watchtower | `watchtower` | Reports image updates (monitor-only) | latest |

Routes to other guests (Proxmox, Home Assistant, Gotify, MySpeed, router, AP) are defined in
`infrastructure/ansible/inventory/group_vars/docker_hosts/traefik.yml`.

## Updates

`:latest` images are checked by Watchtower (monitor-only); pinned majors (`traefik:v3`,
`wg-easy:15`) get Renovate PRs. `make docker-update` pulls newer images and recreates only the
containers whose image changed (`make docker-host` alone never pulls).

## State

`config/` on the VM is runtime state (git-ignored). App-owned files (wg-easy database,
`AdGuardHome.yaml`) are seeded from SOPS when missing and saved back with `make pull-config`.
