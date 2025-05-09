#!/bin/bash
# Usage: ./scripts/setup/commit_and_pull.sh user@vps [commit message]
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 user@vps [commit message]"
  exit 1
fi

VPS="$1"
COMMIT_MSG="${2:-Update project}"
PROJECT_DIR="/opt/cloudtolocalllm"

# Commit and push
echo "[STATUS] Adding all changes..."
git add .
echo "[STATUS] Committing..."
git commit -m "$COMMIT_MSG" || echo "[INFO] Nothing to commit."
echo "[STATUS] Pushing to GitHub..."
git push

echo "[STATUS] Connecting to VPS and pulling latest code..."
ssh "$VPS" "cd $PROJECT_DIR && git pull"

echo "[STATUS] Done!" 