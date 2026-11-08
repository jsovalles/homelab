# auto_updates

Configures Debian unattended-upgrades (security + stable updates, daily window, optional reboot).

| Variable | Type | Description |
|---|---|---|
| `auto_updates_origins` | list | Origins-Pattern entries allowed to upgrade |
| `auto_updates_time` | str | Daily upgrade time (HH:MM) |
| `auto_updates_timezone` | str | Timezone appended to OnCalendar (empty = guest local time) |
| `auto_updates_random_delay` | str | systemd RandomizedDelaySec |
| `auto_updates_reboot` | bool | Reboot automatically when required |
| `auto_updates_reboot_time` | str | Time of the automatic reboot (HH:MM) |

Defaults: `defaults/main.yml`.
