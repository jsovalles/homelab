# docker

Installs Docker CE + compose plugin; frees port 53 from systemd-resolved where it runs.

| Variable | Type | Description |
|---|---|---|
| `docker_host_dns_servers` | list | Upstream DNS servers for the Docker host (systemd-resolved) |
| `docker_legacy_apt_sources` | list | Docker repository files in sources.list.d replaced by docker.sources |

Defaults: `defaults/main.yml`.
