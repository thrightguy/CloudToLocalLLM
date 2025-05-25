#!/bin/bash
# NOTE: Do NOT run git push on the VPS. Only run this script after you have pushed your changes from your local machine and pulled them on the VPS.
# This script expects the Flutter web build output to be in build/web/ in your repo root.
set -e

# Pull latest code
echo "Pulling latest code..."
git pull

# Copy static homepage
echo "Copying static homepage to container..."
docker cp static_homepage/. cloudtolocalllm-webapp:/usr/share/nginx/landing/

# Copy Flutter build (from build/web)
echo "Copying Flutter build to container..."
docker cp build/web/. cloudtolocalllm-webapp:/usr/share/nginx/html/

# Copy nginx config
echo "Copying nginx config to container..."
docker cp config/nginx/nginx-webapp-internal.conf cloudtolocalllm-webapp:/etc/nginx/conf.d/default.conf

# Reload nginx
echo "Reloading nginx..."
docker exec cloudtolocalllm-webapp nginx -s reload

echo "Update complete!" 