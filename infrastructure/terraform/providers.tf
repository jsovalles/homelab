terraform {
  required_version = "~> 1.12.0" # ephemeral resources need >= 1.11

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.115.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
  }

  # OpenTofu native state encryption – the state file is safe to commit to git.
  # Passphrase comes from SOPS via the Makefile (TF_VAR_state_passphrase).
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method   = method.aes_gcm.main
      enforced = true
    }
    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}

# Ephemeral: decrypted secrets are used by the provider but never written to state or plans
ephemeral "sops_file" "secrets" {
  source_file = "${path.module}/../ansible/inventory/group_vars/all/secrets.sops.yaml"
}

locals {
  secrets         = yamldecode(ephemeral.sops_file.secrets.raw)
  ssh_private_key = try(file(pathexpand(var.ssh_private_key_file)), null)
}

provider "proxmox" {
  endpoint  = "https://${var.node_addresses[var.api_node]}:8006/"
  api_token = "${local.secrets.pve_api_token_id}=${local.secrets.pve_api_token_secret}"
  insecure  = true

  # SSH is required for snippets and disk imports, on every node
  ssh {
    # Use the private key file if present, otherwise the ssh-agent
    private_key = local.ssh_private_key
    agent       = local.ssh_private_key == null
    username    = "root"

    dynamic "node" {
      for_each = var.node_addresses
      content {
        name    = node.key
        address = node.value
      }
    }
  }
}
