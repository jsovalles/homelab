# homelab_stack

Syncs docker/ to the VM, renders .env from vars + SOPS, seeds app-owned config from SOPS and runs docker compose.

| Variable | Type | Description |
|---|---|---|
| `homelab_src` | path | Local docker/ directory |
| `homelab_dir` | path | Destination on the VM |
| `homelab_env` | dict | Variables of .env (plain values, quoted by the template) |
| `homelab_compose_up` | bool | Start the stack |
| `homelab_compose_services` | list | Subset of services ([] = all) |
| `homelab_compose_wait_timeout` | int | Seconds to wait for containers to be running/healthy |

Defaults: `defaults/main.yml`.
