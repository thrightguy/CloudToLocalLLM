#!/bin/bash
# Docker-based CloudToLocalLLM VPS Startup Script
# This script uses Docker to build and run the admin daemon,
# avoiding permission and dependency issues.
#
# Usage: Run as root (su - or sudo -i), then:
#   bash scripts/setup/docker_startup_vps.sh

set -uo pipefail # Removed -e to allow script to continue on curl errors

# Configuration
INSTALL_DIR="/opt/cloudtolocalllm"
LOGFILE="$INSTALL_DIR/startup_docker.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}This script must be run as root. Use 'su -' or 'sudo -i' to become root, then run the script.${NC}" >&2
  exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1

log_status() {
  echo -e "${YELLOW}[STATUS]${NC} $1"
}
log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}
log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

trap 'log_error "Script interrupted."' ERR SIGINT SIGTERM

# MAIN EXECUTION
# ==============================================================================
log_status "==== $(date) Starting CloudToLocalLLM stack using Docker ======"

# Step 0: Clean up previous Docker environment
log_status "[0/5] Cleaning up previous Docker environment..."
log_status "Stopping and removing existing CloudToLocalLLM containers..."
EXISTING_CONTAINERS=$(docker ps -aq --filter "name=cloudtolocalllm")
if [ -n "$EXISTING_CONTAINERS" ]; then
    docker stop $EXISTING_CONTAINERS || true
    docker rm $EXISTING_CONTAINERS || true
fi
docker stop docker-admin-daemon-1 || true
docker rm docker-admin-daemon-1 || true

# Remove unused 'cloudllm-network' if not in use
if docker network ls | grep -q 'cloudllm-network'; then
  if ! docker network inspect cloudllm-network | grep -q '"Containers": {}'; then
    log_status "'cloudllm-network' is still in use, not removing."
  else
    log_status "Removing unused 'cloudllm-network'..."
    docker network rm cloudllm-network || true
  fi
fi

# Do NOT prune volumes or images
# docker system prune -af # Commented out to avoid aggressive pruning

# Step 1: Ensure Docker is installed and running (renumbered)
log_status "[1/5] Checking Docker installation..."
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker is not installed. Aborting.${NC}" >&2
  exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_status "Starting Docker service..."
    systemctl start docker
fi

# Log content of Dockerfile.web for debugging
log_status "Content of $INSTALL_DIR/config/docker/Dockerfile.web:"
cat "$INSTALL_DIR/config/docker/Dockerfile.web" || log_error "Could not display Dockerfile.web"
log_status "-----------------------------------------------------"

# Step 2: Start the admin daemon using Docker Compose (renumbered from 3/4)
log_status "[2/5] Starting admin daemon via Docker Compose..."
cd "$INSTALL_DIR"
# Rebuild webapp container with --no-cache to ensure latest config
log_status "Rebuilding webapp container with --no-cache..."
docker compose -f config/docker/docker-compose.yml build --no-cache webapp

docker compose -p ctl_admin -f config/docker/docker-compose.admin.yml up -d

# Wait for the admin daemon to be ready
log_status "Waiting for admin daemon to be ready..."
ADMIN_READY=false
for i in {1..60}; do
  if curl -s --fail http://localhost:9001/admin/health | grep -q '"status": "OK"'; then
    log_status "Admin daemon is ready."
    ADMIN_READY=true
    break
  fi
  sleep 2
done

if [ "$ADMIN_READY" = false ]; then
  log_error "Admin daemon failed to start or is not healthy."
  log_error "Check admin daemon logs with: docker logs ctl_admin-admin-daemon-1"
  exit 1
fi

# Step 3: Deploy all services through admin daemon API (renumbered from 4/4)
log_status "[3/5] Triggering full stack deployment via daemon API..."
DEPLOY_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:9001/admin/deploy/all || true)
DEPLOY_BODY=$(echo "$DEPLOY_RESPONSE" | head -n -1)
DEPLOY_CODE=$(echo "$DEPLOY_RESPONSE" | tail -n1)

if [[ "$DEPLOY_CODE" != "200" ]]; then
  log_error "Deployment API call failed or services are unhealthy (HTTP status: $DEPLOY_CODE)."
  echo "API Response Body:"
  echo "$DEPLOY_BODY"
  log_error "For more details, check the admin daemon logs: docker logs ctl_admin-admin-daemon-1"
  # Optionally, exit here if preferred: exit 1
else
  log_success "Deployment API call succeeded (HTTP status: $DEPLOY_CODE)."
  echo "API Response Body:"
  echo "$DEPLOY_BODY"
fi

# After deployment, check that all containers are on the 'cloudllm-network'
log_status "Checking that all containers are on the 'cloudllm-network'..."
NETWORK_INSPECT=$(docker network inspect cloudllm-network 2>/dev/null || true)
if [[ "$NETWORK_INSPECT" == *'"Containers": {}'* ]]; then
  log_error "No containers found on 'cloudllm-network'. Please check your Compose configuration."
else
  log_success "Containers are attached to 'cloudllm-network'."
fi

log_status "==== $(date) Docker-based startup complete ===="
if [[ "$DEPLOY_CODE" == "200" ]]; then
  log_success "System is now running in Docker containers (or attempting to)."
else
  log_error "Some services may not be running correctly. Please review the logs above."
fi 