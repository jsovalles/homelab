# New Proxmox node / reinstall runbook

Works for any Intel or AMD machine. Everything after the installer is done by this repo
(`pve_host` role): no community post-install scripts needed.

## 0. Before wiping an existing node – save what only lives on it

| What | Where | Why |
|---|---|---|
| **This repo** (until it is pushed to GitHub) | `/root/homelab` | Code, encrypted secrets **and the encrypted OpenTofu state** |
| **age key** | `~/.config/sops/age/keys.txt` | Without it nothing in the repo can be decrypted. The offline **backup age key** (added with `make age-add-recipient`) decrypts everything too |
| **SSH key** | `~/.ssh/id_ed25519` + `.pub` | Authorised on every guest |
| **Backups** | `/var/lib/vz/dump/*` | vzdump archives of the guests |
| App data not in git | Home Assistant backup (HA UI), Uptime Kuma, Beszel | Restore after the rebuild |

Copy them off the machine (e.g. to your PC with `scp -r root@<pve>:/root/homelab .` etc.) and
**check you can open them** before reinstalling. Before a reinstall also run `make pull-config`
so WireGuard/AdGuard state in the repo is current.

## 1. Install Proxmox VE

- Filesystem: **ZFS** (single disk is fine) on new nodes – enables replication/HA later.
- Hostname as in `terraform.tfvars` (`pve1`, `pve2`…), static IP from `docs/network.md`.

## 2. Bootstrap from the repo

```bash
apt update && apt install -y git make
# restore /root/homelab, ~/.config/sops/age/keys.txt, ~/.ssh/id_ed25519 (or git clone + restore keys)
cd /root/homelab
make bootstrap        # tools (checksum-verified), venv, collections
make pve-upgrade      # baseline + full upgrade (see below)
reboot                # if the run printed "A reboot is needed"
make pve-host         # re-run after the reboot: must show changed=0
```

What `make pve-host` sets up (role `pve_host`):

| Area | Setting |
|---|---|
| APT | deb822 sources only: Debian `main contrib non-free-firmware` (+ updates, security), `pve-no-subscription`, Ceph no-subscription; enterprise disabled; legacy `.list` files removed |
| CPU microcode | `intel-microcode` or `amd64-microcode`, chosen from the CPU vendor, **updated through apt** (the community `microcode.sh` installs a one-off `.deb` that never updates) |
| Web UI | subscription dialog hidden; an apt hook re-applies the patch after updates (`pve_host_remove_subscription_nag`) |
| Single node | `pve-ha-lrm` / `pve-ha-crm` stopped while not in a cluster (left alone once clustered) |
| SSH | root login with keys only (keys from `ssh_admin_public_keys` + the controller); web UI unchanged |
| System | chrony enabled, `vm.swappiness=10`, base packages, timezone, `local` storage content types |
| OpenTofu | `terraform@pve` user + `HomelabOpenTofu` role (least privilege) + token written into SOPS |

Not automatic on purpose: IOMMU/PCI passthrough (only if needed), ZFS ARC size (the 8.1+
installer already limits it sensibly).

## 3. Guests

```bash
make tf-init tf-plan     # review: guests + images + backup job
make tf-apply            # on a download error/EOF: make tf-plan tf-apply again
make site                # configure everything; then restore app data (step 0 table)
```
