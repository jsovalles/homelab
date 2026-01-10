# Homelab

This repository contains Docker Compose configurations and supporting files for deploying services on an Ubuntu VM managed by Proxmox. It is designed to help you quickly set up and manage your homelab environment, including authentication, DNS, SSL, and more.

## Table of Contents

- [Homelab](#homelab)
  - [Table of Contents](#table-of-contents)
  - [Project Overview](#project-overview)
  - [Environment Variables](#environment-variables)
  - [Setup Guide](#setup-guide)
  - [Services](#services)
    - [Beszel Agent](#beszel-agent)
    - [Installation](#installation)
    - [Uninstall](#uninstall)
    - [TinyAuth](#tinyauth)
    - [AdGuard Home](#adguard-home)
    - [Pihole (Legacy)](#pihole-legacy)
  - [Config Backup](#config-backup)
    - [Backup Configuration](#backup-configuration)
    - [Restore Configuration](#restore-configuration)
  - [Troubleshooting](#troubleshooting)
  - [Resources](#resources)

## Project Overview

This project provides:
- Docker Compose files for service orchestration
- Example configurations for DNS, SSL, and authentication
- Guides for deploying agents and authentication services

**Prerequisites:**
- Ubuntu VM (recommended on Proxmox)
- Docker & Docker Compose installed

---

## Environment Variables

Create a `.env` file in the root directory to define required environment variables. Use `.env.example` as a template.

---

## Setup Guide

1. Run the following commands:
    ```bash
    apt-get update && apt-get -y upgrade
    apt-get install -y qemu-guest-agent
    ```
2. Clone this repository:
    ```bash
    git clone https://github.com/jsovalles/homelab.git
    cd homelab
    ```
3. Copy `.env.example` to `.env` and update values.
4. Start services:
    ```bash
    docker-compose up -d
    ```
---


## Services

Below is a summary of the main tools and services included in this homelab setup:

- **traefik**: Modern reverse proxy and load balancer with automatic SSL certificate management via Let's Encrypt. Supports dynamic configuration and integrates with Docker labels.
- **wg-easy**: A simple WireGuard VPN server with a web UI for easy management.
- **adguardhome**: Network-wide ad blocker and DNS server with advanced features like DNS-over-HTTPS/TLS support.
- **unbound**: A validating, recursive, caching DNS resolver, used as upstream for AdGuard Home for secure DNS queries.
- **watchtower**: Automatically updates running Docker containers when new images are available.
- **duckdns**: Dynamic DNS service to keep your domain updated with your current IP address.
- **beszel**: A lightweight, self-hosted message hub for secure communication between agents.
- **beszel-agent**: Agent for Beszel, connects to the hub and enables automation or remote control.
- **dozzle**: A real-time log viewer for Docker containers, accessible via a web interface.
- **homepage**: A highly customizable application dashboard with service integrations, status monitoring, and Docker container management.
- **tinyauth**: A simple forward authentication service that integrates with Traefik to protect services with OAuth2 (Google) authentication.

---

### Beszel Agent

The Beszel Agent is used for secure communication and automation between your VM and external services.

### Installation

```bash
mkdir -p /opt/beszel-agent
cd /opt/beszel-agent/
nano install.sh # Paste the Beszel binary script
chmod 775 install.sh
./install.sh
```

### Uninstall
```bash
curl -sL https://get.beszel.dev -o /tmp/install-agent.sh && chmod +x /tmp/install-agent.sh && /tmp/install-agent.sh -u
```
---

### TinyAuth

TinyAuth provides simple authentication for your services. It can be run as a Docker container and supports user management via CLI.

**Creating a User:**
```bash
docker run --rm ghcr.io/steveiliop56/tinyauth:latest user create --username 'user@example.com' --password 'S3cretP@ss' --docker
```

**Traefik Integration:**

To protect services with TinyAuth, configure the ForwardAuth middleware in your Traefik dynamic configuration:

```yaml
http:
  middlewares:
    tinyauth:
      forwardAuth:
        address: "http://172.30.0.8:8802/api/auth/traefik"
```

---

### AdGuard Home

AdGuard Home is a network-wide ad blocker and DNS server with advanced features including:
- DNS-over-HTTPS (DoH) and DNS-over-TLS (DoT) support
- Custom DNS rewrites and filtering rules
- Comprehensive blocklists (Firebog integration)
- Integration with Unbound for recursive DNS resolution
- DNSSEC validation

**Configuration:**

The AdGuard Home configuration is stored in `config/adguardhome/AdGuardHome.yaml`. A template is provided in `config/adguardhome/AdGuardHome.yaml.example`.

**Key Features:**
- **Upstream DNS**: Uses Unbound (172.30.0.2) as primary with Quad9 DoH/DoT as fallback
- **Wildcard DNS**: Configure custom DNS rewrites for local domains
- **Blocklists**: Pre-configured with 29 Firebog recommended lists
- **Web Interface**: Exposed via Traefik with SSL (or via Nginx Proxy Manager if enabled)
---

### Pihole (Legacy)

> **Note:** This setup now uses AdGuard Home instead of Pi-hole. The following is kept for reference.

Pihole is used for DNS-based ad blocking and local DNS resolution. To enable wildcard DNS for local domains with NPM:

1. Create `config/dnsmasq/99-wildcard.conf`
2. Add your desired DNS records, for example:
   ```conf
   address=/your.domain/your.local.ip
   address=/.lan/your.local.ip
   ```

---


## Config Backup

You can securely backup and restore your configuration files using the provided Makefile commands. This is useful for migration or disaster recovery.

### Backup Configuration

This command compresses the `config` directory into a password-protected zip file (`config.zip`).

```bash
make backup_config
```
You will be prompted to enter a password for the zip file. The backup requires `sudo` privileges.

### Restore Configuration

This command extracts the contents of `config.zip` back into the `config` directory.

```bash
make uncompress_config
```
You will be prompted to enter the password used during backup.

**Security Note:**
- Passwords are handled interactively and not stored in plaintext.
- The zip password is only as strong as you choose; use a strong, unique password.
- The backup file (`config.zip`) contains sensitive configuration—store it securely.

---


## Troubleshooting

**General Issues:**
- If containers fail to start, check your `.env` file for missing or incorrect values.
- For permission errors, ensure your user is in the `docker` group.
- Review logs with `docker compose logs <service>` for more details.
---

## Resources

- [Proxmox Documentation](https://www.proxmox.com/proxmox-ve)
- [Docker Documentation](https://docs.docker.com/)
- [TinyAuth GitHub](https://github.com/steveiliop56/tinyauth)
- [AdGuard Home Documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Unbound Documentation](https://nlnetlabs.nl/documentation/unbound/)
- [Firebog Blocklists](https://firebog.net/)
