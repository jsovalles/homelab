#!/usr/bin/env bash
# Phase 0 – install tooling and initialise SOPS/age.
# Safe to re-run. Works on the Proxmox host (Debian 13) or any Debian/Ubuntu box.
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# renovate: datasource=github-releases depName=getsops/sops
SOPS_VERSION="3.10.2"
# renovate: datasource=github-releases depName=opentofu/opentofu
TOFU_VERSION="1.12.5"
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
SECRETS_FILE="$REPO_ROOT/infrastructure/ansible/inventory/group_vars/all/secrets.sops.yaml"
SECRETS_EXAMPLE="$REPO_ROOT/infrastructure/ansible/inventory/secrets.example.yaml"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

need_root() { [ "$(id -u)" -eq 0 ] || { echo "run as root (or via sudo)"; exit 1; }; }

install_packages() {
  need_root
  log "Installing base packages"
  apt-get update -qq
  apt-get install -y -qq git curl ca-certificates age python3-venv make xz-utils rsync shellcheck >/dev/null

  # sops only checksums its static binaries (not the .deb)
  install_verified sops "$SOPS_VERSION" \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}" \
    "sops-v${SOPS_VERSION}.linux.amd64" "sops-v${SOPS_VERSION}.checksums.txt"
  install_verified tofu "$TOFU_VERSION" \
    "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}" \
    "tofu_${TOFU_VERSION}_amd64.deb" "tofu_${TOFU_VERSION}_SHA256SUMS"
}

# Download a release asset (.deb or static binary) + its checksum list and
# install it only if the SHA256 matches.
install_verified() {
  local -r name="$1" version="$2" base_url="$3" asset="$4" sums="$5"
  if command -v "$name" >/dev/null && "$name" --version 2>/dev/null | grep -q "$version"; then
    return 0
  fi
  log "Installing $name $version (checksum verified)"
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064 # expand now: tmp is local
  trap "rm -rf -- '$tmp'" RETURN
  curl -fsSL -o "$tmp/$asset" "$base_url/$asset"
  curl -fsSL -o "$tmp/$sums" "$base_url/$sums"
  grep -qE " [*]?${asset//./\\.}\$" "$tmp/$sums" || { echo "$asset not listed in $sums" >&2; exit 1; }
  (cd "$tmp" && grep -E " [*]?${asset//./\\.}\$" "$sums" | sha256sum -c --status) \
    || { echo "checksum mismatch for $asset" >&2; exit 1; }
  if [[ "$asset" == *.deb ]]; then
    apt-get install -y -qq "$tmp/$asset" >/dev/null
  else
    install -m 0755 "$tmp/$asset" "/usr/local/bin/$name"
  fi
}

install_ansible() {
  if [ ! -x "$REPO_ROOT/.venv/bin/ansible-playbook" ]; then
    log "Creating Python venv with Ansible"
    python3 -m venv "$REPO_ROOT/.venv"
  fi
  "$REPO_ROOT/.venv/bin/pip" install -q --upgrade pip
  # requirements.lock = fully resolved, reproducible set (regenerate after bumping requirements.txt)
  "$REPO_ROOT/.venv/bin/pip" install -q -r "$REPO_ROOT/infrastructure/ansible/requirements.lock"
  log "Installing Ansible collections"
  (cd "$REPO_ROOT/infrastructure/ansible" && "$REPO_ROOT/.venv/bin/ansible-galaxy" collection install -r requirements.yml)
}

init_age() {
  if [ ! -f "$AGE_KEY_FILE" ]; then
    log "Generating age key at $AGE_KEY_FILE  (BACK THIS UP – e.g. in a password manager!)"
    mkdir -p "$(dirname "$AGE_KEY_FILE")"
    age-keygen -o "$AGE_KEY_FILE"
    chmod 600 "$AGE_KEY_FILE"
  fi
  local pub
  pub="$(age-keygen -y "$AGE_KEY_FILE")"
  if grep -q AGE_PUBLIC_KEY_PLACEHOLDER "$REPO_ROOT/.sops.yaml"; then
    log "Writing age recipient $pub to .sops.yaml"
    sed -i "s|AGE_PUBLIC_KEY_PLACEHOLDER|$pub|" "$REPO_ROOT/.sops.yaml"
  fi
}

init_secrets() {
  if [ ! -f "$SECRETS_FILE" ]; then
    log "Creating encrypted secrets file from example"
    cp "$SECRETS_EXAMPLE" "$SECRETS_FILE"
    (cd "$REPO_ROOT" && sops --encrypt --in-place "$SECRETS_FILE")
  fi
  randomise_placeholders
}

# Replace "change-me" placeholders with random values (only ones still unset)
randomise_placeholders() {
  local key value
  for key in tofu_state_passphrase gotify_admin_password; do
    value="$(cd "$REPO_ROOT" && sops -d --extract "[\"$key\"]" "$SECRETS_FILE")"
    if [[ "$value" == change-me* ]]; then
      log "Generating random value for $key"
      (cd "$REPO_ROOT" && sops set "$SECRETS_FILE" "[\"$key\"]" "\"$(openssl rand -base64 33 | tr -d '/+=')\"")
    fi
  done
  log "Fill in homelab_env_secrets with: make secrets"
}

install_packages
install_ansible
init_age
init_secrets
log "Bootstrap complete."
