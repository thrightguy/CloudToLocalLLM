#!/bin/bash
# CloudToLocalLLM VPS Startup Script
#
# This script rebuilds and restarts the admin daemon,
# and triggers a full stack deployment via the daemon API.
#
# Usage: Run as root (su - or sudo -i), then:
#   bash scripts/setup/startup_vps.sh
# Logs are written to /opt/cloudtolocalllm/startup.log

set -euo pipefail

# Configuration
SERVICE_USER="cloudllm"
INSTALL_DIR="/opt/cloudtolocalllm"
LOGFILE="$INSTALL_DIR/startup.log"

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
log_status "==== $(date) Starting CloudToLocalLLM stack ===="

# Step 1: Ensure service user exists
log_status "[1/5] Setting up service user..."
if [ -f "$INSTALL_DIR/scripts/setup/create_service_user.sh" ]; then
  bash "$INSTALL_DIR/scripts/setup/create_service_user.sh"
else
  log_error "Service user setup script not found"
  exit 1
fi

# Step 2: Stop admin daemon
log_status "[2/5] Stopping admin daemon..."
if ! systemctl stop cloudllm-daemon; then
  log_error "Failed to stop admin daemon (may not be running)";
fi

# Step 3: Install dependencies for admin daemon (as root, then give correct permissions)
log_status "[3/5] Installing dependencies and rebuilding admin daemon..."
cd "$INSTALL_DIR/admin_control_daemon" || { log_error "Failed to cd to admin_control_daemon"; exit 1; }

# First, install dependencies as root so they're available system-wide
dart pub get

# Make sure pub cache is accessible
mkdir -p /home/$SERVICE_USER/.pub-cache
chown -R $SERVICE_USER:$SERVICE_USER /home/$SERVICE_USER/.pub-cache

# Fix permissions on admin control daemon directory
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR/admin_control_daemon"

# Switch to service user for compilation
su - "$SERVICE_USER" -c "cd '$INSTALL_DIR/admin_control_daemon' && dart compile exe bin/server.dart -o daemon"
if [ ! -f "$INSTALL_DIR/admin_control_daemon/daemon" ]; then
  log_error "Failed to compile admin daemon"; exit 1;
fi

cd "$INSTALL_DIR" || { log_error "Failed to cd to $INSTALL_DIR after build"; exit 1; }

# Step 4: Start admin daemon
log_status "[4/5] Starting admin daemon..."
if ! systemctl start cloudllm-daemon; then
  log_error "Failed to start admin daemon"; exit 1;
fi
systemctl status cloudllm-daemon --no-pager || log_error "Failed to get admin daemon status"

# Step 5: Deploy all services
sleep 3
log_status "[5/5] Triggering full stack deployment via daemon API..."
curl -X POST http://localhost:9001/admin/deploy/all --max-time 180

log_status "==== $(date) Startup complete ===="
log_success "System is now running as the $SERVICE_USER user" 