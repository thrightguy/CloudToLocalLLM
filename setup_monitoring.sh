#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up Netdata monitoring for CloudToLocalLLM...${NC}"

# Check if docker and docker-compose are installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check if the webnet network exists, if not create it
if ! docker network inspect webnet &> /dev/null; then
    echo -e "${YELLOW}Creating webnet network...${NC}"
    docker network create webnet
    echo -e "${GREEN}Network created.${NC}"
fi

# Optional: Ask for Netdata Cloud token if user wants cloud monitoring
echo -e "${YELLOW}Would you like to connect to Netdata Cloud for remote monitoring? (y/n)${NC}"
read -r use_cloud

if [[ "$use_cloud" == "y" || "$use_cloud" == "Y" ]]; then
    echo -e "${YELLOW}Please get a claim token from https://app.netdata.cloud${NC}"
    echo -e "${YELLOW}Enter your Netdata claim token (or press Enter to skip):${NC}"
    read -r claim_token
    
    if [[ -n "$claim_token" ]]; then
        echo -e "${YELLOW}Enter your Netdata room ID (or press Enter to use default):${NC}"
        read -r claim_rooms
        
        # Export the variables
        export NETDATA_CLAIM_TOKEN="$claim_token"
        if [[ -n "$claim_rooms" ]]; then
            export NETDATA_CLAIM_ROOMS="$claim_rooms"
        fi
    fi
fi

# Start Netdata
echo -e "${YELLOW}Starting Netdata container...${NC}"
docker-compose -f docker-compose.monitor.yml up -d

# Verify that Netdata is running
if docker ps | grep -q "cloudtolocalllm_monitor"; then
    echo -e "${GREEN}Netdata is now running!${NC}"
    
    # Get host IP
    host_ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}========================================================${NC}"
    echo -e "${GREEN}Netdata dashboard is available at:${NC}"
    echo -e "${GREEN}http://${host_ip}:19999${NC}"
    echo -e "${GREEN}========================================================${NC}"
    echo -e "${YELLOW}Monitor the performance of your CloudToLocalLLM deployment in real-time.${NC}"
    
    if [[ -n "${NETDATA_CLAIM_TOKEN:-}" ]]; then
        echo -e "${GREEN}Your system has been claimed to Netdata Cloud.${NC}"
        echo -e "${GREEN}Visit https://app.netdata.cloud to view your dashboard remotely.${NC}"
    fi
    
    echo -e "${YELLOW}To expose the Netdata dashboard through your main domain, add this to your server.conf:${NC}"
    echo -e "${YELLOW}
location /monitor/ {
    proxy_pass http://netdata:19999/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
}${NC}"
else
    echo -e "${RED}Failed to start Netdata.${NC}"
    echo -e "${YELLOW}Check logs with: docker-compose -f docker-compose.monitor.yml logs${NC}"
    exit 1
fi 