#!/bin/bash
# Usage: sudo bash setup_cloudllm_user.sh <public_key_file>
# Example: sudo bash setup_cloudllm_user.sh /root/.ssh/authorized_keys

set -e

USERNAME=cloudllm
PUBKEY_FILE=${1:-/root/.ssh/authorized_keys}

# 1. Create the user if it doesn't exist
echo "[INFO] Creating user $USERNAME if not exists..."
id -u $USERNAME &>/dev/null || adduser --disabled-password --gecos "" $USERNAME

# 2. Add to sudoers
echo "[INFO] Adding $USERNAME to sudo group..."
usermod -aG sudo $USERNAME

# 3. Add to docker group (if docker is installed)
if getent group docker > /dev/null; then
    echo "[INFO] Adding $USERNAME to docker group..."
    usermod -aG docker $USERNAME
else
    echo "[WARN] Docker group not found. Install Docker first, then rerun this step."
fi

# 4. Set up SSH key for the new user
echo "[INFO] Setting up SSH key for $USERNAME..."
mkdir -p /home/$USERNAME/.ssh
cp $PUBKEY_FILE /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys

# 5. (Optional) Disable password login for the user (uncomment to enable)
# passwd -l $USERNAME

echo "[INFO] User $USERNAME setup complete. You can now SSH as $USERNAME." 