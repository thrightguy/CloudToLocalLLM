#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing CloudToLocalLLM daemon...${NC}"

# Install docker compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing docker-compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Ensure docker is running
echo -e "${YELLOW}Ensuring docker service is running...${NC}"
systemctl is-active --quiet docker || systemctl start docker

# Create fixed service file
echo -e "${YELLOW}Creating fixed service file...${NC}"
cat > /etc/systemd/system/cloudtolocalllm.service << 'EOFSERVICE'
[Unit]
Description=CloudToLocalLLM Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/cloudtolocalllm/portal
User=root
Group=root

# Setup environment
ExecStartPre=/bin/bash -c 'mkdir -p /opt/cloudtolocalllm/logs'

# Start all services
ExecStart=/usr/bin/docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml up -d

# Stop all services
ExecStop=/usr/bin/docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml down

# Restart policy
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Reload systemd to recognize the new service
echo -e "${YELLOW}Reloading systemd...${NC}"
systemctl daemon-reload

# Restart the service
echo -e "${YELLOW}Restarting service...${NC}"
systemctl restart cloudtolocalllm.service

# Check service status
echo -e "${YELLOW}Checking service status...${NC}"
systemctl status cloudtolocalllm.service

echo -e "${GREEN}Service has been fixed and restarted!${NC}"
echo -e "If you still have issues, run: ${YELLOW}journalctl -xeu cloudtolocalllm.service${NC} to see detailed logs."
echo -e "You can also try running the docker-compose command manually:"
echo -e "${YELLOW}cd /opt/cloudtolocalllm/portal && docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml up -d${NC}" 