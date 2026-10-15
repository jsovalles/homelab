# base

Common baseline for every host: timezone and per-group base packages. Runs first in the
Proxmox host, LXC and Docker plays.

| Variable | Type | Description |
|---|---|---|
| `base_timezone` | str | Timezone (default: `timezone` from group_vars/all) |
| `base_packages` | list | Extra packages for the hosts of a group (roles install their own) |

Defaults: `defaults/main.yml`.
