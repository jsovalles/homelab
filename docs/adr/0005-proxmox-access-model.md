# 0005 – Proxmox access: CLI bootstrap, least-privilege token, root SSH

## Context
`community.proxmox` modules need API credentials, but the API token is what we are creating.
bpg needs SSH for snippets and `file_id` disk imports.

## Decision
- Phase 1 runs on the node as root and uses `pveum`/`pvesm` with explicit idempotency checks
  (no module covers tokens; no API credentials exist yet).
- OpenTofu uses `terraform@pve!homelab` with the custom `TerraformProv` role (no user, realm,
  permission, host power or guest-agent file privileges). `Administrator` is revoked.
- Provider SSH uses root with key auth (required by snippets and `file_id`, see ADR 0006).
- Guests: cloud-init user `ansible` with passwordless sudo; unique random console password per
  guest; SSH host keys verified (`accept-new`).

## Consequences
- The controller (currently pve1 itself) holds root SSH + the age key: compromise of the
  controller = compromise of everything. **Revisit**: move control to a workstation/CI runner and
  a restricted sudo user per bpg's documented sudoers rules.

## Addendum – token storage
- If writing a new token into SOPS fails, the token is removed again (block/rescue), so a lost
  secret can never leave a dead token behind.
- `sops set` (3.10) takes the value as an argument, so the secret is visible in the process list
  for the duration of the call. Accepted: the controller is a root-only host. Revisit when the
  controller moves to a multi-user machine.
