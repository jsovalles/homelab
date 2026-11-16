# Alerts → Gotify

Gotify (LXC) receives the alerts; one Gotify application (token) per sender. The `gotify` role
creates the applications (`gotify_applications` in `inventory/group_vars/lxc_apps.yml`); the
senders' notification settings live in their own databases and are set once in their UIs.

Gotify URL for the senders: `http://<gotify LAN IP>` (`guest_ips.gotify`, `make tf-output`).
From the Docker VM's containers neither `gotify.home.arpa` (not resolved there) nor the https
domain (Beszel's network is not in Traefik's allowlist) works.

Tokens: Gotify UI → **Apps** → the app's token (eye icon).

## Uptime Kuma (service down / back up)

1. Settings → Notifications → **Setup Notification**
2. Type **Gotify**, name `Gotify`
3. Application token: the `uptime-kuma` token; Server URL: `http://<gotify LAN IP>`; priority 8
4. Tick **Default enabled** and **Apply on all existing monitors** → Test → Save

## Beszel (host and container alerts)

1. Settings → Notifications → **Add URL**:
   `gotify://<gotify LAN IP>/<beszel token>?disabletls=yes`
2. Test URL → Save
3. Per system (bell icon): turn on the alerts, e.g. Status (down), CPU > 80 % for 10 min,
   Memory > 90 %, Disk > 85 %
