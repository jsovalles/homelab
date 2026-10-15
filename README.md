# pve-01 – Proxmox homelab as code

Rebuild the `pve-01` Proxmox VE host and all of its guests from this repository.

| Tool | Role |
|------|------|
| **OpenTofu** (`bpg/proxmox`) | Creates every guest (HAOS VM, Docker VM, LXCs), static IPs, backup job |
| **Ansible** | Host baseline, apps inside the guests, health checks |
| **SOPS + age** | All secrets (API token, passwords, `.env` secrets), encrypted in git |
| **OpenTofu state encryption** | `terraform.tfstate` is AES-GCM encrypted → safe to commit |
| **`make test`** | Tests only what you changed (scratch copy, VMIDs 91xx): deploys twice, asserts `changed=0`, destroys it. `make test-full` tests everything |
| **GitHub Actions** | `ansible-lint` (production profile), `tofu validate`, secrets-are-encrypted check |

## Inventory

| ID | Type | Name | IP (`<lan>` = site prefix, see `docs/network.md`) | Created by | Configured / verified by |
|----|------|------|----|---|---|
| 100 | VM  | docker  | <lan>.2 (static, cloud-init) – Debian 13 | OpenTofu `modules/cloud_vm` | Ansible `docker` + `traefik` + `homelab_stack` |
| 101 | VM  | haos    | <lan>.100 (DHCP reservation by MAC) | OpenTofu `modules/appliance_vm` | Ansible `haos_check` (web UI answers) |
| 102 | LXC | myspeed | <lan>.79 (static) – Debian 13 | OpenTofu `modules/lxc` | Ansible `myspeed` (via `pct exec`) |
| 103 | LXC | gotify  | <lan>.196 (static) – Debian 13 | OpenTofu `modules/lxc` | Ansible `gotify` (via `pct exec`) |

Guests use `<lan>.1` + `1.1.1.1` as DNS – never the AdGuard instance they host.
A daily vzdump job (`homelab-daily`, keep 7) is managed in `infrastructure/terraform/backup.tf`.

## Layout

```
.
├── Makefile                       # entry point – `make help`
├── .sops.yaml                     # SOPS creation rules (age recipient)
├── docs/
│   ├── roadmap.md                 # single node → Proxmox cluster → Talos/Kubernetes
│   ├── adr/                       # architecture decision records (why things are the way they are)
│   └── network.md                 # IP plan (nodes, guests, k8s VIP, LB pool, test range)
├── scripts/
│   ├── bootstrap.sh               # Phase 0 (checksum-verified sops/tofu, locked Python deps)
│   ├── tofu.sh                    # tofu wrapper: SOPS passphrase, workspace, prod-destroy guard
│   ├── inventory.sh               # renders the Ansible inventory from terraform.tfvars
│   ├── check-sops-encrypted.sh    # pre-commit/CI guard
│   └── test-rebuild.sh            # make test
├── docker/                        # Docker Compose stack – deployed to the Docker VM
└── infrastructure/
    ├── terraform/
    │   ├── terraform.tfvars       # nodes, images (pinned + checksums), guests – edit this
    │   ├── envs/test.tfvars       # scratch guests for `make test` (workspace "test")
    │   ├── images.tf · guests.tf · backup.tf · imports.tf · providers.tf
    │   ├── inventory.tf · validation.tf
    │   └── modules/               # cloud_vm · appliance_vm · lxc (reused by Talos later)
    └── ansible/
        ├── inventory/
        │   ├── prod.yml / test.yml                # GENERATED (gitignored) – `make inventory`
        │   ├── group_vars/<group>.yml             # per-group connection settings
        │   ├── secrets.example.yaml               # plaintext template
        │   ├── group_vars/all/secrets.sops.yaml   # ENCRYPTED
        │   └── group_vars/docker_hosts/main.yml   # non-secret .env values
        ├── playbooks/  01-pve-host · 02-haos · 03-lxc-apps · 04-docker-host · 91-pull-config · 92-drift · site
        ├── roles/      preflight · pve_host · haos_check · gotify · myspeed · docker · traefik · homelab_stack
        │               ssh_access · auto_updates · console_access
        └── files/      SOPS-encrypted app-owned config (wireguard/wg-easy.db.sops.json, adguardhome/AdGuardHome.sops.yaml)
```

### Adding a node or a guest

- **Node**: install Proxmox (ZFS!), add it to `nodes` in `terraform.tfvars` (the inventory picks it up),
  then run `make pve-host`. Cluster formation is Stage B
  in `docs/roadmap.md`.
- **Guest**: add an entry to `cloud_vms`, `appliance_vms` or `lxcs` with `node = "..."` and
  `ansible = { groups = [...], vars = {...} }`; `make tf-plan tf-apply`. The Ansible inventory is
  generated from the same entry ([ADR 0004](docs/adr/0004-inventory-generated-from-tfvars.md)).

