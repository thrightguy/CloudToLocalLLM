#!/bin/bash
set -e

# Clean, fetch dependencies, and redeploy Flutter web app in Docker

echo "[1/7] Removing old build/web directory..."
rm -rf build/web

echo "[2/7] Cleaning Flutter project..."
flutter clean

echo "[3/7] Getting Flutter dependencies..."
flutter pub get

echo "[4/7] Building Flutter web app..."
flutter build web

echo "[5/7] Rebuilding Docker webapp image (no cache)..."
docker compose build --no-cache webapp

echo "[6/7] Recreating and restarting webapp container..."
docker compose up -d --force-recreate webapp

echo "[7/7] Deployment complete. Showing running containers:"
docker compose ps 