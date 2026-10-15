# ssh_access

Authorises `ssh_authorized_keys` (controller key + `ssh_admin_public_keys`) for the login user.
Keys are only added, never removed – delete a revoked key from the host by hand as well.

| Variable | Type | Description |
|---|---|---|
| `ssh_access_user` | str | Account that receives the keys |
| `ssh_access_keys` | list | Public keys to authorise |

Defaults: `defaults/main.yml`.