## Phases

Every target accepts `ENV=test` (scratch environment) and `ARGS="..."` (extra ansible args, e.g. `--tags gotify`).

### Phase 0 – tooling & secrets
```bash
make bootstrap      # age, sops, ansible (venv), tofu; age key; secrets file with random passwords
make secrets        # fill in homelab_env_secrets (sops opens $EDITOR)
```
**Back up `~/.config/sops/age/keys.txt`** (password manager / offline). Without it nothing
in this repo can be decrypted.

**Backup key (recommended):** a second age key kept offline can decrypt everything as well:
```bash
age-keygen -o homelab-backup-age.txt      # on your PC; store it in your password manager, then delete the file
make age-add-recipient KEY=age1...        # its public key (printed by age-keygen); commit the result
```

### Phase 1 – Proxmox host
```bash
make pve-host
```
No-subscription repos, base packages, `snippets`/`import` content on `local`, and the
`terraform@pve!homelab` API token – **written straight into the SOPS file**, never printed.

### Phase 2 – OpenTofu (all guests)
```bash
make tf-init
make tf-plan
make tf-apply
```
On the *current* host the guests already exist. Set `adopt_existing_guests = true` in
`terraform.tfvars` (imports run only in the production workspace) and review `make tf-plan`:
it must say **0 to destroy**. Adopted guests keep today's hardware through per-guest `hardware`
/ `keyctl` overrides; new guests default to q35 + `x86-64-v2-AES` (portable across Intel/AMD,
live-migration friendly).

### Phase 3 – HAOS & LXC apps
```bash
make haos           # waits until Home Assistant answers; restore an HA backup afterwards
make lxc-apps       # installs/updates Gotify + MySpeed, then health-checks them
```

### Phase 4 – Docker host (`docker/`)
```bash
make docker-host
```
1. Installs Docker CE + compose plugin, frees port 53 from systemd-resolved.
2. Syncs `docker/` to `/root/homelab` (rsync, no delete – `.env` and runtime `config/*` on the VM are kept)
   and creates the `config/` directories the stack mounts (`homelab_config_dirs`).
3. Renders `.env` (0600) from `homelab_env` **merged with** `homelab_env_secrets` (SOPS).
4. Renders the Traefik config from templates and, on a fresh VM, writes the app-owned files
   (WireGuard peers, AdGuard) from their SOPS copies.
5. `docker compose up --wait` – fails if any container doesn't become running/healthy.

`make docker-update` does the same and also pulls newer images (`make docker-host` never pulls).

#### The `.env` lives in this repo, not on the VM

`/root/homelab/.env` on the VM is **generated** on every `make docker-host`; never edit it there.

| Kind of value | Where | How to edit |
|---|---|---|
| Non-secret (`TZ`, ports, URLs…) | `homelab_env` in `infrastructure/ansible/inventory/group_vars/docker_hosts/main.yml` | normal editor, reviewed in PRs |
| Secret (tokens, hashes, client secrets…) | `homelab_env_secrets` in `group_vars/all/secrets.sops.yaml` | `make secrets` (sops decrypts in your editor, re-encrypts on save) |

Then `make docker-host` renders the merged `.env` (mode 0600) and recreates only the containers
whose config changed. Write values exactly as in a `.env` (keep `$$` escaping, quotes).

Containers do **not** load the whole `.env`: compose only uses it to fill `${VAR}`, and each
service lists the variables it receives under `environment:` in `docker/docker-compose.yml`
(`${VAR:?}` = required, compose refuses to start without it). A new variable therefore needs two
changes: the value here, and the `environment:` entry of the service that uses it.

Adding a new variable: put it in one of the two places above (secret keys also get a
placeholder in `infrastructure/ansible/inventory/secrets.example.yaml`).

#### App-owned config (wg-easy peers, AdGuard)

Some files are changed by the apps themselves (adding a peer in wg-easy). They are stored
SOPS-encrypted in `infrastructure/ansible/files/` (`wireguard/wg-easy.db.sops.json`,
`adguardhome/AdGuardHome.sops.yaml`) and are
**written to the VM only when missing** – a running VM is never overwritten.

| You changed… | Do |
|---|---|
| Peers in the wg-easy UI / settings in AdGuard | `make pull-config` → commit the `.sops.*` file (only rewritten when content changed) |
| Not sure what differs | `make drift` – read-only report: repo-owned files a deploy would change, app-owned files not pulled yet |
| Traefik routes / middlewares | edit `group_vars/docker_hosts/traefik.yml` (+ `make site-config`/`make secrets`) → `make docker-host` – the repo always wins; edits made on the VM are overwritten |

What is **not** in git: Traefik's `acme.json` (re-issued automatically) and app data in Docker
volumes (Uptime Kuma, tinyauth, Beszel) – those are covered by the vzdump job.

