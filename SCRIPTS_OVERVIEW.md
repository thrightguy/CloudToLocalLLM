# CloudToLocalLLM Scripts Overview

This document provides a categorized overview of all major scripts in the repository, clarifying their purpose and recommended usage.

---

## Main Deployment Workflow

These scripts are for the standard, recommended deployment process:

- **scripts/setup/docker_startup_vps.sh**
  - Main entry point for deploying or updating the application on the VPS.
  - Handles Docker Compose, SSL, permissions, and service startup.
  - Use this for regular updates and deployments.

## Maintenance & Advanced Scripts

These scripts are for advanced use, troubleshooting, or special maintenance tasks. Use only if you know what you are doing:

- **scripts/deploy_update.sh**
  - For advanced/legacy update workflows. May use manual copying or container exec steps.
  - Not needed for standard deployments using volume mounts.

- **scripts/vps_setup.sh**
  - For initial VPS setup, user creation, and system hardening.
  - Not needed for regular deployments.

- **scripts/build_webapp_verbose.sh**
  - Verbose build and troubleshooting for the webapp container.
  - Use for debugging build issues.

- **scripts/deploy.sh**
  - (Legacy) SSH/rsync-based deployment. Not recommended for the current Docker/volume-mount workflow.

## Utility & Helper Scripts

- **scripts/certbot_permissions_hook.sh**
  - Ensures SSL certificate permissions are correct after renewal.

- **scripts/setup_cloudllm_user.sh**
  - Creates and configures the cloudllm user on the VPS.

- **scripts/maintenance/**
  - Miscellaneous scripts for fixing permissions, cleaning up, etc.

- **scripts/deploy_vps.sh**
  - Advanced/legacy VPS deployment script. Use only if you understand its workflow.

---

## Best Practices

- **For regular deployment and updates, always use `scripts/setup/docker_startup_vps.sh`.**
- Use maintenance scripts only for troubleshooting or special cases.
- See the main `README.md` for project overview and the `docs/` directory for full deployment and architecture documentation. 