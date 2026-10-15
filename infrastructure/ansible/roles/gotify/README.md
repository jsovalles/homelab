# gotify

Installs/updates Gotify server as a systemd service inside an LXC.

| Variable | Type | Description |
|---|---|---|
| `gotify_version` | str | Release tag or 'latest' |
| `gotify_dir` | path | Install directory |
| `gotify_user` | str | System user the service runs as (owns only data/) |
| `gotify_port` | int | HTTP port |
| `gotify_admin_user` | str | Initial admin user |
| `gotify_default_admin_password` | str | Gotify's built-in admin password, replaced by `gotify_admin_password` |

Defaults: `defaults/main.yml`.
