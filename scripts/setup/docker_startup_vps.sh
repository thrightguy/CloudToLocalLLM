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
# Corrected admin daemon container name
docker stop ctl_admin-admin-daemon-1 || true
docker rm ctl_admin-admin-daemon-1 || true

# Remove the PostgreSQL data volume to ensure a fresh start
log_status "Removing PostgreSQL data volume ctl_services_db_data..."
docker volume rm ctl_services_db_data || true

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

# Define paths for admin daemon source and hash file
ADMIN_DAEMON_SRC_DIR="$INSTALL_DIR/admin_control_daemon"
ADMIN_DAEMON_HASH_FILE="$INSTALL_DIR/.admin_daemon_hash"
SHOULD_REBUILD_ADMIN_DAEMON=false

# Function to calculate hash of the admin daemon source directory
calculate_admin_daemon_hash() {
  if [ -d "$ADMIN_DAEMON_SRC_DIR" ]; then
    # Create a hash of all files and their names, then hash that list
    # This is robust to file additions, deletions, and modifications.
    # Exclude .git directory if it exists within admin_control_daemon
    find "$ADMIN_DAEMON_SRC_DIR" -type f -not -path "*/.git/*" -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}'
  else
    echo "" # Return empty if source dir doesn't exist
  fi
}

CURRENT_ADMIN_DAEMON_HASH=$(calculate_admin_daemon_hash)
log_status "Current admin_daemon source hash: $CURRENT_ADMIN_DAEMON_HASH"

if [ -f "$ADMIN_DAEMON_HASH_FILE" ]; then
  OLD_ADMIN_DAEMON_HASH=$(cat "$ADMIN_DAEMON_HASH_FILE")
  log_status "Old admin_daemon source hash: $OLD_ADMIN_DAEMON_HASH"
  if [ "$CURRENT_ADMIN_DAEMON_HASH" != "$OLD_ADMIN_DAEMON_HASH" ]; then
    log_status "Admin daemon source code has changed. Rebuild will be triggered."
    SHOULD_REBUILD_ADMIN_DAEMON=true
  else
    log_status "Admin daemon source code has not changed."
    SHOULD_REBUILD_ADMIN_DAEMON=false
  fi
else
  log_status "No old admin_daemon hash file found. Rebuild will be triggered."
  SHOULD_REBUILD_ADMIN_DAEMON=true
fi

# Rebuild webapp container with --no-cache to ensure latest config
log_status "Rebuilding webapp container with --no-cache..."
docker compose -f config/docker/docker-compose.yml build --no-cache webapp

ADMIN_DAEMON_COMPOSE_CMD="docker compose -p ctl_admin -f config/docker/docker-compose.admin.yml up -d"

if [ "$SHOULD_REBUILD_ADMIN_DAEMON" = true ]; then
  log_status "Executing admin daemon compose with --build..."
  $ADMIN_DAEMON_COMPOSE_CMD --build admin-daemon # Target only admin-daemon for build
else
  log_status "Executing admin daemon compose without --build..."
  $ADMIN_DAEMON_COMPOSE_CMD admin-daemon # Target only admin-daemon
fi

# After successful compose up, if a rebuild happened, update the hash file
if [ "$SHOULD_REBUILD_ADMIN_DAEMON" = true ]; then
  # Check if admin daemon started successfully before updating hash
  # We'll infer this by checking if the /admin/health endpoint becomes ready later.
  # For now, we optimistically assume success if compose up doesn't fail immediately.
  # A more robust check would be after the health check loop.
  # However, if compose up fails, this part won't be reached due to "set -e" or manual exits.
  echo "$CURRENT_ADMIN_DAEMON_HASH" > "$ADMIN_DAEMON_HASH_FILE"
  log_status "Updated admin_daemon hash file with new hash: $CURRENT_ADMIN_DAEMON_HASH"
fi

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