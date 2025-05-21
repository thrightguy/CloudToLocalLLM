#!/bin/bash

# Exit on any error
set -e

# --- CONFIGURATION ---
NEW_USER="cloudllm"
NEW_USER_HOME="/home/$NEW_USER"
# IMPORTANT: Verify this is your correct repository URL
REPO_URL="https://github.com/rightguy/CloudToLocalLLM.git"
REPO_DIR="$NEW_USER_HOME/CloudToLocalLLM"
# This is the script *inside your repo* that will start Docker services
DEPLOY_ON_VPS_SCRIPT_NAME="scripts/start_docker_services.sh"
DEPLOY_SCRIPT_PATH="$REPO_DIR/$DEPLOY_ON_VPS_SCRIPT_NAME"
LOG_FILE="/var/log/initial_server_setup.log"
# The public key for the new user
NEW_USER_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmt52b2bC4DCH81qyeB3d7SPvk8tR/LIjGUp3aas4gw christopher.maltais@gmail.com"
# --- END CONFIGURATION ---

# Function for logging
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

main() {
    log "Starting initial server setup..."
    exec &> >(tee -a "$LOG_FILE") # Redirect all output to log file and stdout/stderr

    # Ensure script is run as root
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR: This script must be run as root."
        echo "ERROR: This script must be run as root." >&2
        exit 1
    fi

    # 1. SYSTEM UPDATE & BASIC UTILITIES
    log "Updating package lists and installing basic utilities..."
    apt update -y
    apt install -y sudo apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release git ufw tree

    # 2. CREATE NEW USER & SUDO PRIVILEGES
    log "Creating user $NEW_USER..."
    if id "$NEW_USER" &>/dev/null; then
        log "User $NEW_USER already exists."
    else
        useradd -m -s /bin/bash "$NEW_USER"
        log "Adding user $NEW_USER to sudo group..."
        usermod -aG sudo "$NEW_USER"
        log "Configuring passwordless sudo for $NEW_USER..."
        echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$NEW_USER-nopasswd"
        chmod 0440 "/etc/sudoers.d/$NEW_USER-nopasswd"
    fi

    # 3. SSH SETUP FOR NEW USER
    log "Setting up SSH for $NEW_USER with public key..."
    mkdir -p "$NEW_USER_HOME/.ssh"
    echo "$NEW_USER_PUBLIC_KEY" > "$NEW_USER_HOME/.ssh/authorized_keys"
    chmod 700 "$NEW_USER_HOME/.ssh"
    chmod 600 "$NEW_USER_HOME/.ssh/authorized_keys"
    chown -R "$NEW_USER:$NEW_USER" "$NEW_USER_HOME/.ssh"
    log "SSH for $NEW_USER configured with the provided public key."

    # 4. INSTALL DOCKER
    log "Installing Docker..."
    if ! command -v docker &> /dev/null; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update -y
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        log "Docker is already installed."
    fi
    log "Adding user $NEW_USER to docker group..."
    usermod -aG docker "$NEW_USER"

    # 5. INSTALL NGINX
    log "Installing Nginx..."
    if ! command -v nginx &> /dev/null; then
        apt install -y nginx
    else
        log "Nginx is already installed."
    fi

    # 6. INSTALL CERTBOT
    log "Installing Certbot..."
    if ! command -v certbot &> /dev/null; then
        apt install -y certbot python3-certbot-nginx
    else
        log "Certbot is already installed."
    fi

    # 7. CONFIGURE UFW (FIREWALL)
    log "Configuring UFW firewall..."
    ufw allow OpenSSH
    ufw allow 'Nginx Full' # Allows both HTTP (80) and HTTPS (443)
    ufw --force enable

    # 8. VERIFY INSTALLATIONS
    log "Verifying installations..."
    MISSING_PACKAGES=0
    check_command() {
        if command -v $1 &> /dev/null; then log "$1 is installed."; else log "ERROR: $1 is NOT installed."; MISSING_PACKAGES=$((MISSING_PACKAGES + 1)); fi
    }
    check_command docker; check_command nginx; check_command certbot; check_command git; check_command ufw; check_command curl

    if [ $MISSING_PACKAGES -ne 0 ]; then
        log "ERROR: $MISSING_PACKAGES essential command(s) are missing. Please check the log."
    else
        log "All checked commands are available."
    fi

    # 9. CLONE PROJECT REPOSITORY
    log "Cloning project repository $REPO_URL into $REPO_DIR..."
    if [ -d "$REPO_DIR/.git" ]; then
        log "Repository directory $REPO_DIR already exists and appears to be a git repo. Attempting to pull latest changes..."
        su - "$NEW_USER" -c "cd $REPO_DIR && git pull"
    elif [ -d "$REPO_DIR" ]; then
        log "Directory $REPO_DIR exists but is not a git repo. Please remove or rename it."
    else
        su - "$NEW_USER" -c "git clone $REPO_URL $REPO_DIR"
        if [ $? -ne 0 ]; then log "ERROR: Failed to clone repository. Please check URL and permissions."; fi
    fi
    # Ensure correct ownership even if folder existed.
    if [ -d "$REPO_DIR" ]; then
      chown -R "$NEW_USER:$NEW_USER" "$REPO_DIR"
    fi

    # 10. ASK TO RUN DEPLOYMENT SCRIPT
    log "Server setup phase complete."
    if [ -f "$DEPLOY_SCRIPT_PATH" ]; then
        log "Deployment script found at $DEPLOY_SCRIPT_PATH."
        echo # Newline for readability
        read -p "Do you want to run the main deployment script ($DEPLOY_ON_VPS_SCRIPT_NAME) now? (yes/no): " yn
        case $yn in
            [Yy]* )
                log "User chose to run the deployment script."
                log "Executing $DEPLOY_SCRIPT_PATH as user $NEW_USER..."
                if [ ! -x "$DEPLOY_SCRIPT_PATH" ]; then
                    log "Deployment script is not executable. Attempting to make it executable..."
                    chmod +x "$DEPLOY_SCRIPT_PATH"
                fi
                su - "$NEW_USER" -c "$DEPLOY_SCRIPT_PATH" # Script should cd to its own directory if needed
                if [ $? -eq 0 ]; then log "Deployment script executed successfully."; else log "ERROR: Deployment script execution failed. Check logs."; fi
                ;;
            [Nn]* )
                log "User chose not to run the deployment script."
                log "You can run it later manually as user $NEW_USER: cd $REPO_DIR && $DEPLOY_ON_VPS_SCRIPT_NAME"
                ;;
            * ) echo "Invalid input. Skipping deployment script.";;
        esac
    else
        log "WARNING: Deployment script $DEPLOY_SCRIPT_PATH not found. Skipping deployment attempt."
        log "Please ensure the repository is cloned correctly and the script '$DEPLOY_ON_VPS_SCRIPT_NAME' exists at '$REPO_DIR/scripts/'."
    fi

    # 11. Final system state check and enabling services
    log "Starting and enabling services (docker, nginx, ufw)..."
    systemctl enable docker --now
    systemctl enable nginx --now
    # ufw is enabled by 'ufw enable', systemctl enable ufw might not be standard or needed

    log "Initial server setup script finished."
    log "---------------------------------------------------------------------"
    log "IMPORTANT:"
    log "1. Review the log file at $LOG_FILE for any errors."
    log "2. If you haven't already, create the .env file in $REPO_DIR with your secrets (AUTH0_CLIENT_SECRET, DB_PASSWORD etc.) before the application can run correctly."
    log "3. A reboot is recommended to ensure all changes (like user groups for Docker) take full effect: sudo reboot"
    log "4. After reboot, try logging in as '$NEW_USER': ssh $NEW_USER@cloudtolocalllm.online"
    log "---------------------------------------------------------------------"
}

main "$@" 