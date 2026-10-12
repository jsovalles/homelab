#!/usr/bin/env bash
# Rebuild test in an isolated scratch environment:
#   tofu workspace "test" (VMIDs 91xx, test IPs)  +  ansible inventory/test.yml
# 1. create the guests in scope  2. run their playbooks  3. run them again → must report
# changed=0  4. destroy (unless KEEP=1)
#
# SCOPE (default: auto)
#   auto     pick from the files changed in git (docs-only → nothing to test)
#   all      everything (big changes, before a PR)
#   docker | haos | lxc | myspeed | gotify | host   only that part
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- scope
scope_from_git() {
  if ! git rev-parse --verify -q HEAD >/dev/null; then echo all; return; fi
  scope_from_files "$( { git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u)"
}

# Map changed paths to test parts (one path per line)
scope_from_files() {
  local files="$1" f
  [[ -z "$files" ]] && { echo none; return; }
  local -A s=()
  while IFS= read -r f; do
    case "$f" in
      *.md|docs/*|LICENSE|.gitignore|renovate.json5|.github/*) ;;            # no runtime effect
      docker/*|infrastructure/ansible/files/*|\
      infrastructure/ansible/inventory/group_vars/docker_hosts/*|\
      infrastructure/ansible/playbooks/04-*|infrastructure/ansible/playbooks/9[0-9]-*|\
      infrastructure/ansible/roles/docker/*|infrastructure/ansible/roles/traefik/*|\
      infrastructure/ansible/roles/homelab_stack/*|infrastructure/ansible/roles/ssh_access/*|\
      infrastructure/ansible/roles/console_access/*)                         s[docker]=1 ;;
      infrastructure/ansible/roles/gotify/*)                                 s[gotify]=1 ;;
      infrastructure/ansible/roles/myspeed/*)                                s[myspeed]=1 ;;
      infrastructure/ansible/playbooks/03-*|\
      infrastructure/ansible/inventory/group_vars/lxc_apps.yml)              s[lxc]=1 ;;
      infrastructure/ansible/roles/auto_updates/*)                           s[docker]=1; s[lxc]=1 ;;
      infrastructure/ansible/roles/haos_check/*|infrastructure/ansible/playbooks/02-*|\
      infrastructure/ansible/inventory/group_vars/homeassistant.yml)         s[haos]=1 ;;
      infrastructure/ansible/roles/pve_host/*|infrastructure/ansible/playbooks/01-*|\
      infrastructure/ansible/inventory/group_vars/proxmox.yml)               s[host]=1 ;;
      *)                                                                     echo all; return ;;
    esac
  done <<<"$files"
  # lxc covers both containers
  if [[ -n "${s[lxc]:-}" ]]; then unset 's[gotify]' 's[myspeed]'; fi
  [[ ${#s[@]} -eq 0 ]] && { echo none; return; }
  echo "${!s[@]}"
}

# `test-rebuild.sh --scope-for <files…>` prints the scope only (used to test the mapping)
if [[ "${1:-}" == --scope-for ]]; then shift; scope_from_files "$(printf '%s\n' "$@")"; exit 0; fi

SCOPE="${SCOPE:-auto}"
[[ "$SCOPE" == auto ]] && SCOPE="$(scope_from_git)"
[[ " $SCOPE " == *" all "* ]] && SCOPE=all
if [[ "$SCOPE" == none ]]; then
  log "Only documentation changed – nothing to test (use SCOPE=all to force)"
  exit 0
fi
log "Test scope: $SCOPE"

targets=()      # -target=… for OpenTofu (empty = everything)
playbooks=()    # "playbook[|--limit host]"
for part in $SCOPE; do
  case "$part" in
    all)     targets=(); playbooks=("site.yml"); break ;;
    docker)  targets+=('-target=module.cloud_vm["docker"]');     playbooks+=("04-docker-host.yml") ;;
    haos)    targets+=('-target=module.appliance_vm["haos"]');   playbooks+=("02-haos.yml") ;;
    lxc)     targets+=('-target=module.lxc');                    playbooks+=("03-lxc-apps.yml") ;;
    myspeed) targets+=('-target=module.lxc["test-myspeed"]');    playbooks+=("03-lxc-apps.yml|test-myspeed") ;;
    gotify)  targets+=('-target=module.lxc["test-gotify"]');     playbooks+=("03-lxc-apps.yml|test-gotify") ;;
    host)    playbooks+=("01-pve-host.yml") ;;
    *) echo "unknown SCOPE part: $part" >&2; exit 2 ;;
  esac
done
needs_guests=true
[[ "$SCOPE" == host ]] && needs_guests=false

# ---------------------------------------------------------------- helpers
forget_host_keys() {
  # Test VMs get new host keys on every rebuild: drop the old known_hosts entries
  local ip
  for ip in $(./scripts/tofu.sh test console -lock=false -state=/nonexistent/none.tfstate <<<'nonsensitive(jsonencode([for k, v in var.cloud_vms : var.guest_network[k].ip]))' \
              | python3 -c 'import json,sys; print(" ".join(json.loads(json.loads(sys.stdin.read().strip().splitlines()[-1]))))'); do
    ssh-keygen -R "$ip" >/dev/null 2>&1 || true
  done
}

cleanup() {
  if [ "${KEEP:-0}" != "1" ]; then
    forget_host_keys
    log "Destroying test environment"
    make --no-print-directory tf-destroy ENV=test TF_ARGS=-auto-approve || true
  else
    log "KEEP=1 – leaving test guests running"
  fi
}

run_playbooks() {
  local entry pb limit
  for entry in "${playbooks[@]}"; do
    pb="${entry%%|*}"; limit=""
    [[ "$entry" == *"|"* ]] && limit="--limit ${entry#*|}"
    make --no-print-directory -s ENV=test ARGS="$limit" ansible-run PLAYBOOK="playbooks/$pb"
  done
}

# ---------------------------------------------------------------- run
make --no-print-directory tf-init
log "Removing any leftover test environment"
make --no-print-directory tf-destroy ENV=test TF_ARGS=-auto-approve
forget_host_keys
trap cleanup EXIT

if $needs_guests; then
  log "Creating test guests${targets[*]:+ (${targets[*]})}"
  # One retry: Proxmox's API proxy recycles workers and can drop a long download-url request (EOF).
  # Re-planning is safe – everything already created stays in state.
  tf_targets="$(printf "'%s' " "${targets[@]}")"   # keep the quotes in module.x["key"] through make
  [[ ${#targets[@]} -eq 0 ]] && tf_targets=""
  if ! { make --no-print-directory tf-plan ENV=test TF_ARGS="$tf_targets" && make --no-print-directory tf-apply ENV=test; }; then
    log "Apply failed – retrying once (transient Proxmox API/download errors)"
    make --no-print-directory tf-plan ENV=test TF_ARGS="$tf_targets"
    make --no-print-directory tf-apply ENV=test
  fi
fi

log "First run"
run_playbooks

log "Second run – checking idempotency"
out="$(run_playbooks 2>&1 | tee /dev/stderr)"
recap="$(sed -n '/PLAY RECAP/,$p' <<<"$out")"
if grep -E 'changed=[1-9]|failed=[1-9]|unreachable=[1-9]' <<<"$recap"; then
  log "FAIL: second run was not idempotent / had failures"
  exit 1
fi
log "PASS: scope '$SCOPE' rebuilds and is idempotent"
