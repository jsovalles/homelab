# homelab_stack

Syncs docker/ to the VM, renders .env from vars + SOPS, seeds app-owned config from SOPS and runs docker compose.

| Variable | Type | Description |
|---|---|---|
| `homelab_stack_src` | path | Local docker/ directory |
| `homelab_stack_dir` | path | Destination on the VM |
| `homelab_stack_env` | dict | Variables of .env (plain values, quoted by the template) |
| `homelab_stack_compose_up` | bool | Start the stack |
| `homelab_stack_compose_services` | list | Subset of services ([] = all) |
| `homelab_stack_compose_pull` | str | Image pull policy (always = update images) |
| `homelab_stack_compose_wait_timeout` | int | Seconds to wait for containers to be running/healthy |
| `homelab_stack_http_checks` | list | HTTP endpoints ({name, url}) checked from the VM after deploy |
| `homelab_stack_config_dirs` | list | Directories under config/ created for compose bind mounts |
| `homelab_stack_config_seeds` | list | SOPS files (src, dest, format, mode) written to the host only when missing |
| `homelab_stack_config_seeds_dir` | path | Directory holding the SOPS seed files |

Defaults: `defaults/main.yml`.
