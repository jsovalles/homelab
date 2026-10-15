# Working on this repo

Single-maintainer homelab, but every change goes through a branch and a PR so CI runs and
`main` always reflects what is deployed.

## Flow

1. `git switch -c <type>/<short-name>` (e.g. `feat/uptime-route`, `fix/wg-port`)
2. Edit in the repo, never on a guest. Secrets: `make secrets`; site data: `make site-config`.
3. `make lint` (also runs as a pre-commit hook after `make hooks`); `make tf-test` when changing
   an OpenTofu module (add a test in `infrastructure/terraform/tests/` for new module behaviour)
4. Test on scratch guests: `make test` (only the parts you changed) –
   `make test-full` for big or cross-cutting changes and before merging a large PR
5. Apply to production (`make docker-host`, `make lxc-apps`, `make tf-plan tf-apply`, …),
   then `make drift` must be clean
6. Open the PR, let CI pass, squash-merge

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `ci:`) – Renovate uses the same style.

## Rules

- **No site data in plain text**: LAN IPs, MACs and the domain live only in `site.sops.yaml`
  (checked by the `no-site-data` hook). Secrets live only in `secrets.sops.yaml`.
- Never commit decrypted files, `.env`, plan files or age keys (`.gitignore` + gitleaks).
- Changed something in wg-easy or AdGuard's UI? `make pull-config` and commit the result.
- Architectural decisions get an ADR in `docs/adr/`.
