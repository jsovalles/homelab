# ssh_access

Authorises `ssh_authorized_keys` (controller key + `ssh_admin_public_keys`) for the login user.
Keys are only added, never removed – delete a revoked key from the host by hand as well.
