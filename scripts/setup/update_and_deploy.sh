#!/bin/bash

# Configure script behavior
set -e  # Exit immediately if a command exits with a non-zero status

# Set the timestamp format for logs
TIMESTAMP=$(date)

echo "[STATUS] ==== $TIMESTAMP Starting CloudToLocalLLM update and deployment ===="

# Step 1: Pull latest code
echo "[STATUS] [1/7] Pulling latest code from GitHub..."
git pull

# Step 2: Check Android embedding
echo "[STATUS] [2/7] Checking and fixing Android embedding..."
# Run the comprehensive Android migration script
if [ -f "./scripts/setup/migrate_android_v2.sh" ]; then
  bash ./scripts/setup/migrate_android_v2.sh
else
  echo "[ERROR] Android migration script not found!"
  exit 1
fi

# Step 3: Fix Docker build configurations
echo "[STATUS] [3/7] Fixing Docker build configurations..."
if [ -f "./scripts/setup/fix_docker_build.sh" ]; then
  bash ./scripts/setup/fix_docker_build.sh
else
  echo "[WARNING] Docker fix script not found, skipping..."
fi

# Step 4: Clean Flutter build
echo "[STATUS] [4/7] Cleaning Flutter build..."
flutter clean

# Step 5: Stop admin daemon
echo "[STATUS] [5/7] Stopping admin daemon..."
systemctl stop cloudllm-daemon.service || true

# Step 6: Rebuild admin daemon
echo "[STATUS] [6/7] Rebuilding admin daemon..."
cd admin_control_daemon
flutter pub get
dart compile exe bin/main.dart -o daemon
cd ..
cp -f admin_control_daemon/daemon /opt/cloudtolocalllm/admin_control_daemon/daemon

# Step 7: Start admin daemon and deploy services
echo "[STATUS] [7/7] Starting admin daemon and deploying services..."
systemctl start cloudllm-daemon.service

# Wait for the daemon to fully start
sleep 5

# Deploy services
echo "[STATUS] Triggering deployment of all services..."
curl -s -X POST http://localhost:8090/admin/deploy/all -H "Content-Type: application/json" -d '{"force": true}' | jq

echo "[STATUS] ==== $(date) Update and deployment complete ===="
echo "[STATUS] For detailed logs, use: systemctl status cloudllm-daemon.service" 