# traefik

Renders `traefik.yml` and the dynamic files (`config.yml`, `internal.yml`, `middleware.yaml`) into
`config/traefik/` on the Docker host. Routes come from `traefik_services`; the domain, LAN IPs,
ACME email and basic-auth hash come from SOPS (`site.sops.yaml`, `secrets.sops.yaml`).

Only a change to `traefik.yml` restarts the container; dynamic files are hot-reloaded.
Set `traefik_acme_enabled: false` to run without Let's Encrypt (test environment).

Internal routes use `<subdomain>.home.arpa` (RFC 8375), not `.local` (reserved for mDNS).
AdGuard must rewrite `*.home.arpa` to the Docker host.

| Variable | Type | Description |
|---|---|---|
| `traefik_dir` | path | Config directory on the host (mounted by compose) |
| `traefik_container` | str | Container restarted when traefik.yml changes |
| `traefik_domain` | str | Base domain for https routes |
| `traefik_acme_enabled` | bool | Request Let's Encrypt certificates (DuckDNS DNS challenge) |
| `traefik_acme_staging` | bool | Use the Let's Encrypt staging CA |
| `traefik_acme_email` | str | ACME account email |
| `traefik_internal_routes` | bool | Also render <subdomain>.<internal domain> HTTP routes |
| `traefik_internal_domain` | str | Internal LAN domain (default home.arpa, RFC 8375) |
| `traefik_legacy_dynamic_files` | list | Old dynamic files to delete |
| `traefik_allowed_cidrs` | list | Source ranges allowed on the https entrypoint |
| `traefik_tinyauth_url` | str | Base URL of tinyauth for forward auth |
| `traefik_basic_auth_users` | raw | htpasswd line(s) for the dashboard |
| `traefik_services` | list | Routes: name, subdomain, url\|service, insecure_tls, middlewares, internal |

Defaults: `defaults/main.yml`.
