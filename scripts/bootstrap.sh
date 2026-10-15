#!/usr/bin/env bash
# Phase 0 – install tooling and initialise SOPS/age.
# Safe to re-run. Works on the Proxmox host (Debian 13) or any Debian/Ubuntu box.
# Run as the user that will operate the repo (root on a Proxmox host): only the system
# packages are installed with sudo, the venv and the age key belong to the invoking user.
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

# Root already (fresh Proxmox host: no sudo installed) or sudo for package installs only
SUDO=()
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null || { echo "not root and sudo is not installed" >&2; exit 1; }
  SUDO=(sudo)
fi
ARCH="$(dpkg --print-architecture)" # amd64 | arm64 – both are published by sops and OpenTofu

# A fresh Proxmox VE install enables the enterprise repositories, which answer 401 without a
# subscription and make `apt-get update` fail. Switch to the no-subscription repositories with
# the same files Phase 1 (pve_host/tasks/apt.yml) manages, so Phase 1 finds them in place.
use_pve_no_subscription_repos() {
  [ -f /etc/apt/sources.list.d/pve-enterprise.sources ] || return 0
  grep -q '^Enabled: no' /etc/apt/sources.list.d/pve-enterprise.sources && return 0
  local release
  # shellcheck disable=SC1091 # system file
  release="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  log "Proxmox VE: disabling the enterprise repositories (no subscription)"
  "${SUDO[@]}" tee /etc/apt/sources.list.d/pve-enterprise.sources >/dev/null <<EOF
# Managed by Ansible – no subscription
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: $release
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
Enabled: no
EOF
  "${SUDO[@]}" tee /etc/apt/sources.list.d/proxmox.sources >/dev/null <<EOF
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: $release
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
  # The installer's ceph.sources points at the enterprise Ceph repository too; Phase 1 writes
  # the no-subscription one
  "${SUDO[@]}" rm -f /etc/apt/sources.list.d/ceph.sources
}

install_packages() {
  use_pve_no_subscription_repos
  log "Installing base packages"
  "${SUDO[@]}" apt-get update -qq
  "${SUDO[@]}" apt-get install -y -qq git curl ca-certificates age python3-venv make xz-utils rsync shellcheck openssl >/dev/null

  # sops only checksums its static binaries (not the .deb)
  install_verified sops "$SOPS_VERSION" \
    "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}" \
    "sops-v${SOPS_VERSION}.linux.${ARCH}" "sops-v${SOPS_VERSION}.checksums.txt"
  install_verified tofu "$TOFU_VERSION" \
    "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}" \
    "tofu_${TOFU_VERSION}_${ARCH}.deb" "tofu_${TOFU_VERSION}_SHA256SUMS"
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
    "${SUDO[@]}" apt-get install -y -qq "$tmp/$asset" >/dev/null
  else
    "${SUDO[@]}" install -m 0755 "$tmp/$asset" "/usr/local/bin/$name"
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
  log "Fill in homelab_secrets with: make secrets"
}

install_packages
install_ansible
init_age
init_secrets
log "Bootstrap complete."
