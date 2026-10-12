# 0008 – App config: templates + SOPS seeds instead of a config archive

## Context
The Docker VM's `config/` (Traefik, WireGuard, AdGuard) was backed up as one password-protected
archive (`config.tar.gz.enc`). It was opaque in git (any change = new blob), mixed config we own
with state the apps own, and needed a separate password.

## Decision
- **Repo-owned** config is rendered from templates on every deploy (Traefik, `.env`); the repo
  always wins.
- **App-owned** files (wg-easy `wg0.json`, `AdGuardHome.yaml`) are stored SOPS-encrypted in
  `infrastructure/ansible/files/`, written to the VM only when missing, and copied back with
  `make pull-config` (rewritten only when the content changed).
- `make drift` reports differences in both directions without changing anything.
- Not stored: Traefik `acme.json` (re-issued) and app data volumes (vzdump).
- `config.tar.gz.enc`, `make backup-config` and its password are removed.

## Consequences
- One key (age) protects everything; no extra backup password.
- App changes are not saved until `make pull-config` – `make drift` shows what is pending.
