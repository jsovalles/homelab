# traefik

Renders `traefik.yml` and the dynamic files (`config.yml`, `internal.yml`, `middleware.yaml`) into
`config/traefik/` on the Docker host. Routes come from `traefik_services`; the domain, LAN IPs,
ACME email and basic-auth hash come from SOPS (`site.sops.yaml`, `secrets.sops.yaml`).

Only a change to `traefik.yml` restarts the container; dynamic files are hot-reloaded.
Set `traefik_acme_enabled: false` to run without Let's Encrypt (test environment).

Internal routes use `<subdomain>.home.arpa` (RFC 8375), not `.local` (reserved for mDNS).
AdGuard must rewrite `*.home.arpa` to the Docker host.
