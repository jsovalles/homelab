# 0004 – Ansible inventory generated from tfvars

## Context
VMIDs, IPs and node placement were written both in `terraform.tfvars` and in the Ansible
inventory, which drifts as soon as nodes and guests are added.

## Decision
Each guest in tfvars declares `ansible = { groups, vars }`. OpenTofu renders
`local.ansible_inventory`; `scripts/inventory.sh` evaluates it with `tofu console` (no state
needed) into `infrastructure/ansible/inventory/<env>.yml` (gitignored). Every Ansible make
target regenerates it first. Connection settings that are the same for a group live in
`group_vars/<group>.yml`.

## Consequences
- tfvars is the single source of truth; adding a guest is one edit.
- Ansible runs need the age key (to evaluate tofu) – already true for secrets.
