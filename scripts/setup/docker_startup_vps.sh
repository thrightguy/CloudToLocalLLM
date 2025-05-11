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

# Step 0: Clean up previous Docker environment using Docker Compose
log_status "[0/3] Cleaning up previous Docker environment..."
cd "$INSTALL_DIR" # Ensure we are in the correct directory for compose
docker compose -f config/docker/docker-compose.yml down --volumes --remove-orphans || log_status "No existing services to clean up or cleanup already performed."

# Remove unused 'cloudllm-network' if not in use by other projects (optional, can be kept if managed by compose)
# This might be handled by 'docker compose down --remove-orphans' if the network is exclusive to this compose project.
# For safety, we can leave the more specific check, or rely on compose.
if docker network ls | grep -q 'cloudllm-network'; then
  if ! docker network inspect cloudllm-network | grep -q '"Containers": {}' && ! docker network inspect cloudllm-network | grep -q '"Containers": null'; then
    log_status "'cloudllm-network' is still in use by some containers, not removing."
  else
    # Check if the network is managed by any docker-compose project.
    # This is a heuristic; a network might be externally created.
    # If `com.docker.compose.project` label is present, and it's not for *our* project (if we knew its name), we'd skip.
    # For now, if it appears empty or only has null containers, attempt removal.
    log_status "Attempting to remove 'cloudllm-network' if it is unused..."
    docker network rm cloudllm-network || log_status "'cloudllm-network' could not be removed (may be in use or already gone)."
  fi
fi

# Step 1: Ensure Docker is installed and running
log_status "[1/3] Checking Docker installation..."
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker is not installed. Aborting.${NC}" >&2
  exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_status "Starting Docker service..."
    systemctl start docker
fi

# Log content of Dockerfile.web for debugging (optional, can be removed if too verbose)
# log_status "Content of $INSTALL_DIR/config/docker/Dockerfile.web:"
# cat "$INSTALL_DIR/config/docker/Dockerfile.web" || log_error "Could not display Dockerfile.web"
# log_status "-----------------------------------------------------"

# Step 2: Build/Rebuild all services from docker-compose.yml
log_status "[2/3] Building/Rebuilding services with --no-cache..."
cd "$INSTALL_DIR"
docker compose -f config/docker/docker-compose.yml build --no-cache
if [ $? -ne 0 ]; then
  log_error "Docker compose build failed. Please check the output above."
  exit 1
fi
log_success "All services built successfully."

# Step 3: Start all services
log_status "[3/3] Starting all services..."
docker compose -f config/docker/docker-compose.yml up -d
if [ $? -ne 0 ]; then
  log_error "Docker compose up failed. Please check the output above and container logs."
  log_error "You can check logs using: docker compose -f config/docker/docker-compose.yml logs"
  exit 1
fi

# After deployment, check that all containers are on the 'cloudllm-network'
# This check might need adjustment if your main docker-compose.yml defines a different network name
# or if the project name prefix changes the effective network name.
# The default network name is usually <project_name>_default.
# 'cloudllm-network' is explicitly defined in the provided docker-compose.yml, so this check should be okay.
log_status "Checking that containers are attached to 'cloudllm-network'..."
# Give services a moment to attach to the network
sleep 5 
NETWORK_INSPECT=$(docker network inspect cloudllm-network 2>/dev/null || echo "Network not found")
if [[ "$NETWORK_INSPECT" == "Network not found" ]] || [[ "$NETWORK_INSPECT" == *'"Containers": {}'* ]] || [[ "$NETWORK_INSPECT" == *'"Containers": null'* ]]; then
  log_warning "No containers actively found on 'cloudllm-network', or network doesn't exist. This might be okay if services are still starting or if a different network is primary."
  log_warning "Check 'docker ps' and 'docker network ls'. Also inspect services: docker compose -f config/docker/docker-compose.yml ps"
else
  log_success "Containers appear to be attached to 'cloudllm-network'."
fi

log_status "==== $(date) Docker-based startup/restart complete ===="
log_success "System services are now starting up in Docker containers."
log_status "Use 'docker compose -f config/docker/docker-compose.yml ps' to see running services."
log_status "Use 'docker compose -f config/docker/docker-compose.yml logs -f' to tail logs." 