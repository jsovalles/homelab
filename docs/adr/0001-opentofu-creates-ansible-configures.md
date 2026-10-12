# 0001 – OpenTofu creates guests, Ansible configures them

## Context
The host was built by hand with community-scripts. We need to rebuild it from git, and later
grow to several Proxmox nodes and Kubernetes.

## Decision
- **OpenTofu** (`bpg/proxmox`) owns everything with a Proxmox API object: guests, image
  downloads, backup jobs, later HA resources. Cloud-init is minimal (user, key, guest agent).
- **Ansible** owns everything inside a host: Proxmox host baseline, apps in LXCs (via
  `pct exec`), the Docker stack, health checks.
- Community-scripts are not used: they are interactive and not idempotent.

## Consequences
- Two tools, but each with one clear job; the split matches the public references
  (khuedoan/homelab, sergelogvinov/terraform-talos).
- App installs (Gotify, MySpeed) are re-implemented as Ansible roles and must be maintained.
