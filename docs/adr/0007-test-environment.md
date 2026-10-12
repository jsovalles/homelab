# 0007 – Scratch `test` environment on the production host

## Context
There is one Proxmox node; rebuilds must be proven before touching production guests.

## Decision
`make test` uses the `test` OpenTofu workspace (`envs/test.tfvars`: VMIDs 91xx, IPs .240–.249,
`test-` prefixed images, no protection, disabled backup job), runs every playbook twice and
fails unless the second run reports `changed=0`, then destroys everything.

## Consequences
- Catches non-idempotent tasks and fresh-install bugs (5 found so far).
- Phase 1 (host baseline) runs against the real host during tests – it is the same host.
- Only Compose services that need no real secrets are started (Traefik, tinyauth, wg-easy are
  not exercised). Production guests are never touched (separate workspace + protection flag).
