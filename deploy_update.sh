#!/bin/bash
set -e

# Pull latest code
echo "Pulling latest code..."
git pull

# Copy static homepage
echo "Copying static homepage to container..."
docker cp static_homepage/. cloudtolocalllm-webapp:/usr/share/nginx/landing/

# Copy Flutter build
echo "Copying Flutter build to container..."
docker cp flutter_build/. cloudtolocalllm-webapp:/usr/share/nginx/html/

# Copy nginx config
echo "Copying nginx config to container..."
docker cp config/nginx/nginx-webapp-internal.conf cloudtolocalllm-webapp:/etc/nginx/conf.d/default.conf

# Reload nginx
echo "Reloading nginx..."
docker exec cloudtolocalllm-webapp nginx -s reload

echo "Update complete!" 