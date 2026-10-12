#!/usr/bin/env bash
# Wrapper around `tofu` for this repo:
#   - decrypts the state passphrase from SOPS (never written to disk)
#   - selects the workspace for the environment (prod → default, test → test)
#   - adds the env var-file to commands that evaluate variables
#   - refuses to destroy production unless CONFIRM=destroy-prod
#
# Usage: scripts/tofu.sh <prod|test> <tofu subcommand> [args...]
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TF_DIR="$REPO_ROOT/infrastructure/terraform"
SOPS_FILE="$REPO_ROOT/infrastructure/ansible/inventory/group_vars/all/secrets.sops.yaml"
SITE_FILE="$REPO_ROOT/infrastructure/ansible/inventory/group_vars/all/site.sops.yaml"

die() { printf 'tofu.sh: %s\n' "$*" >&2; exit 1; }

[[ $# -ge 2 ]] || die "usage: $0 <prod|test> <subcommand> [args...]"
env_name="$1"; shift
subcommand="$1"; shift

case "$env_name" in
  prod) workspace="default"; var_file=() ;;
  test) workspace="test";    var_file=("-var-file=envs/test.tfvars") ;;
  *)    die "unknown environment '$env_name' (expected prod or test)" ;;
esac

command -v tofu >/dev/null || die "tofu not installed – run make bootstrap"
command -v sops >/dev/null || die "sops not installed – run make bootstrap"

# Production guard: every way of destroying (destroy, plan/apply -destroy) needs CONFIRM, and the
# protection flag cannot be switched off from the command line.
if [[ "$env_name" == "prod" ]]; then
  destroys=false
  [[ "$subcommand" == "destroy" ]] && destroys=true
  for arg in "$@"; do
    [[ "$arg" == "-destroy" || "$arg" == "--destroy" ]] && destroys=true
    [[ "$arg" == *protect_guests* ]] && die "protect_guests cannot be overridden for production (edit terraform.tfvars in a reviewed change)."
  done
  if $destroys && [[ "${CONFIRM:-}" != "destroy-prod" ]]; then
    die "refusing to destroy production. Re-run with CONFIRM=destroy-prod (guests also have Proxmox protection enabled)."
  fi
fi

TF_VAR_state_passphrase="$(sops -d --extract '["tofu_state_passphrase"]' "$SOPS_FILE")" \
  || die "cannot decrypt tofu_state_passphrase (age key missing?)"
export TF_VAR_state_passphrase

# Site data (IPs, MACs, gateway…) for this environment: every top-level key becomes
# TF_VAR_<key> holding JSON (valid HCL). Kept in memory only, never written to disk.
site_json="$(sops -d --extract "[\"terraform\"][\"$env_name\"]" --output-type json "$SITE_FILE")" \
  || die "cannot decrypt terraform.$env_name from $SITE_FILE"
while IFS= read -r -d '' name && IFS= read -r -d '' value; do
  export "TF_VAR_${name}=${value}"
done < <(python3 -c 'import json,sys
for k, v in json.loads(sys.stdin.read()).items():
    sys.stdout.write(k + "\0" + json.dumps(v) + "\0")' <<<"$site_json")
unset site_json

cd "$TF_DIR"

# Workspace management itself must run without TF_WORKSPACE pinned
if [[ "$subcommand" == "init" ]]; then
  tofu init "$@"
  tofu workspace list | grep -qE '^\*? +test$' || tofu workspace new test >/dev/null
  tofu workspace select default >/dev/null
  exit 0
fi

export TF_WORKSPACE="$workspace"
case "$subcommand" in
  plan|apply|destroy|console|import|refresh)
    exec tofu "$subcommand" "${var_file[@]}" "$@" ;;
  *)
    exec tofu "$subcommand" "$@" ;;
esac
