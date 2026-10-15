#!/usr/bin/env bash
# Fail if a *.sops.y(a)ml / *.sops.json file passed (or tracked by git) holds a value SOPS
# should have encrypted in plaintext. Uses the file's own sops metadata: with encrypted_regex,
# only values under matching keys must be ENC[...] (the rest is plaintext by design and still
# scanned by gitleaks); otherwise every value must be, except keys ending in the unencrypted suffix.
set -Eeuo pipefail

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.sops.yaml' '*.sops.yml' '*.sops.json' \
    | grep -vE '(^|/)\.sops\.ya?ml$')
fi
[[ ${#files[@]} -eq 0 ]] && exit 0

python3 - "${files[@]}" <<'PY'
import json
import re
import sys

import yaml

rc = 0
for path in sys.argv[1:]:
    with open(path) as f:
        doc = json.load(f) if path.endswith(".json") else yaml.safe_load(f)
    meta = doc.get("sops") if isinstance(doc, dict) else None
    if not isinstance(meta, dict):
        print(f"NOT ENCRYPTED (no sops metadata): {path}", file=sys.stderr)
        rc = 1
        continue
    enc_re = meta.get("encrypted_regex")
    suffix = meta.get("unencrypted_suffix", "_unencrypted")
    plain = []

    def walk(node, keypath, must_encrypt):
        if isinstance(node, dict):
            for k, v in node.items():
                k = str(k)
                if enc_re is not None:
                    child = must_encrypt or re.search(enc_re, k) is not None
                else:
                    child = must_encrypt and not k.endswith(suffix)
                walk(v, keypath + [k], child)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, keypath + [str(i)], must_encrypt)
        # sops leaves empty values (null, "") unencrypted
        elif must_encrypt and node not in (None, "") and not (isinstance(node, str) and node.startswith("ENC[")):
            plain.append(".".join(keypath))

    for key, value in doc.items():
        if key != "sops":
            walk({key: value}, [], enc_re is None)
    if plain:
        print(f"NOT ENCRYPTED: {path}: {', '.join(plain)}", file=sys.stderr)
        rc = 1
sys.exit(rc)
PY
