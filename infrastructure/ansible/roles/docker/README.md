# docker

Installs Docker CE + compose plugin; frees port 53 from systemd-resolved where it runs.

| Variable | Type | Description |
|---|---|---|
| `docker_legacy_apt_sources` | list | Older Docker repository files replaced by `docker.sources` |

Defaults: `defaults/main.yml`.
