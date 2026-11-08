# 0006 – HAOS image imported with `file_id` (SSH)

## Context
HAOS ships as `.qcow2.xz`. Proxmox's download-url only decompresses for content `iso`
(gz/lzo/zst/bz2); its `zst` path runs `zstd -d`, which also reads xz. The API-only
`import_from` disk attribute only accepts content `import` volumes.

## Decision
Download HAOS as content `iso` (`.img`) with `decompression_algorithm = "zst"` and attach it
with `file_id`, which bpg imports via SSH (`qm disk import`).

## Consequences
- Fully declarative HAOS VM, checksum-verified, no Ansible `qm` scripting.
- Needs root SSH to the node (bpg warns against granting `qm` via sudo). Revisit if Proxmox
  adds decompression for `import` content.
