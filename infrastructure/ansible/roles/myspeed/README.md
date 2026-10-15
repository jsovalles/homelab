# myspeed

Installs/updates MySpeed (Node.js) as a systemd service inside an LXC.

| Variable | Type | Description |
|---|---|---|
| `myspeed_version` | str | Release tag or 'latest' |
| `myspeed_dir` | path | Install directory |
| `myspeed_user` | str | System user the service runs as (owns only data/ and bin/) |
| `myspeed_node_major` | int | Node.js major version |
| `myspeed_port` | int | HTTP port used by the health check |

Defaults: `defaults/main.yml`.
