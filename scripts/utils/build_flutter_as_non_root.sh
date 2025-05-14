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

# Fix permissions so appuser owns the project directory
chown -R "$TARGET_USER":"$TARGET_USER" "$PROJECT_DIR"

# Check if flutter is available for the user, and fix PATH if needed
if ! runuser -u "$TARGET_USER" -- which flutter &>/dev/null; then
  echo "Flutter is not in PATH for $TARGET_USER. Attempting to fix..."
  FLUTTER_BIN="$(which flutter 2>/dev/null || true)"
  if [ -z "$FLUTTER_BIN" ]; then
    for d in /usr/local/bin /usr/bin /opt/flutter/bin /snap/bin; do
      if [ -x "$d/flutter" ]; then
        FLUTTER_BIN="$d/flutter"; break
      fi
    done
  fi
  if [ -z "$FLUTTER_BIN" ]; then
    echo "Could not find flutter binary. Please install Flutter and ensure it is available." >&2
    exit 2
  fi
  FLUTTER_DIR="$(dirname "$FLUTTER_BIN")"
  su - "$TARGET_USER" -c "grep -q 'export PATH=.*$FLUTTER_DIR' ~/.bashrc || echo 'export PATH=\"$FLUTTER_DIR:\$PATH\"' >> ~/.bashrc"
  export PATH="$FLUTTER_DIR:$PATH"
fi

# Run the build commands as the target user (no sudo)
runuser -u "$TARGET_USER" -- bash -c "cd '$PROJECT_DIR' && source ~/.bashrc && flutter clean && flutter pub get && flutter build web" 