#!/bin/bash
set -e

# Clean and redeploy Flutter web app in Docker

echo "[1/5] Removing old build/web directory..."
rm -rf build/web

echo "[2/5] Building Flutter web app..."
flutter build web

echo "[3/5] Rebuilding Docker webapp image (no cache)..."
docker compose build --no-cache webapp

echo "[4/5] Recreating and restarting webapp container..."
docker compose up -d --force-recreate webapp

echo "[5/5] Deployment complete. Showing running containers:"
docker compose ps 