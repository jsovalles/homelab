# Security

Single-maintainer homelab. If you find a problem, please open a private
[security advisory](https://github.com/jsovalles/homelab/security/advisories/new) instead of an issue.

## How secrets are handled

- All secrets live in SOPS files encrypted with age (`*.sops.yaml`, `*.sops.json`); decrypted values
  are only used in memory. Site data (domain, IPs, MACs) is encrypted the same way.
- Every commit and CI run checks: values that SOPS should encrypt are encrypted
  (`scripts/check-sops-encrypted.sh`), no site data in plain files (`scripts/check-no-site-data.sh`),
  and gitleaks over the full history and the working tree.

## Known exposure in git history

| What | Where | Status |
|---|---|---|
| Watchtower HTTP API token | `.env.example` in the first commits (Sep 2025 – Jan 2026), before secrets moved to SOPS | **Burned.** The Watchtower HTTP API is disabled (no `WATCHTOWER_HTTP_API_*` in the stack) and the value is not used anywhere. Never re-enable the API with it. Listed in `.gitleaksignore`. |

The history was not rewritten: the repository is public, rewriting would change every commit hash,
and copies of the old commits may exist elsewhere. Anything ever committed in plain text is treated
as compromised and rotated instead.
