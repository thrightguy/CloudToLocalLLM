#!/bin/bash
set -e

# This script builds the Flutter web app as the appuser without requiring a password.
# Usage: sudo ./scripts/utils/flutter_build_as_appuser.sh

PROJECT_DIR="/opt/cloudtolocalllm"
FLUTTER_BIN="/var/lib/snapd/snap/bin/flutter"
APPUSER="appuser"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# Ensure appuser owns the project directory
chown -R $APPUSER:$APPUSER "$PROJECT_DIR"

# Run the build as appuser
sudo -u $APPUSER -H bash -c "cd $PROJECT_DIR && $FLUTTER_BIN build web --release" 