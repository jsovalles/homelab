# 0003 – SOPS + age, one secrets file for now

## Context
Ansible (vars), OpenTofu (provider token, state passphrase) and the Docker `.env` need secrets.
Later Talos/Kubernetes secrets will join.

## Decision
One file `infrastructure/ansible/inventory/group_vars/all/secrets.sops.yaml`, encrypted for a
single age recipient. Ansible loads it via the `community.sops` vars plugin; OpenTofu via an
ephemeral `sops_file`. New Proxmox tokens are written into it by Ansible, never printed.

## Consequences
- Simple, one key to back up (`~/.config/sops/age/keys.txt`).
- Anyone who can decrypt sees everything. **Revisit** at Stage C: split by trust domain with
  path-scoped `.sops.yaml` rules (`talos/`, `kubernetes/` with `encrypted_regex`), add recipients
  per machine/CI (as onedr0p/cluster-template and budimanjojo/home-cluster do).
