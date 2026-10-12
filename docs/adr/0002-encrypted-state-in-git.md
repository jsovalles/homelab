# 0002 – Encrypted OpenTofu state committed to git

## Context
The goal is "rebuild from the GitHub repo". State must survive the host it describes, and
there is a single operator. None of the reviewed public repos commit state; most keep it local.

## Decision
Use OpenTofu native state + plan encryption (PBKDF2 → AES-GCM, `enforced = true`) with the
passphrase in SOPS, and commit `terraform.tfstate` for the production workspace.
Secrets are read through an `ephemeral` sops resource so they never reach state; per-guest
passwords (`random_password`) do live in state, protected by the encryption.

## Consequences
- Disaster recovery needs only git + the age key.
- No locking: two concurrent applies would conflict. Acceptable for one operator.
- **Revisit** when CI applies changes or a second operator appears → S3/MinIO backend with locking
  (supersede this ADR).
