# Docker stack

The services on the docker VM. **Deployed by `make docker-host` from the repo root – never edit
files on the VM.** The `.env`, Traefik config and app config seeds are rendered by Ansible
(see the main [README](../README.md)).

Every web UI is reachable as `https://<name>.<domain>` (Let's Encrypt via Traefik, LAN-only) and
`http://<name>.home.arpa` (resolved by AdGuard, LAN-only).

| Service | Name | Purpose | Image tag |
|---|---|---|---|
| Traefik | `traefik` | Reverse proxy, TLS (DNS-01 via DuckDNS), LAN allowlist | pinned |
| wg-easy | `wg` | WireGuard VPN (UDP port in `WG_PORT`) + web UI | pinned |
| AdGuard Home | `adguard` | LAN DNS, ad blocking, `*.home.arpa` rewrite | pinned |
| Unbound | – | DNS-over-TLS upstream for AdGuard (`unbound/forward-records.conf`) | pinned |
| DuckDNS | – | Keeps the public DNS name pointed at the home IP | pinned |
| TinyAuth | `tinyauth` | Login (Google OAuth) in front of selected routes | pinned |
| Beszel + agent | `beszel` | Host/container metrics | pinned |
| Uptime Kuma | `uptime` | Uptime monitoring (monitors are set up in its UI) | pinned |
| BentoPDF | `bentopdf` | PDF tools | pinned |
| MySpeed | `myspeed` | Scheduled speed tests, no login (LAN only; data in `config/myspeed`) | pinned |

Every route (these containers and the other guests: Proxmox, Home Assistant, Gotify, Hermes, router,
AP) comes from the service catalog `infrastructure/ansible/inventory/group_vars/all/services.yml`.

## Updates

Every image is pinned to `version@sha256:digest` in `docker-compose.yml`, so the repo states
exactly what runs. Renovate opens the updates as PRs (grouped weekly, release notes included;
patch/digest updates automerge once CI passes, majors wait for review). After merging, run
`make docker-host`: a changed pin pulls the new image and recreates only that container.

## State

`config/` on the VM is runtime state (git-ignored). App-owned files (wg-easy database,
`AdGuardHome.yaml`) are seeded from SOPS when missing and saved back with `make pull-config`.
