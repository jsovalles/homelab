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
    case "$arg" in
      -destroy|--destroy) destroys=true ;;
      # boolean flag with a value (-destroy=true, =1, =t…): only explicit false is not a destroy
      -destroy=*|--destroy=*) [[ "${arg#*=}" =~ ^([Ff]([Aa][Ll][Ss][Ee])?|0)$ ]] || destroys=true ;;
    esac
    [[ "$arg" == *protect_guests* ]] && die "protect_guests cannot be overridden for production (edit terraform.tfvars in a reviewed change)."
    # a var-file passed on the command line could set it too
    if [[ "$arg" == -var-file=* || "$arg" == --var-file=* ]] && grep -q protect_guests -- "$TF_DIR/${arg#*=}" "${arg#*=}" 2>/dev/null; then
      die "protect_guests cannot be overridden for production (found in ${arg#*=})."
    fi
  done
  [[ -n "${TF_VAR_protect_guests+set}" ]] \
    && die "protect_guests cannot be overridden for production (unset TF_VAR_protect_guests)."
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

# Proxmox LXC template index (URLs + checksums of the templates). download.proxmox.com has no
# valid TLS certificate, so verify its GPG signature with the Proxmox release key – the key
# `pveam` trusts – before OpenTofu uses it. Applying a saved plan reuses the planned values.
APLINFO_URL="http://download.proxmox.com/images/aplinfo-pve-9.dat"
APLINFO_KEY="$TF_DIR/keys/proxmox-release-trixie.asc"
APLINFO_FPR="24B30F06ECC1836A4E5EFECBA7BCD1420BFE778E" # Proxmox Trixie Release Key

needs_template_index() {
  case "$subcommand" in
    plan|refresh|import|destroy) return 0 ;;
    apply)
      # a saved plan file (an existing file argument – not the value of an option like
      # `-parallelism 1`) reuses the planned values
      local arg
      for arg in "$@"; do
        [[ "$arg" != -* && ( -f "$TF_DIR/$arg" || -f "$arg" ) ]] && return 1
      done
      return 0 ;;
    *) return 1 ;;
  esac
}

if needs_template_index "$@"; then
  command -v gpg >/dev/null || die "gpg not installed – run make bootstrap"
  aplinfo_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$aplinfo_tmp"' EXIT
  if ! curl -fsSL --retry 3 -o "$aplinfo_tmp/aplinfo.dat" "$APLINFO_URL" \
     || ! curl -fsSL --retry 3 -o "$aplinfo_tmp/aplinfo.dat.asc" "$APLINFO_URL.asc"; then
    die "cannot download the Proxmox template index ($APLINFO_URL)"
  fi
  mkdir -m 0700 "$aplinfo_tmp/gnupg"
  gpg --homedir "$aplinfo_tmp/gnupg" --batch --quiet --import "$APLINFO_KEY" 2>/dev/null
  gpg --homedir "$aplinfo_tmp/gnupg" --batch --status-fd 1 \
      --verify "$aplinfo_tmp/aplinfo.dat.asc" "$aplinfo_tmp/aplinfo.dat" 2>/dev/null \
    | grep -q "^\[GNUPG:\] VALIDSIG $APLINFO_FPR " \
    || die "BAD SIGNATURE on the Proxmox template index – refusing to use it"
  TF_VAR_pve_aplinfo="$(<"$aplinfo_tmp/aplinfo.dat")"
  export TF_VAR_pve_aplinfo
  rm -rf -- "$aplinfo_tmp"
  trap - EXIT
fi

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
