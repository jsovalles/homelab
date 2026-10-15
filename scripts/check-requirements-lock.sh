#!/usr/bin/env bash
# Fail when a pin in infrastructure/ansible/requirements.txt (bumped by Renovate) differs from
# requirements.lock (what bootstrap and CI install). Fix: make lock
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../infrastructure/ansible"

python3 - <<'PY'
import re
import sys

norm = lambda n: re.sub(r"[-_.]+", "-", n).lower()
pins = lambda path: {norm(n): v for n, v in re.findall(r"^([A-Za-z0-9_.-]+)==([^\s\\;#]+)", open(path).read(), re.M)}
wanted, locked = pins("requirements.txt"), pins("requirements.lock")
bad = [f"{n}: requirements.txt {v} != lock {locked.get(n, 'missing')}" for n, v in wanted.items() if locked.get(n) != v]
if bad:
    print("requirements.lock is out of date (run `make lock`):\n  " + "\n  ".join(bad), file=sys.stderr)
    sys.exit(1)
PY
