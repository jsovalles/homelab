# preflight

Fails fast when secrets are not decrypted or still placeholders.

| Variable | Type | Description |
|---|---|---|
| `preflight_required_secrets` | list | Secret variable names that must be real |
| `preflight_placeholder_regex` | str | Regex identifying placeholder values |
| `preflight_check_env_secrets` | bool | Also check homelab_secrets for placeholders |
| `preflight_allow_placeholder_secrets` | bool | Only warn-free skip for test environments |

Defaults: `defaults/main.yml`.
