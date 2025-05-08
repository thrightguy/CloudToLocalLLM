#!/bin/bash

# Unified script for updating code, fixing Android embedding, and deploying services
# Created to simplify VPS maintenance

set -e  # Exit on error

echo "[STATUS] ==== $(date) Starting CloudToLocalLLM update and deployment ===="

# Log directory
LOG_DIR="/opt/cloudtolocalllm/logs"
mkdir -p $LOG_DIR

# 1. Pull latest code
echo "[STATUS] [1/5] Pulling latest code from GitHub..."
git checkout -- pubspec.lock  # Discard local changes to avoid conflicts
git pull

# 2. Migrate Android embedding to V2 if needed
echo "[STATUS] [2/5] Checking Android embedding..."
if ! grep -q 'flutterEmbedding.*2' android/app/src/main/AndroidManifest.xml 2>/dev/null; then
  echo "[STATUS] Android embedding V2 not found. Migrating..."
  # Make the script executable
  chmod +x scripts/setup/migrate_android_v2.sh
  # Run migration script
  ./scripts/setup/migrate_android_v2.sh
  # Commit changes
  git add android/
  git commit -m "Migrate Android embedding to V2 for device_info_plus compatibility"
  git push
else
  echo "[STATUS] Android embedding V2 already present. Skipping migration."
fi

# 3. Stop admin daemon
echo "[STATUS] [3/5] Stopping admin daemon..."
systemctl stop cloudllm-daemon.service || echo "No daemon was running"

# 4. Rebuild admin daemon
echo "[STATUS] [4/5] Rebuilding admin daemon..."
cd /opt/cloudtolocalllm/admin_control_daemon
flutter pub get
dart compile exe bin/server.dart -o daemon
cd /opt/cloudtolocalllm

# 5. Start admin daemon and deploy services
echo "[STATUS] [5/5] Starting admin daemon and deploying services..."
systemctl start cloudllm-daemon.service

# Wait for daemon to be ready
sleep 3

# Trigger services deployment one by one using the correct API endpoints
echo "[STATUS] Triggering deployment of individual services..."
curl -X POST http://localhost:9001/deploy/webapp
curl -X POST http://localhost:9001/deploy/fusionauth
curl -X POST http://localhost:9001/deploy/tunnel
curl -X POST http://localhost:9001/deploy/monitoring

echo "[STATUS] ==== $(date) Update and deployment complete ===="
echo "[STATUS] For detailed logs, use: systemctl status cloudllm-daemon.service" 