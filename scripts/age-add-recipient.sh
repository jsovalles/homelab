#!/usr/bin/env bash
# Add an age public key as an extra SOPS recipient (e.g. an offline backup key) and
# re-encrypt every SOPS file so either key can decrypt it.
#   make age-add-recipient KEY=age1...
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

key="${1:-}"
if [[ ! "$key" =~ ^age1[0-9a-z]{58}$ ]]; then
  echo "usage: $0 age1...   (the PUBLIC key, from: age-keygen -y <keyfile>)" >&2
  exit 2
fi

if grep -q "$key" .sops.yaml; then
  echo "already a recipient in .sops.yaml"
else
  # every `age: <keys>` line gets the new key appended
  sed -i -E "s|^( *age: )(.*)$|\1\2,${key}|" .sops.yaml
  echo "added to .sops.yaml"
fi

mapfile -t files < <(git ls-files --cached --others --exclude-standard | grep -E '(^|/)[^/]+\.sops\.(ya?ml|json)$')
for f in "${files[@]}"; do
  sops updatekeys --yes "$f"
done
echo "re-encrypted ${#files[@]} files – commit .sops.yaml and the *.sops.* files"
