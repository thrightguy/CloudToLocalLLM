#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing CloudToLocalLLM daemon...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Stop the service if it's running
systemctl stop cloudtolocalllm.service

echo -e "${YELLOW}Ensuring docker service is running...${NC}"
systemctl start docker || {
    echo -e "${RED}Failed to start Docker service${NC}"
    exit 1
}

echo -e "${YELLOW}Creating fixed service file...${NC}"
cat > /etc/systemd/system/cloudtolocalllm.service << 'EOF'
[Unit]
Description=CloudToLocalLLM Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/cloudtolocalllm/portal

# Environment setup
Environment=COMPOSE_HTTP_TIMEOUT=300

# Create required directories
ExecStartPre=/bin/bash -c 'mkdir -p /opt/cloudtolocalllm/logs'
ExecStartPre=/bin/bash -c 'mkdir -p certbot/www certbot/conf'

# Ensure Docker is running
ExecStartPre=/bin/bash -c 'systemctl is-active --quiet docker || systemctl start docker'

# Pull images first
ExecStartPre=/usr/bin/docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml pull --quiet --ignore-pull-failures

# Start services with logging
ExecStart=/bin/bash -c '/usr/bin/docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml up --remove-orphans 2>&1 | tee -a /opt/cloudtolocalllm/logs/service.log'

# Stop services gracefully
ExecStop=/usr/bin/docker-compose -f docker-compose.auth.yml -f docker-compose.web.yml down

# Restart policy
Restart=always
RestartSec=10

# Give the service time to start up
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}Reloading systemd...${NC}"
systemctl daemon-reload || {
    echo -e "${RED}Failed to reload systemd${NC}"
    exit 1
}

echo -e "${YELLOW}Restarting service...${NC}"
systemctl restart cloudtolocalllm.service

# Wait a bit to check status
sleep 5

# Check service status
if systemctl is-active --quiet cloudtolocalllm.service; then
    echo -e "${GREEN}Service started successfully${NC}"
else
    echo -e "${RED}Service failed to start. Checking logs...${NC}"
    echo -e "${YELLOW}Service Status:${NC}"
    systemctl status cloudtolocalllm.service
    echo -e "${YELLOW}Docker Compose Logs:${NC}"
    tail -n 50 /opt/cloudtolocalllm/logs/service.log
    exit 1
fi 