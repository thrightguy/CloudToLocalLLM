#!/bin/bash
# Fix permissions for cloudllm user
# This script should be run as root

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_status() {
  echo -e "${YELLOW}[STATUS]${NC} $1"
}
log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}
log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  log_error "This script must be run as root"
  exit 1
fi

INSTALL_DIR="/opt/cloudtolocalllm"
CLOUDLLM_USER="cloudllm"
CLOUDLLM_GROUP="cloudllm"

log_status "Fixing permissions for $INSTALL_DIR..."

# Create cloudllm group if it doesn't exist
if ! getent group "$CLOUDLLM_GROUP" >/dev/null; then
  log_status "Creating group $CLOUDLLM_GROUP..."
  groupadd "$CLOUDLLM_GROUP"
fi

# Add cloudllm user to the group if not already a member
if ! groups "$CLOUDLLM_USER" | grep -q "$CLOUDLLM_GROUP"; then
  log_status "Adding $CLOUDLLM_USER to group $CLOUDLLM_GROUP..."
  usermod -a -G "$CLOUDLLM_GROUP" "$CLOUDLLM_USER"
fi

# Change ownership of the installation directory
log_status "Changing ownership of $INSTALL_DIR to $CLOUDLLM_USER:$CLOUDLLM_GROUP..."
chown -R "$CLOUDLLM_USER:$CLOUDLLM_GROUP" "$INSTALL_DIR"

# Set proper permissions
log_status "Setting proper permissions..."
find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
find "$INSTALL_DIR" -type f -exec chmod 644 {} \;

# Make scripts executable
log_status "Making scripts executable..."
find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;

# Ensure Docker socket is accessible
log_status "Ensuring Docker socket is accessible..."
if [ -e /var/run/docker.sock ]; then
  chmod 666 /var/run/docker.sock
  if ! getent group docker >/dev/null; then
    groupadd docker
  fi
  usermod -aG docker "$CLOUDLLM_USER"
fi

log_success "Permissions have been fixed successfully"
log_status "You may need to log out and log back in for group changes to take effect" 