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

# Step 1: Ensure Docker is installed and running
log_status "[1/4] Checking Docker installation..."
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker is not installed. Aborting.${NC}" >&2
  exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_status "Starting Docker service..."
    systemctl start docker
fi

# Step 3: Start the admin daemon using Docker Compose
log_status "[3/4] Starting admin daemon via Docker Compose..."
cd "$INSTALL_DIR"
docker compose -f config/docker/docker-compose.admin.yml up -d --build

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
  log_error "Check admin daemon logs with: docker logs docker-admin-daemon-1"
  exit 1
fi

# Step 4: Deploy all services through admin daemon API
log_status "[4/4] Triggering full stack deployment via daemon API..."
DEPLOY_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:9001/admin/deploy/all || true)
DEPLOY_BODY=$(echo "$DEPLOY_RESPONSE" | head -n -1)
DEPLOY_CODE=$(echo "$DEPLOY_RESPONSE" | tail -n1)

if [[ "$DEPLOY_CODE" != "200" ]]; then
  log_error "Deployment API call failed or services are unhealthy (HTTP status: $DEPLOY_CODE)."
  echo "API Response Body:"
  echo "$DEPLOY_BODY"
  log_error "For more details, check the admin daemon logs: docker logs docker-admin-daemon-1"
  # Optionally, exit here if preferred: exit 1
else
  log_success "Deployment API call succeeded (HTTP status: $DEPLOY_CODE)."
  echo "API Response Body:"
  echo "$DEPLOY_BODY"
fi

log_status "==== $(date) Docker-based startup complete ===="
if [[ "$DEPLOY_CODE" == "200" ]]; then
  log_success "System is now running in Docker containers (or attempting to)."
else
  log_error "Some services may not be running correctly. Please review the logs above."
fi 