## Safety nets

| Command | What it does |
|---|---|
| `make lint` | pre-commit hooks (whitespace, private keys, gitleaks, YAML, shellcheck, SOPS-encrypted, tofu fmt, ansible-lint) + `tofu validate` – same as CI. `make hooks` installs them as a git hook |
| `make check` | `--check --diff` dry run of every playbook |
| `make drift` | Read-only: what on the Docker VM differs from the repo (every `changed` is drift) |
| `make test` | Rebuilds **only the parts affected by your uncommitted changes** (picked from `git diff`: e.g. a compose change → docker VM only, a gotify role change → gotify only, docs only → nothing; unknown/shared files → everything). Force a part with `SCOPE=docker\|haos\|lxc\|myspeed\|gotify\|host`. |
| `make test-full` | Full rebuild of everything – use for big changes and before a PR. Runs in the `test` workspace (VMIDs 9100-9105, IPs .240-.242), second run must be `changed=0`, then destroy. `KEEP=1` keeps it. Production guests and images are never touched (test images are `test-` prefixed). |

**No site data in git:** LAN IPs, MACs and the domain live only in `site.sops.yaml`
(`make site-config`, partially encrypted so the structure stays reviewable). Terraform gets them
as sensitive `TF_VAR_*` (hidden in plans), Ansible through the generated inventory and the rendered `.env`. The `no-site-data` hook blocks private IPs, MACs and `*.duckdns.org`
everywhere, and the exact site values when the age key is present.

Production guests have the Proxmox **protection** flag, and `make tf-destroy` refuses to run
against prod unless `CONFIRM=destroy-prod` is set. Terraform `validation.tf` rejects duplicate
VMIDs/IPs and unknown nodes/images at plan time. Renovate (`renovate.json5`) proposes version
bumps; every bump goes through CI and `make test`.

Preflight checks stop any playbook early when the secrets file can't be decrypted or still
contains placeholders.

## Updates and console access

| | Docker VM | LXCs (MySpeed, Gotify) | HAOS / Proxmox host |
|---|---|---|---|
| **Automatic updates** | `unattended-upgrades`: Debian security + stable updates, daily 04:00 (± 30 min, `America/Bogota`); Docker/NodeSource repos excluded | same | HAOS updates itself; the Proxmox host is updated by you (no unattended upgrades on the hypervisor) |
| **Reboot after kernel updates** | not automatic (`auto_updates_reboot`) – check `/run/reboot-required` | never needed | – |
| **Proxmox UI console** | login prompt: `ansible` + per-guest password (`make tf-output ARGS='-json guest_passwords'`), `sudo -i` for root | login prompt: `root` + per-guest password | normal |

Logs: `/var/log/unattended-upgrades/`. A run missed while a guest was off is caught up after boot.
If `make tf-apply` fails with a download error or `EOF` from the Proxmox API (mirrors and the API proxy
occasionally drop long requests), run `make tf-plan tf-apply` again – finished resources are kept.
Changing an LXC's console mode with OpenTofu restarts the container. Console auto-login exists
(`console_autologin`, `console_mode`) but is off on purpose: it would turn console-only access
(`VM.Console`, e.g. a leaked API token) into a shell.

## Credentials

| What | Where |
|---|---|
| Guest root/console passwords (unique per guest) | `make tf-output ARGS='-json guest_passwords'` |
| SSH to VMs | user `ansible` (passwordless sudo, keys only) with `~/.ssh/id_ed25519` |
| LXCs | `pct enter <vmid>` on the node, or via Ansible (`pct exec`) |
| Everything else (API token, `.env` secrets, backup password) | `make secrets` |

## Contributing

Branch → `make lint` → `make test` → PR → merge: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Full disaster recovery

Step-by-step for a new or reinstalled node (incl. what to save first): **[docs/new-node.md](docs/new-node.md)**.

```bash
# fresh Proxmox install with the same IP (<lan>.4) and hostname pve-01
apt install -y git make && git clone https://github.com/<you>/<this-repo> /root/homelab && cd /root/homelab
# restore ~/.config/sops/age/keys.txt and ~/.ssh/id_ed25519 from your backup
make bootstrap
make pve-host              # creates a new API token and stores it in SOPS
make rebuild
```
App data (Home Assistant, Gotify DB, MySpeed DB) is **state**, not config – restore it from
the vzdump backups / HA backups. Note the backup job writes to `local` (same disk): copy
backups off-host or add a Proxmox Backup Server storage for real DR.

## Notes
- `.env` values are written verbatim: escape `$` as `$$` (bcrypt hashes) as in the upstream `.env`.
- Upgrading HAOS / Ubuntu / Debian images: add a new entry (url + checksum) in `terraform.tfvars` and point the guest at it.
  Existing guests are not recreated (`ignore_changes`); HAOS updates itself.
