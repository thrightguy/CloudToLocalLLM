#!/bin/bash
# drop_root_and_run.sh
# This script must be run as root. It will drop privileges to a non-root user and run the given command.

set -e

TARGET_USER="appuser"

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Create the user if it doesn't exist
if ! id "$TARGET_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$TARGET_USER"
fi

# If no command is given, print usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 2
fi

# Run the command as the target user
exec sudo -u "$TARGET_USER" -- "$@" 