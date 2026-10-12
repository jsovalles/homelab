# Network plan – `<lan>.0/24`

`<lan>` stands for the private /24 prefix of the home network. Real addresses, MACs and the
domain live only in `infrastructure/ansible/inventory/group_vars/all/site.sops.yaml`
(`make site-config`); this document describes the **layout**, not the values.

Single flat LAN on `vmbr0`, gateway/router `<lan>.1`.
**Everything outside the DHCP pool is assigned statically by this repo.**

DHCP pool on the router: **`.100 – .150`**. Everything else is static and assigned by this repo
(or by a DHCP reservation for appliances without cloud-init).

| Range | Purpose | Notes |
|---|---|---|
| `.1` | Router / gateway | Also upstream DNS for guests |
| `.2` | Docker VM (AdGuard DNS, Traefik, wg-easy) | Network DNS server – keep fixed |
| `.3` | *reserved* | |
| `.4 – .9` | Proxmox VE nodes | `.4` pve1, `.5` pve2, `.6` pve3 … |
| `.10` | Corosync QDevice | Only while the cluster has an even number of nodes (e.g. a Raspberry Pi) |
| `.11 – .19` | Raspberry Pis (bare-metal Talos workers) | Stage C |
| `.20 – .39` | Talos VMs (control plane + workers) | Stage C |
| `.40` | Kubernetes API virtual IP | Shared by control-plane nodes |
| `.41 – .59` | Cilium LoadBalancer / L2 pool | Service IPs handed out by Kubernetes |
| `.60 – .99` | Static VMs / LXCs | myspeed `.79` |
| **`.100 – .150`** | **DHCP pool (router)** | Clients, phones, IoT |
| `.100` | Home Assistant OS – **DHCP reservation** by MAC (pinned in `site.sops.yaml`) | Inside the pool on purpose: HAOS has no cloud-init; the reservation pins it. Alternative: set a static IP in HA and move it to `.60–.99` |
| `.151 – .199` | Static VMs / LXCs (overflow) | gotify `.196` |
| `.200 – .239` | *reserved* (future VLAN migration / services) | |
| `.240 – .249` | `make test` scratch environment | Destroyed after each test |
| `.250 – .254` | *reserved* | |

> Note: a DHCP client was seen at `.208` before the pool was confirmed – if the router pool
> really ends at `.150`, that lease came from an older configuration and will not recur.

## DNS

- **Public names:** `https://<service>.<domain>` (Let's Encrypt wildcard via DuckDNS).
- **Internal names:** `http://<service>.home.arpa` – `home.arpa` is the RFC 8375 domain for home
  networks. Do **not** use `.local`: it is reserved for mDNS (RFC 6762) and devices such as Home
  Assistant answer for their own `.local` names.
- AdGuard rewrites `*.<domain>` and `*.home.arpa` to the Docker VM (Traefik).
  Migration from the old setup: in the AdGuard UI add the `*.home.arpa` rewrite and delete the old
  `*.local` one (it hijacks every `.local` name for AdGuard clients), then `make pull-config` so the
  repo copy (`AdGuardHome.sops.yaml`) has the change.

- Guests and nodes resolve via `<lan>.1` → `1.1.1.1` (never through AdGuard, so the
  DNS server can always boot).
- LAN clients use AdGuard on `.2` (handed out by the router's DHCP).
- When Kubernetes takes over AdGuard (Stage C), give it a fixed LoadBalancer IP and keep
  `.2` working until the router points to the new one.

## Future

- A dedicated Corosync/storage network (second NIC or VLAN) once there are 3+ nodes or Ceph.
- VLANs (IoT, lab, management) are possible later: `nodes[*].bridge` and a `vlan_id` field
  per guest are the extension points in Terraform.
