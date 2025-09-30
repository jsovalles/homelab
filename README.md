
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
    - [Pihole](#pihole)
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

- **nginx-proxy-manager**: A web-based interface for managing Nginx proxy hosts, SSL certificates, and redirection.
- **wg-easy**:A simple WireGuard VPN server with a web UI for easy management.
- **pihole**: Network-wide ad blocker and DNS server, useful for blocking ads and tracking domains.
- **unbound**:A validating, recursive, caching DNS resolver, often used with Pi-hole for secure DNS queries.
- **watchtower**:Automatically updates running Docker containers when new images are available.
- **duckdns**: Dynamic DNS service to keep your domain updated with your current IP address.
- **beszel**: A lightweight, self-hosted message hub for secure communication between agents.
- **beszel-agent**: Agent for Beszel, connects to the hub and enables automation or remote control.
- **dozzle**: A real-time log viewer for Docker containers, accessible via a web interface.

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
docker run --rm ghcr.io/steveiliop56/tinyauth:v3 user create --username 'user@example.com' --password 'S3cretP@ss' --docker
```

**Docker Compose Example:**
```yaml
tinyauth:
  image: ghcr.io/steveiliop56/tinyauth:v3
  container_name: tinyauth
  restart: unless-stopped
  environment:
    - SECRET=secret-var
    - APP_URL=https://tinyauth.your.domain
    - USERS=
  networks:
    dns:
      ipv4_address: 172.30.0.11
```

---

### Pihole

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

- If containers fail to start, check your `.env` file for missing or incorrect values.
- For permission errors, ensure your user is in the `docker` group.
- Review logs with `docker-compose logs <service>` for more details.

---

## Resources

- [Proxmox Documentation](https://www.proxmox.com/proxmox-ve)
- [Docker Documentation](https://docs.docker.com/)
- [TinyAuth GitHub](https://github.com/steveiliop56/tinyauth)