#!/usr/bin/env bash
# gitleaks as CI sees it, plus uncommitted work: the full git history and the working tree
# (tracked + untracked, but not ignored files – .cache/, .venv/ hold third-party test keys).
# Runs inside the pre-commit gitleaks environment, so the pinned gitleaks binary is on PATH.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

tree="$(mktemp -d)"
trap 'rm -rf -- "$tree"' EXIT

gitleaks git --no-banner --redact .
git ls-files -z --cached --others --exclude-standard \
  | while IFS= read -r -d '' f; do
      # tracked but deleted in the working tree: skip it (an `&&` here would fail the pipeline)
      if [[ -f "$f" ]]; then printf '%s\0' "$f"; fi
    done \
  | xargs -0 -r cp --parents -t "$tree"
cp .gitleaks.toml "$tree/"
gitleaks dir --no-banner --redact --verbose --config "$tree/.gitleaks.toml" "$tree"
