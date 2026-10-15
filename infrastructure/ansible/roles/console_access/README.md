# console_access

Auto-login on the Proxmox VM console (noVNC tty1 + xterm.js ttyS0). Containers keep the `tty` console
(login prompt); see `console_mode` in the OpenTofu `lxc` module.

| Variable | Type | Description |
|---|---|---|
| `console_access_autologin` | bool | Enable auto-login (false removes the drop-ins) |
| `console_access_autologin_user` | str | Account logged in on the console |

Defaults: `defaults/main.yml`.
