#!/bin/bash

# Common variables and functions for Auth0 integration

AUTH0_CLIENT_ID="WBibIxpJlvVp64UIpfMqYxDyYC8XDWbU"
AUTH0_DOMAIN="dev-cloudtolocalllm.us.auth0.com"
WEB_ROOT="/opt/cloudtolocalllm/nginx/html"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/opt/cloudtolocalllm/backup_${TIMESTAMP}"

# Create a function for colored output
green() {
    echo -e "\033[0;32m$1\033[0m"
}

yellow() {
    echo -e "\033[1;33m$1\033[0m"
}

red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Function to create backup
create_backup() {
    yellow "Creating backup in $BACKUP_DIR..."
    mkdir -p $BACKUP_DIR
    cp -r $WEB_ROOT/* $BACKUP_DIR/ 2>/dev/null || true
    green "Backup created successfully"
}