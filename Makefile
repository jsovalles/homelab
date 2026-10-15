SHELL := /bin/bash
.DEFAULT_GOAL := help

# ENV=prod (default) or ENV=test  → selects tofu workspace + ansible inventory
ENV ?= prod

SOPS_FILE   := infrastructure/ansible/inventory/group_vars/all/secrets.sops.yaml
VENV        := $(CURDIR)/.venv/bin
INVENTORY   := inventory/$(ENV).yml
ANSIBLE     := ./scripts/inventory.sh $(ENV) >/dev/null && cd infrastructure/ansible && PATH=$(VENV):$$PATH ansible-playbook -i $(INVENTORY) $(ARGS)
TOFU        := ./scripts/tofu.sh $(ENV)

export SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
# In a VS Code terminal (incl. Remote-SSH) `make secrets` / `make site-config` open the decrypted
# file in a VS Code tab; sops re-encrypts when the tab is closed.
ifeq ($(TERM_PROGRAM),vscode)
export SOPS_EDITOR ?= code --wait
endif

help: ## Show this help (ENV=test → scratch environment, ARGS= for extra ansible args)
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------- Phase 0
bootstrap: ## Phase 0 – install ansible/sops/age/tofu, create age key + secrets file
	./scripts/bootstrap.sh

secrets: ## Edit the encrypted secrets file with $EDITOR
	sops $(SOPS_FILE)

age-add-recipient: ## Add a backup age PUBLIC key (KEY=age1...) and re-encrypt all SOPS files
	./scripts/age-add-recipient.sh "$(KEY)"

site-config: ## Edit site data (domain, IPs, MACs) – infrastructure/ansible/inventory/group_vars/all/site.sops.yaml
	sops infrastructure/ansible/inventory/group_vars/all/site.sops.yaml

# ---------------------------------------------------------------- Phase 1
pve-host: ## Phase 1 – Proxmox host (repos, storage, terraform API token → SOPS)
	$(ANSIBLE) playbooks/01-pve-host.yml

pve-upgrade: ## Phase 1 + apt full-upgrade of the Proxmox host (reboot afterwards if told so)
	$(ANSIBLE) playbooks/01-pve-host.yml -e pve_host_full_upgrade=true

# ---------------------------------------------------------------- Phase 2
tf-init: ## Phase 2 – tofu init (+ create test workspace)
	$(TOFU) init -upgrade

tf-plan: ## Phase 2 – tofu plan (all guests + backup job)
	$(TOFU) plan -out=tfplan.$(ENV) $(TF_ARGS)

tf-apply: ## Phase 2 – tofu apply the saved plan
	$(TOFU) apply tfplan.$(ENV)

tf-test: ## Unit tests of the OpenTofu modules (tofu test, mock provider – no Proxmox needed)
	$(TOFU) init -input=false >/dev/null
	$(TOFU) test

tf-destroy: ## Phase 2 – DANGER: destroy guests of $(ENV) (prod needs CONFIRM=destroy-prod)
	$(TOFU) destroy $(TF_ARGS)

tf-output: ## Show outputs, e.g. ARGS='-json guest_passwords'
	$(TOFU) output $(ARGS)

inventory: ## Render infrastructure/ansible/inventory/$(ENV).yml from the OpenTofu variables
	./scripts/inventory.sh $(ENV)

# ---------------------------------------------------------------- Phase 3/4
haos: ## Phase 3 – wait until Home Assistant answers
	$(ANSIBLE) playbooks/02-haos.yml

lxc-apps: ## Phase 3 – install Gotify + MySpeed inside their LXCs
	$(ANSIBLE) playbooks/03-lxc-apps.yml

docker-host: ## Phase 4 – docker + docker/ stack, .env from SOPS
	$(ANSIBLE) playbooks/04-docker-host.yml

docker-update: ## Phase 4 + pull newer images and recreate updated containers
	$(ANSIBLE) playbooks/04-docker-host.yml -e homelab_stack_compose_pull=always

drift: ## Read-only: what on the Docker VM differs from the repo (changed = drift)
	export ANSIBLE_DISPLAY_OK_HOSTS=false ANSIBLE_DISPLAY_SKIPPED_HOSTS=false; \
	$(ANSIBLE) playbooks/92-drift.yml --check

pull-config: ## Copy wg-easy/AdGuard config from the Docker VM back into the repo (SOPS-encrypted)
	$(ANSIBLE) playbooks/91-pull-config.yml

# ---------------------------------------------------------------- All
site: ## Run every Ansible phase
	$(ANSIBLE) playbooks/site.yml

check: ## Dry-run every Ansible phase (--check --diff)
	$(ANSIBLE) playbooks/site.yml --check --diff

rebuild: pve-host tf-init tf-plan tf-apply site ## Full rebuild from scratch

test: ## Rebuild test of what changed (SCOPE=auto|all|docker|haos|lxc|myspeed|gotify|host, KEEP=1)
	SCOPE="$(SCOPE)" KEEP="$(KEEP)" ./scripts/test-rebuild.sh

test-full: ## Full rebuild test of everything (big changes, before a PR)
	SCOPE=all KEEP="$(KEEP)" ./scripts/test-rebuild.sh

ansible-run: # internal: run one playbook, e.g. PLAYBOOK=playbooks/04-docker-host.yml
	$(ANSIBLE) $(PLAYBOOK)

lint: ## pre-commit hooks on all files + tofu validate (same as CI)
	PATH=$(VENV):$$PATH pre-commit run --files $$(git ls-files --cached --others --exclude-standard)
	cd infrastructure/terraform && TF_VAR_state_passphrase=lint-only-passphrase-000 tofu validate

lock: ## Regenerate infrastructure/ansible/requirements.lock (with hashes) after changing requirements.txt
	tmp="$$(mktemp -d)" && trap 'rm -rf "$$tmp"' EXIT && python3 -m venv "$$tmp" \
	  && "$$tmp/bin/pip" install -q pip-tools \
	  && cd infrastructure/ansible && "$$tmp/bin/pip-compile" --quiet --generate-hashes --allow-unsafe \
	     --strip-extras --no-emit-index-url -o requirements.lock requirements.txt

hooks: ## Install the git pre-commit hook + decrypted diffs for SOPS files
	PATH=$(VENV):$$PATH pre-commit install
	git config diff.sopsdiffer.textconv "sops -d"

.PHONY: help bootstrap secrets age-add-recipient site-config pve-host pve-upgrade docker-update tf-init tf-plan tf-apply tf-test tf-destroy tf-output inventory haos lxc-apps docker-host drift pull-config site check rebuild test test-full ansible-run lint lock hooks
