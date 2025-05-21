#!/bin/bash

# Exit on error
set -e

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

# Create cloudllm user if it doesn't exist
if ! id "cloudllm" &>/dev/null; then
  log_status "Creating cloudllm user..."
  useradd -m -s /bin/bash cloudllm
  log_success "Created cloudllm user"
else
  log_status "cloudllm user already exists"
fi

# Create necessary directories
log_status "Setting up directories..."
mkdir -p /opt/cloudtolocalllm
mkdir -p /home/cloudllm/.ssh
chown -R cloudllm:cloudllm /opt/cloudtolocalllm
chown -R cloudllm:cloudllm /home/cloudllm/.ssh
chmod 700 /home/cloudllm/.ssh
log_success "Directories set up"

# Add user to docker group
log_status "Adding cloudllm to docker group..."
usermod -aG docker cloudllm
log_success "Added cloudllm to docker group"

# Set up SSH key
log_status "Setting up SSH key..."
if [ -f /root/.ssh/id_ed25519.pub ]; then
  cat /root/.ssh/id_ed25519.pub > /home/cloudllm/.ssh/authorized_keys
  chown cloudllm:cloudllm /home/cloudllm/.ssh/authorized_keys
  chmod 600 /home/cloudllm/.ssh/authorized_keys
  log_success "SSH key set up"
else
  log_error "SSH public key not found at /root/.ssh/id_ed25519.pub"
  exit 1
fi

# Set up Git configuration
log_status "Setting up Git configuration..."
sudo -u cloudllm git config --global --add safe.directory /opt/cloudtolocalllm
log_success "Git configuration set up"

log_success "Setup completed successfully!" 