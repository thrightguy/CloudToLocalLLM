#!/bin/bash

# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Create backup directory with timestamp
BACKUP_DIR="/opt/ssl_backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Copy certificates with error checking
if [ ! -d "/opt/cloudtolocalllm/certbot/live" ]; then
    echo "Error: Source directory /opt/cloudtolocalllm/certbot/live does not exist"
    exit 1
fi

cp -r /opt/cloudtolocalllm/certbot/live/* "$BACKUP_DIR/"
cp -r /opt/cloudtolocalllm/certbot/archive/* "$BACKUP_DIR/archive/"

# Set secure permissions
chmod -R 600 "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "SSL certificates backed up to $BACKUP_DIR" 