#!/bin/bash
# Docker-based CloudToLocalLLM VPS Startup Script
# This script uses Docker to build and run the application stack.
#
# Usage: Run as root (su - or sudo -i), then:
#   bash scripts/setup/docker_startup_vps.sh

set -uo pipefail

# Configuration
INSTALL_DIR="/opt/cloudtolocalllm"
LOGFILE="$INSTALL_DIR/startup_docker.log"
COMPOSE_FILE="docker-compose.yml" # Use the root compose file

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

log_status "Attempting to stop and remove potentially conflicting old DB container (cloudtolocalllm-fusionauth-db)..."
docker stop cloudtolocalllm-fusionauth-db >/dev/null 2>&1 || true
docker rm cloudtolocalllm-fusionauth-db >/dev/null 2>&1 || true
log_status "Done attempting to remove old DB container."

docker compose -f "$COMPOSE_FILE" down --volumes --remove-orphans || log_status "No existing services to clean up or cleanup already performed for project using $COMPOSE_FILE."

# Optional: Remove unused 'cloudllm-network' if not managed by compose and truly unused
# This part can be tricky if other applications might use it.
# If 'cloudllm-network' is defined *within* your main docker-compose.yml and set to external:false (default),
# 'docker compose down' should handle it if it's not in use by other containers of the same project.
# If it's an external network, manual cleanup might be needed if desired and safe.
# log_status "Checking 'cloudllm-network'..."
# if docker network inspect cloudllm-network >/dev/null 2>&1; then
#   if [[ -z $(docker ps -q --filter network=cloudllm-network) ]]; then
#     log_status "'cloudllm-network' exists and appears unused. Consider manual removal if it's not managed by your compose project: docker network rm cloudllm-network"
#   else
#     log_status "'cloudllm-network' is still in use."
#   fi
# else
#   log_status "'cloudllm-network' does not exist."
# fi

# Step 1: Ensure Docker is installed and running
log_status "[1/3] Checking Docker installation..."
if ! command -v docker &>/dev/null; then
  log_error "Docker is not installed. Aborting."
  exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_status "Starting Docker service..."
    systemctl start docker
fi

# Step 2: Build/Rebuild all services from docker-compose.yml
log_status "[2/3] Building/Rebuilding services with --no-cache from $COMPOSE_FILE..."
cd "$INSTALL_DIR"
docker compose -f "$COMPOSE_FILE" build --no-cache
if [ $? -ne 0 ]; then
  log_error "Docker compose build failed. Please check the output above."
  exit 1
fi
log_success "All services built successfully."

# Step 3: Start all services
log_status "[3/3] Starting all services from $COMPOSE_FILE..."
docker compose -f "$COMPOSE_FILE" up -d
if [ $? -ne 0 ]; then
  log_error "Docker compose up failed. Please check the output above and container logs."
  log_error "You can check logs using: docker compose -f $COMPOSE_FILE logs"
  exit 1
fi

log_status "Verifying running services (this may take a moment for services to initialize)..."
sleep 10 # Give services a moment to start
docker compose -f "$COMPOSE_FILE" ps

log_status "==== $(date) Docker-based startup/restart complete ===="
log_success "System services are now starting up in Docker containers."
log_status "Use 'docker compose -f $COMPOSE_FILE ps' to see running services."
log_status "Use 'docker compose -f $COMPOSE_FILE logs -f' to tail logs." 