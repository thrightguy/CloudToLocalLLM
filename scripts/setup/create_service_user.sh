#!/bin/bash
# Create and configure a dedicated non-root user for CloudToLocalLLM services
# Run as root: bash scripts/setup/create_service_user.sh

set -euo pipefail

# Configuration
SERVICE_USER="cloudllm"
INSTALL_DIR="/opt/cloudtolocalllm"
LOG_FILE="$INSTALL_DIR/logs/user_setup.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}This script must be run as root${NC}" >&2
  exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${YELLOW}[$(date)] Creating service user $SERVICE_USER for CloudToLocalLLM...${NC}"

# Create user if it doesn't exist
if id "$SERVICE_USER" &>/dev/null; then
    echo -e "${YELLOW}User $SERVICE_USER already exists, skipping creation${NC}"
else
    useradd -m -s /bin/bash "$SERVICE_USER"
    echo -e "${GREEN}Created user $SERVICE_USER${NC}"
fi

# Add user to necessary groups (docker)
usermod -aG docker "$SERVICE_USER" || echo -e "${YELLOW}Failed to add $SERVICE_USER to docker group${NC}"
# Try to add to sudo group if it exists
if getent group sudo >/dev/null; then
    usermod -aG sudo "$SERVICE_USER" || echo -e "${YELLOW}Failed to add $SERVICE_USER to sudo group${NC}"
else
    echo -e "${YELLOW}Group 'sudo' does not exist, can't add user to it${NC}"
fi

# Set correct permissions on installation directory
echo -e "${YELLOW}Setting correct permissions on $INSTALL_DIR...${NC}"
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

# Create or update .bashrc for the service user to include Flutter and Dart in PATH
echo -e "${YELLOW}Setting up environment for $SERVICE_USER...${NC}"
cat >> "/home/$SERVICE_USER/.bashrc" << EOL

# CloudToLocalLLM environment setup
export PATH="\$HOME/.pub-cache/bin:\$PATH"
# If Flutter is installed globally, make sure it's in the path
if [ -d "/opt/flutter/bin" ]; then
  export PATH="/opt/flutter/bin:\$PATH"
fi
EOL

# Create necessary directories
mkdir -p "/home/$SERVICE_USER/.pub-cache"
chown -R "$SERVICE_USER:$SERVICE_USER" "/home/$SERVICE_USER/.pub-cache"

# Update systemd service files to use the non-root user
echo -e "${YELLOW}Updating systemd service to use non-root user...${NC}"

# Create/update the daemon service file
cat > /etc/systemd/system/cloudllm-daemon.service << EOL
[Unit]
Description=CloudToLocalLLM Admin Control Daemon
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR/admin_control_daemon
ExecStart=$INSTALL_DIR/admin_control_daemon/daemon
Restart=on-failure
User=$SERVICE_USER
Group=$SERVICE_USER
Environment=HOME=/home/$SERVICE_USER

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd to recognize the changes
systemctl daemon-reload

echo -e "${GREEN}Service user setup complete!${NC}"
echo -e "You can now run services as the $SERVICE_USER user"
echo -e "Systemd services have been updated to use the $SERVICE_USER user"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Restart the daemon: systemctl restart cloudllm-daemon"
echo -e "2. Check status: systemctl status cloudllm-daemon" 