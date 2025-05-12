# CloudToLocalLLM VPS Setup & Management

This directory contains scripts for setting up, deploying, and maintaining the CloudToLocalLLM application on a VPS or server. The workflow is now unified and Docker-centric, with a single entry point for most operations.

---

## 🚀 Main Script: `main_vps.sh`

**Usage:**
```bash
cd scripts/setup
bash main_vps.sh [option]
```

**Options:**
- `deploy`      — Build and deploy the Docker stack (with prompt for full flush)
- `ssl-dns`     — Run DNS-based SSL certbot (interactive, wildcard, for advanced users)
- `ssl-webroot` — Run webroot-based SSL certbot (automated, for Nginx)
- `monitor`     — Setup Netdata monitoring
- `fix-docker`  — Run Docker/Flutter build fixes
- `clean`       — Aggressively prune Docker system (all unused containers, images, volumes, build cache)
- `help`        — Show help/usage

**Example:**
```bash
bash main_vps.sh deploy
```

---

## 🗂️ Remaining Scripts
- `docker_startup_vps.sh` — Handles Docker stack build/start/flush (called by main_vps.sh)
- `fix_docker_build.sh`   — Utility for fixing Docker/Flutter build issues
- `setup_cloud.sh`, `setup_ollama.sh`, `setup_monitoring.sh` — Entrypoint/setup scripts for containers/monitoring
- `../ssl/obtain_initial_certs.sh` — DNS/manual SSL certbot (for wildcard certs)
- `../ssl/manage_ssl.sh`           — Webroot/automated SSL certbot (for Nginx)

---

## 🛠️ For Maintainers & AI Assistants

- **Script Trails:**
  - All main operations are routed through `main_vps.sh` for easy automation and future extension.
  - If you add new scripts, document them here and consider integrating them as options in `main_vps.sh`.
  - For future automation, use the comments in `main_vps.sh` as anchor points for code search and script discovery.

- **AI/Automation Notes:**
  - If you are an AI assistant or maintainer, leave breadcrumbs in this section for future maintainers or AI agents.
  - Example: If you add a new monitoring tool, add a section here and a new option in `main_vps.sh`.
  - If you automate documentation or script discovery, use this README as your index.

---

## 📝 Changelog
- **2025-05:** Unified all VPS/Docker/SSL/monitoring scripts under `main_vps.sh`. Removed legacy admin daemon and redundant scripts. This README and script system are now the canonical entry point for server management.

---

## 🔒 SSL/HTTPS Certificates (Let's Encrypt)

- SSL is automatically managed for:
  - `cloudtolocalllm.online` (production)
  - `beta.cloudtolocalllm.online` (dev/beta)
- Uses Certbot with webroot (HTTP-01) via Docker for fully automated certificate issuance and renewal.
- **No manual DNS or TXT records required.**
- To add more subdomains in the future:
  1. Add the subdomain to your DNS (A/AAAA record pointing to your server).
  2. Edit the `DOMAINS` variable in `scripts/ssl/manage_ssl.sh` to include `-d newsub.cloudtolocalllm.online`.
  3. Re-run the SSL script.
- **Rule:** Avoid using subdomains unless necessary for infrastructure separation (e.g., `beta`). Prefer using paths for user or feature separation.

---

**For more details, see the main project README.** 