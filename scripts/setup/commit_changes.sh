#!/bin/bash

# Script to commit all changes related to Android embedding and Docker fixes
# and push them to GitHub

set -e  # Exit on error

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "[STATUS] Committing changes to GitHub..."

# Stage all new and modified scripts
git add scripts/setup/migrate_android_v2.sh
git add scripts/setup/update_and_deploy.sh
git add scripts/setup/fix_docker_build.sh
git add scripts/setup/docker_android_fix.sh
git add scripts/setup/README.md
git add scripts/setup/commit_changes.sh

# Stage Docker configuration files
git add config/docker/Dockerfile
git add config/docker/Dockerfile.web
git add docker-compose.yml

# Check if there are staged changes
if git diff --staged --quiet; then
  echo "[STATUS] No changes to commit."
  exit 0
fi

# Commit changes
git commit -m "Fix Android embedding and Docker build issues

- Added comprehensive Android V2 embedding migration script
- Fixed Flutter root user warnings in Docker builds
- Updated deployment scripts
- Added Docker Compose setup
- Added documentation

This commit fixes the issue with device_info_plus plugin requiring
Android embedding V2 and addresses the Flutter root user warnings
in Docker builds.

Date: $TIMESTAMP"

# Push to GitHub
echo "[STATUS] Pushing changes to GitHub..."
git push

echo "[STATUS] Changes successfully committed and pushed to GitHub." 