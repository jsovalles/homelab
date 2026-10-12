#!/usr/bin/env bash
# Fail if any *.sops.y(a)ml / *.sops.json file passed (or tracked by git) is not SOPS-encrypted.
set -Eeuo pipefail

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.sops.yaml' '*.sops.yml' '*.sops.json' \
    | grep -vE '(^|/)\.sops\.ya?ml$')
fi

rc=0
for f in "${files[@]}"; do
  # YAML has a top-level `sops:` key, JSON a top-level "sops" object
  if ! grep -qE '^(sops:|[[:space:]]*"sops": *\{)' "$f" || ! grep -qE 'ENC\[AES256_GCM' "$f"; then
    printf 'NOT ENCRYPTED: %s\n' "$f" >&2
    rc=1
  fi
done
exit "$rc"
