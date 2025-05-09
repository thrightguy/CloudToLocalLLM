#!/bin/bash
# Usage: ./scripts/setup/commit_only.sh [commit message]
set -e

COMMIT_MSG="${1:-Update project}"

# Commit and print push instructions
echo "[STATUS] Adding all changes..."
git add .
echo "[STATUS] Committing..."
git commit -m "$COMMIT_MSG" || echo "[INFO] Nothing to commit."
echo "[STATUS] To push your changes, run:"
echo "    git push"
echo "[INFO] After pushing, SSH into your VPS and run:"
echo "    cd /opt/cloudtolocalllm && git pull" 