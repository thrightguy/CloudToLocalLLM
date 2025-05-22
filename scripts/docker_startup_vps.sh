#!/bin/bash

# Exit on error
set -e

# Create required directories
mkdir -p certbot/www
mkdir -p certbot/conf
mkdir -p ssl

# Create self-signed certificate for nginx to start
echo "Generating self-signed certificate for nginx..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/default.key -out ssl/default.pem \
  -subj "/CN=cloudtolocalllm.online"

# Start Docker Compose
echo "Starting Docker Compose..."
docker compose up -d --build

echo "Docker Compose started successfully." 