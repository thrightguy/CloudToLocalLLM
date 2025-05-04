#!/bin/bash

# Source common functions
source /tmp/auth0_scripts/common.sh

yellow "Restarting services..."

# Navigate to Docker Compose directory
cd /opt/cloudtolocalllm || exit 1

# First try with docker-compose
if [ -f "docker-compose.yml" ]; then
    yellow "Using docker-compose to restart services..."
    docker-compose down || yellow "Warning: docker-compose down failed"
    docker-compose up -d || yellow "Warning: docker-compose up failed"
    green "Services restarted with docker-compose"
else
    # Try to restart manually
    yellow "docker-compose.yml not found, restarting containers manually..."
    
    # Find all nginx containers
    NGINX_CONTAINERS=$(docker ps -a | grep nginx | awk '{print $1}')
    if [ -n "$NGINX_CONTAINERS" ]; then
        yellow "Restarting Nginx containers..."
        for CONTAINER in $NGINX_CONTAINERS; do
            docker restart $CONTAINER || yellow "Warning: Failed to restart container $CONTAINER"
        done
        green "Restarted Nginx containers"
    else
        red "No Nginx containers found to restart"
    fi
    
    # Find ALL containers associated with the application if possible
    APP_CONTAINERS=$(docker ps -a --filter "label=com.docker.compose.project=cloudtolocalllm" -q)
    if [ -n "$APP_CONTAINERS" ]; then
        yellow "Restarting all application containers..."
        for CONTAINER in $APP_CONTAINERS; do
            docker restart $CONTAINER || yellow "Warning: Failed to restart container $CONTAINER"
        done
        green "Restarted all application containers"
    fi
fi

green "All services restarted successfully"