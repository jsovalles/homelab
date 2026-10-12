# Architecture Decision Records

One file per decision: context, decision, consequences. Never rewrite an accepted ADR –
supersede it with a new one.

| # | Decision | Status |
|---|---|---|
| [0001](0001-opentofu-creates-ansible-configures.md) | OpenTofu creates guests, Ansible configures them | Accepted |
| [0002](0002-encrypted-state-in-git.md) | Encrypted OpenTofu state committed to git | Accepted |
| [0003](0003-sops-age-single-secrets-file.md) | SOPS + age, one secrets file for now | Accepted |
| [0004](0004-inventory-generated-from-tfvars.md) | Ansible inventory generated from tfvars | Accepted |
| [0005](0005-proxmox-access-model.md) | Proxmox access: CLI bootstrap, least-privilege token, root SSH | Accepted |
| [0006](0006-haos-appliance-image-import.md) | HAOS image imported with `file_id` (SSH) | Accepted |
| [0007](0007-test-environment.md) | Scratch `test` environment on the production host | Accepted |
| [0008](0008-app-config-templates-and-seeds.md) | App config: templates + SOPS seeds instead of a config archive | Accepted |
