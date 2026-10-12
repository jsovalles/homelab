# haos_check

Verifies the HAOS VM (created by OpenTofu) is running and its web UI answers.

| Variable | Type | Description |
|---|---|---|
| `haos_vmid` | int | VMID of the HAOS VM |
| `haos_port` | int | Web UI port |
| `haos_wait_retries` | int | Retries while waiting for the UI |
| `haos_wait_delay` | int | Seconds between retries |

Defaults: `defaults/main.yml`.
