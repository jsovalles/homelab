#!/usr/bin/env bash
# Block site-identifying data (LAN IPs, MACs, the homelab domain) from being committed.
#
# Layer 1 (always, also in CI): generic patterns – private IPv4 literals, IPv6 ULAs, MAC addresses,
#   *.duckdns.org hostnames. Allowed: Docker's internal 172.30.0.0/24, wg-easy's default
#   10.8.0.0/24, 127.x, and placeholder forms like <lan>.4 or 192.168.X.0.
# Layer 2 (when the age key is available): the exact values stored in site.sops.yaml,
#   decrypted in memory only.
#
# Usage: scripts/check-no-site-data.sh [files...]   (default: all files git would track)
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SITE_FILE="$REPO_ROOT/infrastructure/ansible/inventory/group_vars/all/site.sops.yaml"

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  mapfile -t files < <(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard)
fi

# Encrypted files, lock files and this script itself are not checked
filtered=()
for f in "${files[@]}"; do
  case "$f" in
    *.sops.yaml|*.sops.yml|*.sops.json|*.lock|*.lock.hcl|scripts/check-no-site-data.sh) ;;
    *) [[ -f "$f" ]] && filtered+=("$f") ;;
  esac
done
[[ ${#filtered[@]} -gt 0 ]] || exit 0

rc=0
report() { printf 'site data in %s\n' "$1" >&2; rc=1; }

# --- Layer 1: generic patterns -------------------------------------------------------
# PCRE lookarounds: the boundaries are checked, not consumed, so adjacent addresses
# ("172.30.0.3,192.168.1.5") are each matched in full and judged on their own
private_ip='(?<![0-9.])(192\.168\.[0-9]{1,3}\.[0-9]{1,3}|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})(?![0-9])'
# matched against "<line>:<address>" output, so anchored to the whole address
allowed_ip=':(172\.30\.0\.[0-9]{1,3}|10\.8\.0\.[0-9]{1,3})$'
mac='(^|[^0-9A-Fa-f:])([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}([^0-9A-Fa-f:]|$)'
ula='(^|[^0-9A-Fa-f:])[fF][cdCD][0-9A-Fa-f]{2}:[0-9A-Fa-f:]{2,}'
duckdns='[A-Za-z0-9-]+\.duckdns\.org'

# Findings are captured in full, never piped into `grep -q`: with pipefail an early-exiting
# grep -q kills the upstream grep (SIGPIPE) and turns a finding into a pass on large files.
for f in "${filtered[@]}"; do
  ips="$(grep -nPo "$private_ip" "$f" | grep -vE "$allowed_ip" || true)"
  if [[ -n "$ips" ]]; then
    while IFS= read -r hit; do printf '  %s:%s\n' "$f" "$hit" >&2; done <<<"$ips"
    report "$f (private IP literal – use a variable from site.sops.yaml)"
  fi
  if grep -qE "$ula" "$f"; then
    report "$f (IPv6 ULA address – keep it in site.sops.yaml)"
  fi
  if grep -qE "$mac" "$f"; then
    report "$f (MAC address – keep it in site.sops.yaml)"
  fi
  hosts="$(grep -nEo "$duckdns" "$f" | grep -vE '(^|:)(your|example|yourname|myname)[^:]*\.duckdns\.org' || true)"
  if [[ -n "$hosts" ]]; then
    report "$f (duckdns hostname – use homelab_domain)"
  fi
done

# --- Layer 2: exact site values --------------------------------------------------------
if command -v sops >/dev/null && sops -d --output-type json "$SITE_FILE" >/dev/null 2>&1; then
  # Decrypted values never go into command arguments: JSON through a pipe, literals into a
  # private pattern file read by grep -f.
  patterns="$(mktemp)"
  chmod 600 "$patterns"
  trap 'rm -f -- "$patterns"' EXIT
  sops -d --output-type json "$SITE_FILE" | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
keys = re.compile(r"^(homelab_domain|letsencrypt_email|node_addresses|ip|mac|gateway|dns_servers|.*_ip|.*_url|.*_cidrs)$")
public_dns = {"1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4", "9.9.9.9"}
def walk(node, sensitive=False):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk(v, sensitive or bool(keys.match(k)))
    elif isinstance(node, list):
        for v in node:
            yield from walk(v, sensitive)
    elif sensitive and isinstance(node, str) and node not in public_dns and len(node) >= 6:
        yield node
print("\n".join(sorted(set(walk(data)))))
' >"$patterns"
  if [[ -s "$patterns" ]]; then
    for f in "${filtered[@]}"; do
      if grep -qiFf "$patterns" -- "$f"; then
        report "$f (contains a value from site.sops.yaml)"
      fi
    done
  fi
fi

if [[ $rc -ne 0 ]]; then
  echo "Move these values to site.sops.yaml (make site-config) and reference them as variables." >&2
fi
exit "$rc"
