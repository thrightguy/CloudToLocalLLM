#!/bin/bash

set -e
set -o pipefail

CLOUDLLM_USER="cloudllm"
CLOUDLLM_HOME="/home/$CLOUDLLM_USER"
REPO_DIR="/opt/cloudtolocalllm"
REPO_URL="https://github.com/thrightguy/CloudToLocalLLM.git"
USER_PUBLIC_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmt52b2bC4DCH81qyeB3d7SPvk8tR/LIjGUp3aas4gw christopher.maltais@gmail.com"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root. Please run with sudo or as root."
  exit 1
fi

echo "[INFO] Starting VPS initial setup for CloudToLocalLLM..."

apt-get update -y
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker --version
docker compose version

echo "[INFO] Creating user '$CLOUDLLM_USER'..."
if id "$CLOUDLLM_USER" &>/dev/null; then
    echo "[INFO] User '$CLOUDLLM_USER' already exists."
else
    adduser --disabled-password --gecos "" "$CLOUDLLM_USER"
    echo "[SUCCESS] User '$CLOUDLLM_USER' created."
fi

mkdir -p "$CLOUDLLM_HOME/.ssh"
echo "$USER_PUBLIC_SSH_KEY" > "$CLOUDLLM_HOME/.ssh/authorized_keys"
chown -R "$CLOUDLLM_USER:$CLOUDLLM_USER" "$CLOUDLLM_HOME/.ssh"
chmod 700 "$CLOUDLLM_HOME/.ssh"
chmod 600 "$CLOUDLLM_HOME/.ssh/authorized_keys"
usermod -aG docker "$CLOUDLLM_USER"

mkdir -p "$REPO_DIR"
chown "$CLOUDLLM_USER:$CLOUDLLM_USER" "$REPO_DIR"

sudo -u "$CLOUDLLM_USER" git clone "$REPO_URL" "$REPO_DIR" || true

if [ -f "$REPO_DIR/scripts/setup/main_vps.sh" ]; then
    bash "$REPO_DIR/scripts/setup/main_vps.sh" deploy
else
    echo "[ERROR] Main deployment script not found at $REPO_DIR/scripts/setup/main_vps.sh"
    exit 1
fi

echo "[INFO] ---- VPS Initial Setup Script Completed ----"
exit 0 