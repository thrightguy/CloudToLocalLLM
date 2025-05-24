#!/bin/bash

# Exit on any error
set -e

# Create backup directory with timestamp
BACKUP_DIR="./certbot/backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Copy certificates with error checking
if [ ! -d "./certbot/live" ]; then
    echo "Error: Source directory ./certbot/live does not exist"
    exit 1
fi

cp -r ./certbot/live/* "$BACKUP_DIR/"
cp -r ./certbot/archive/* "$BACKUP_DIR/archive/"

echo "SSL certificates backed up to $BACKUP_DIR" 