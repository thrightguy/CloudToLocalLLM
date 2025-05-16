#!/bin/bash

# CloudToLocalLLM Service Troubleshooting Commands
# Run these commands on the VPS to diagnose issues with the service.

# 1. Check the overall status of the cloudtolocalllm systemd service
echo "--- Checking cloudtolocalllm.service status --- "
systemctl status cloudtolocalllm.service
echo

# 2. View detailed journal logs for the service (shows errors during start/run)
echo "--- Journal logs for cloudtolocalllm.service (last 100 lines) --- "
journalctl -n 100 -xeu cloudtolocalllm.service
echo

# 3. Check if Docker and Docker Compose are installed and their versions
echo "--- Docker and Docker Compose versions --- "
docker --version
docker-compose --version
echo

# 4. Check if the Docker daemon/service is running
echo "--- Docker service status --- "
systemctl status docker
echo

# 5. Verify that the Docker Compose files exist in the expected location
echo "--- Checking for Docker Compose files --- "
ls -la /opt/cloudtolocalllm/portal/docker-compose.auth.yml
ls -la /opt/cloudtolocalllm/portal/docker-compose.web.yml
echo

# 6. Change to the service's working directory and validate the Docker Compose configuration
# This helps catch syntax errors or issues with environment variables in the compose files.
echo "--- Validating Docker Compose configuration (from /opt/cloudtolocalllm/portal) --- "
if [ -d "/opt/cloudtolocalllm/portal" ]; then
    cd /opt/cloudtolocalllm/portal && \
    echo "Current directory: $(pwd)" && \
    docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml config
else
    echo "Directory /opt/cloudtolocalllm/portal not found."
fi
echo

echo "--- Troubleshooting script finished --- " 