# gotify

Installs/updates Gotify server as a systemd service inside an LXC.

| Variable | Type | Description |
|---|---|---|
| `gotify_version` | str | Release tag or 'latest' |
| `gotify_dir` | path | Install directory |
| `gotify_port` | int | HTTP port |
| `gotify_admin_user` | str | Initial admin user |

Defaults: `defaults/main.yml`.
