#!/bin/bash

# Script to fix dependencies without full deployment
# Handles pub get and dependency updates only

set -e  # Exit on error

echo "[STATUS] ==== $(date) Starting dependency fix ===="

# Directory 
cd /opt/cloudtolocalllm

# Clean up any local changes to pubspec.lock
echo "[STATUS] Cleaning up pubspec.lock..."
git checkout -- pubspec.lock

# Pull latest code (contains the fixed dependency versions)
echo "[STATUS] Pulling latest code with fixed dependencies..."
git pull

# Run pub get in main project
echo "[STATUS] Running flutter pub get in main project..."
flutter pub get

# Run pub get in admin_control_daemon
echo "[STATUS] Running flutter pub get in admin_control_daemon..."
cd admin_control_daemon
flutter pub get
cd ..

# Run pub get in auth_service
echo "[STATUS] Running flutter pub get in auth_service..."
cd auth_service
flutter pub get
cd ..

echo "[STATUS] Flutter dependencies updated successfully"
echo "[STATUS] ==== $(date) Dependency fix complete ====" 