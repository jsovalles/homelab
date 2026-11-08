# host_firewall

nftables input/forward filter that coexists with Docker's own rules (LAN-only by default).

Loads its own table (`inet homelab_fw`) from a dedicated systemd unit, so Docker's chains are
never flushed. Host services are filtered on input; container ports published by Docker are
filtered on forward by their original host port. Containers can always reach host services.

| Variable | Type | Description |
|---|---|---|
| `host_firewall_enabled` | bool | Load the rules (false removes them) |
| `host_firewall_allowed_cidrs` | list | Sources allowed to reach the LAN ports (default: `lan_cidr` + `traefik_extra_allowed_cidrs`) |
| `host_firewall_lan_tcp_ports` | list | TCP ports open to `host_firewall_allowed_cidrs` |
| `host_firewall_lan_udp_ports` | list | UDP ports open to `host_firewall_allowed_cidrs` |
| `host_firewall_public_tcp_ports` | list | TCP ports open to everyone (router port forwards) |
| `host_firewall_public_udp_ports` | list | UDP ports open to everyone (router port forwards) |

Defaults: `defaults/main.yml`. Debug on the host: `nft list table inet homelab_fw`.
