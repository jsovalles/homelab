#!/usr/bin/env bash
# Role READMEs list every variable of meta/argument_specs.yml (the single source of truth), and
# every variable in defaults/main.yml must be declared there.
#   scripts/check-role-docs.sh         check (pre-commit, CI)
#   scripts/check-role-docs.sh --fix   rewrite the README tables (make role-docs)
set -Eeuo pipefail

# PyYAML: use the repo venv (pinned, see requirements.lock) when it exists – the git hook runs
# with the user's PATH, where the system python3 may not have it; CI's python3 has it
PYTHON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.venv/bin/python3"
[[ -x "$PYTHON" ]] || PYTHON=python3
cd "$(dirname "${BASH_SOURCE[0]}")/../infrastructure/ansible/roles"

"$PYTHON" - "$@" <<'PY'
import os
import sys

import yaml

fix = "--fix" in sys.argv[1:]
header = "| Variable | Type | Description |\n|---|---|---|\n"
footer = "Defaults: `defaults/main.yml`."
rc = 0

for role in sorted(os.listdir(".")):
    spec_file = f"{role}/meta/argument_specs.yml"
    if not os.path.isfile(spec_file):
        continue
    options = yaml.safe_load(open(spec_file))["argument_specs"]["main"].get("options") or {}
    defaults_file = f"{role}/defaults/main.yml"
    defaults = (yaml.safe_load(open(defaults_file)) or {}) if os.path.isfile(defaults_file) else {}
    undeclared = sorted(set(defaults) - set(options))
    if undeclared:
        print(f"{role}: defaults not declared in meta/argument_specs.yml: {', '.join(undeclared)}", file=sys.stderr)
        rc = 1

    rows = "".join(
        f"| `{name}` | {opt.get('type', 'raw')} | {str(opt.get('description', '')).replace('|', chr(92) + '|')} |\n"
        for name, opt in options.items()
    )
    table = header + rows if options else ""

    readme_file = f"{role}/README.md"
    readme = open(readme_file).read()
    if header in readme:  # replace the existing table (header up to the first non-table line)
        start = readme.index(header)
        end = start
        lines = readme[start:].splitlines(keepends=True)
        for line in lines:
            if not line.startswith("|"):
                break
            end += len(line)
        new = readme[:start] + table + readme[end:]
    elif table:  # add it before the "Defaults:" line, or at the end
        if footer in readme:
            i = readme.index(footer)
            new = readme[:i] + table + "\n" + readme[i:]
        else:
            new = readme.rstrip("\n") + "\n\n" + table + "\n" + footer + "\n"
    else:
        new = readme

    if new != readme:
        if fix:
            open(readme_file, "w").write(new)
            print(f"{role}: README table updated")
        else:
            print(f"{role}: README variable table is out of date (run `make role-docs`)", file=sys.stderr)
            rc = 1
sys.exit(rc)
PY
