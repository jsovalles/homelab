# haos_check

Verifies the HAOS VM (created by OpenTofu) is running and its web UI answers.

| Variable | Type | Description |
|---|---|---|
| `haos_check_vmid` | int | VMID of the HAOS VM |
| `haos_check_port` | int | Web UI port |
| `haos_check_wait_retries` | int | Retries while waiting for the UI |
| `haos_check_wait_delay` | int | Seconds between retries |

Defaults: `defaults/main.yml`.
