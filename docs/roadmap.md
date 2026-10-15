# Roadmap – from one node to an HA cluster

Target: several Proxmox nodes (mini PCs) + Raspberry Pis, highly-available services and
Kubernetes-style scaling, along the lines of
[Talos Linux on Proxmox with Terraform](https://www.jonashietala.se/blog/2026/05/22/talos_linux_on_proxmox_with_terraform/).

## What provides what

| Goal | Mechanism |
|---|---|
| HA for VMs that must stay VMs (HAOS) | Proxmox cluster (≥3 votes) + Proxmox HA + replicated/shared storage |
| HA for services | Kubernetes (Talos): pods are rescheduled on healthy nodes |
| Autoscaling | Kubernetes HPA for workloads; node count = a list in tfvars (`tofu apply`) |
| Desired state for apps | GitOps (ArgoCD/Flux) watching `gitops/` |
| Secrets everywhere | SOPS + age (Ansible, OpenTofu today; KSOPS / Flux SOPS in Kubernetes) |

## Stage A – single node (now)

- [x] OpenTofu creates all guests; Ansible configures them; SOPS secrets; `make test`
- [x] Multi-node-ready structure: `nodes` map, per-node image downloads, guest maps, modules
- [x] Ground-zero rebuild of all guests from the repo (Debian 13, IDs 100–103); adoption path kept for future nodes (`adopt_existing_guests`)
- [x] DHCP pool `.100–.150` documented; static ranges outside it (`docs/network.md`)
- [ ] AdGuard: encryption (DoH 8053 / DoT 853) is enabled without a certificate – disable it or
      reuse the Traefik wildcard certificate (existing production issue, logged at every start).
      Waits for the own domain (DuckDNS is not reliable enough for certificates)
- [ ] Proxmox API certificate via ACME once the own domain exists, then `insecure = false` in the
      OpenTofu provider (TLS verification is off today)
- [ ] Off-host backups: point `backup_job.storage` at the future NAS node (Proxmox on the NAS,
      NFS/PBS). Until then backups live on the same disk as the guests
- [x] Bootstrap: `make bootstrap` calls `sudo`, which a fresh Proxmox host doesn't have (root
      login) – only use `sudo` when not already root
- [x] Bootstrap: `apt-get update` fails with `401 Unauthorized` on a fresh Proxmox host
      (enterprise repos enabled, no subscription). Phase 1 (`pve_host/tasks/apt.yml`) fixes the
      sources, but it runs after bootstrap – switch to the no-subscription repos inside
      `scripts/bootstrap.sh` when it detects Proxmox
- [x] Phase ordering: `make pve-host` renders the inventory via `tofu console`, which needs
      `tofu init` (Phase 2) first – run init in bootstrap or auto-init in `scripts/inventory.sh`
- [x] Hostname mismatch: the repo assumed `pve1`, the host was installed as `pve-01`; plan failed
      with "hostname lookup 'pve1' failed". Add a Phase 1 preflight check that
      `ansible_hostname` is a key in `nodes` (terraform.tfvars) before Phase 2
- [x] Stale state: the committed state described guests on the old host; a ground-zero rebuild
      on a new host needed manual `tofu state rm`. Document/script a "fresh host" state reset
      (keep `random_password.*`)
- [x] Storage mismatch: tfvars assumed `local-lvm`, the host has `local-zfs`; apply failed at
      VM creation. Preflight-check that `nodes.*.vm_datastore` exists (`pvesm status`) in Phase 1,
      or make the `vm_datastore` default `local-zfs` to match the ZFS-only policy

## Stage B – Proxmox cluster (nodes 2 and 3)

Prerequisites per new node:
- Install with **ZFS** (`rpool`) → enables storage replication + HA without Ceph.
  pve-01 is already ZFS (`local-zfs`).
- Same Proxmox major version, unique hostname, static IP from `.4 – .9`.

Work:
- [ ] Add node to `nodes` in `terraform.tfvars` (the generated inventory follows)
- [ ] Ansible role `pve_cluster`: `pvecm create` on the first node / `pvecm add` on the rest,
      idempotent (check `pvecm status` first) – pattern from the `ansible-proxmox` skill
- [ ] QDevice on a Raspberry Pi while the vote count is even (`.10`)
- [ ] ZFS storage replication jobs + Proxmox HA rules for HAOS and the Docker VM
      (OpenTofu `proxmox_virtual_environment_haresource`, replication via Ansible/API)
- [ ] Optional later: Ceph (≥3 nodes, ideally 10 GbE dedicated network)

Raspberry Pis are **not** Proxmox nodes (no official ARM support): they become the QDevice
and/or bare-metal Talos workers in Stage C.

## Stage C – Kubernetes (Talos)

Layout (separate OpenTofu root so cluster state is isolated from guest state):

```
infrastructure/
├── terraform/            # Proxmox guests (this)
├── terraform-talos/      # Talos VMs (reuse modules/…), siderolabs/talos provider, bootstrap
└── ansible/
gitops/                   # ArgoCD/Flux apps – replaces docker/ service by service
```

- [ ] Talos image from the image factory (`qemu-guest-agent`, `iscsi-tools`, `util-linux-tools`)
- [ ] 3 control-plane VMs spread over the Proxmox nodes (`.20+`), VIP `.40`
- [ ] Raspberry Pis join as workers (bare metal, `.11+`)
- [ ] Cilium (kube-proxy replacement, L2 announcements, Gateway API), LB pool `.41 – .59`
- [ ] Storage: Longhorn (replicated across nodes) or NFS/democratic-csi
- [ ] ArgoCD + SOPS (age key) for secrets
- [ ] Migrate `docker/` services one at a time: AdGuard+Unbound, Traefik → Gateway API,
      tinyauth, homepage, dozzle, beszel, wg-easy; Gotify and MySpeed (LXCs) too
- [ ] Retire the Docker VM when empty. HAOS stays a VM (Proxmox HA).

## Stage D – scaling & polish

- [ ] HPA / resource requests for workloads
- [ ] Node pools as tfvars lists (add a worker = one line + `tofu apply`); consider Omni
- [ ] Monitoring (Prometheus/Grafana or Beszel), alerting to Gotify
- [ ] Remote OpenTofu state (S3/MinIO) once more than one operator/CI applies changes
- [ ] CI: `make test` on a self-hosted runner for every PR
