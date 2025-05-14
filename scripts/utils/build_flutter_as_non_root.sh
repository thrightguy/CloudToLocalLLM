#!/bin/bash
# build_flutter_as_non_root.sh
# This script must be run as root. It will build the Flutter app as a non-root user (appuser), without using sudo.

set -e

TARGET_USER="appuser"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Create the user if it doesn't exist
if ! id "$TARGET_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$TARGET_USER"
fi

# Ensure flutter is available for the user
if ! runuser -u "$TARGET_USER" -- which flutter &>/dev/null; then
  echo "Flutter is not available for $TARGET_USER. Please ensure flutter is installed and in the PATH for this user." >&2
  exit 2
fi

# Run the build commands as the target user (no sudo)
runuser -u "$TARGET_USER" -- bash -c "cd '$PROJECT_DIR' && flutter clean && flutter pub get && flutter build web" 