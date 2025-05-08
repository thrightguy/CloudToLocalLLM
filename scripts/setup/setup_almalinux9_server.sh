#!/bin/bash

# Script to set up a fresh AlmaLinux 9 server for the CloudToLocalLLM project.
#
# This script will:
# 1. Update the system.
# 2. Install Git and configure global user info.
# 3. Guide through SSH key generation for GitHub.
# 4. Install Docker Engine and Docker Compose plugin.
# 5. Add the current user to the 'docker' group.
# 6. Clone the project repository from GitHub.
# 7. Configure firewalld for HTTP/HTTPS.
#
# IMPORTANT:
# - Run this script as a user with sudo privileges.
# - Some steps, like adding the SSH key to GitHub, require manual intervention.

# --- Configuration ---
DEFAULT_CLONE_DIR="/opt/cloudtolocalllm"
DEFAULT_REPO_SSH_URL="git@github.com:thrightguy/CloudToLocalLLM.git" # Confirm this is your SSH URL

# --- Helper Functions ---
print_info() {
    echo -e "\\033[1;34m[INFO] $1\\033[0m"
}

print_success() {
    echo -e "\\033[1;32m[SUCCESS] $1\\033[0m"
}

print_warning() {
    echo -e "\\033[1;33m[WARNING] $1\\033[0m"
}

print_error() {
    echo -e "\\033[1;31m[ERROR] $1\\033[0m"
}

ask_yes_no() {
    while true; do
        read -p "$1 (yes/no): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# --- Main Script ---

print_info "Starting AlmaLinux 9 server setup for CloudToLocalLLM..."
echo "-----------------------------------------------------------"

# Ensure script is not run as root directly for user-specific configs, but sudo will be used.
if [[ $EUID -eq 0 ]] && [[ -z "$SUDO_USER" ]]; then
   print_warning "This script is best run as a non-root user with sudo privileges. Some user-specific configurations might not apply correctly if run directly as root without sudo."
   if ! ask_yes_no "Continue anyway?"; then
       print_info "Exiting script."
       exit 0
   fi
fi
CURRENT_USER=${SUDO_USER:-$(whoami)} # Get the user who invoked sudo, or current user

# 1. Update System
print_info "Updating system packages..."
if sudo dnf update -y; then
    print_success "System packages updated."
else
    print_error "Failed to update system packages. Please check for errors."
    exit 1
fi
echo "-----------------------------------------------------------"

# 2. Install Git and Configure
print_info "Checking and installing Git..."
if command_exists git; then
    print_success "Git is already installed: $(git --version)"
else
    if sudo dnf install git -y; then
        print_success "Git installed successfully: $(git --version)"
    else
        print_error "Failed to install Git. Please check for errors."
        exit 1
    fi
fi

print_info "Configuring global Git user information..."
read -p "Enter your Git user name (e.g., Your Name): " git_user_name
read -p "Enter your Git user email (e.g., your_email@example.com): " git_user_email

if [[ -n "$git_user_name" ]] && [[ -n "$git_user_email" ]]; then
    git config --global user.name "$git_user_name"
    git config --global user.email "$git_user_email"
    print_success "Git global user name and email configured."
else
    print_warning "Git user name or email not provided. Skipping global Git config."
fi
echo "-----------------------------------------------------------"

# 3. Set Up SSH Keys for GitHub
print_info "Setting up SSH keys for GitHub access..."
SSH_DIR="$HOME/.ssh"
SSH_KEY_PATH="$SSH_DIR/id_ed25519"

if [ -f "$SSH_KEY_PATH" ]; then
    print_info "SSH key already exists at $SSH_KEY_PATH."
    if ! ask_yes_no "Do you want to overwrite it and generate a new one?"; then
        print_info "Skipping SSH key generation. Using existing key."
    else
        NEEDS_KEYGEN=true
    fi
else
    NEEDS_KEYGEN=true
fi

if [ "$NEEDS_KEYGEN" = true ]; then
    print_info "Generating a new SSH key..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    read -p "Enter the email address associated with your GitHub account: " github_email
    if [[ -z "$github_email" ]]; then
        print_error "GitHub email cannot be empty. Skipping SSH key generation."
    else
        ssh-keygen -t ed25519 -C "$github_email" -f "$SSH_KEY_PATH" # No passphrase for simplicity in script
        if [ $? -eq 0 ]; then
            print_success "New SSH key pair generated at $SSH_KEY_PATH"
        else
            print_error "SSH key generation failed."
        fi
    fi
fi

if [ -f "$SSH_KEY_PATH.pub" ]; then
    print_info "Your SSH public key is:"
    echo "---------------------------------------------------------------------"
    cat "$SSH_KEY_PATH.pub"
    echo "---------------------------------------------------------------------"
    print_info "Please copy the ENTIRE public key above and add it to your GitHub account:"
    echo "1. Go to GitHub > Settings > SSH and GPG keys > New SSH key."
    echo "2. Paste the key and give it a title (e.g., AlmaLinux9-Server)."
    if ask_yes_no "Have you added the public key to GitHub and are ready to test the connection?"; then
        print_info "Attempting to start ssh-agent and add the key..."
        eval \"\$(ssh-agent -s)\"
        ssh-add "$SSH_KEY_PATH"
        print_info "Testing SSH connection to GitHub..."
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            print_success "SSH connection to GitHub successful!"
        else
            print_warning "SSH connection to GitHub failed or message not as expected. You may need to troubleshoot manually."
            print_warning "Make sure the key is added to GitHub and the ssh-agent has the private key."
        fi
    else
        print_warning "Skipping GitHub SSH connection test. Please complete it manually later."
    fi
else
    print_warning "SSH public key not found. Cannot proceed with GitHub SSH setup."
fi
echo "-----------------------------------------------------------"

# 4. Install Docker Engine and Docker Compose Plugin
print_info "Checking and installing Docker..."
if command_exists docker; then
    print_success "Docker is already installed: $(docker --version)"
else
    print_info "Installing Docker Engine and plugins..."
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    if sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y; then
        print_success "Docker Engine installed successfully."
        print_info "Starting and enabling Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
        if systemctl is-active --quiet docker; then
            print_success "Docker service is active and enabled."
        else
            print_error "Docker service failed to start or enable."
        fi
    else
        print_error "Failed to install Docker Engine. Please check for errors."
        exit 1
    fi
fi

# Verify docker compose command (with space)
if command_exists docker && docker compose version > /dev/null 2>&1; then
    print_success "Docker Compose plugin is available: $(docker compose version)"
else
    print_warning "Docker Compose plugin (docker compose) not found or not working. You might need to install it manually or troubleshoot."
fi
echo "-----------------------------------------------------------"

# 5. Add User to Docker Group
print_info "Configuring Docker group for current user ($CURRENT_USER)..."
if getent group docker > /dev/null; then
    print_info "'docker' group already exists."
else
    if sudo groupadd docker; then
        print_success "'docker' group created."
    else
        print_error "Failed to create 'docker' group."
    fi
fi

if id -nG "$CURRENT_USER" | grep -qw "docker"; then
    print_success "User $CURRENT_USER is already in the 'docker' group."
else
    if sudo usermod -aG docker "$CURRENT_USER"; then
        print_success "User $CURRENT_USER added to the 'docker' group."
        print_warning "You need to log out and log back in for this group change to take full effect!"
    else
        print_error "Failed to add user $CURRENT_USER to the 'docker' group."
    fi
fi
echo "-----------------------------------------------------------"

# 6. Clone Project Repository
print_info "Cloning the project repository..."
read -e -p "Enter the SSH URL of your GitHub repository: " -i "$DEFAULT_REPO_SSH_URL" REPO_URL
read -e -p "Enter the local directory to clone into: " -i "$DEFAULT_CLONE_DIR" CLONE_DIR

if [[ -z "$REPO_URL" ]] || [[ -z "$CLONE_DIR" ]]; then
    print_error "Repository URL or clone directory cannot be empty. Skipping clone."
else
    if [ -d "$CLONE_DIR" ]; then
        print_warning "Directory $CLONE_DIR already exists."
        if ask_yes_no "Do you want to remove it and re-clone?"; then
            sudo rm -rf "$CLONE_DIR"
            print_info "Existing directory removed."
        else
            print_info "Skipping clone. Using existing directory."
            REPO_EXISTS=true
        fi
    fi

    if [ "$REPO_EXISTS" != true ]; then
        # Ensure parent directory exists and user has permissions or use sudo for /opt
        PARENT_DIR=$(dirname "$CLONE_DIR")
        if [ ! -d "$PARENT_DIR" ]; then
            sudo mkdir -p "$PARENT_DIR"
            sudo chown "$CURRENT_USER:$CURRENT_USER" "$PARENT_DIR" # Or appropriate permissions
            print_info "Created parent directory $PARENT_DIR"
        fi
         # If cloning into /opt or other system dirs, might need sudo for the clone itself,
         # or ensure user has write perms to the parent. For simplicity, try without sudo first if user owns parent.
        print_info "Cloning $REPO_URL into $CLONE_DIR..."
        if git clone "$REPO_URL" "$CLONE_DIR"; then
            print_success "Repository cloned successfully into $CLONE_DIR."
            # Adjust ownership if cloned into a system directory like /opt
            if [[ "$CLONE_DIR" == /opt/* ]]; then
                sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$CLONE_DIR"
                print_info "Ownership of $CLONE_DIR set to $CURRENT_USER."
            fi
        else
            print_error "Failed to clone repository. Check SSH key setup with GitHub and repository URL."
        fi
    fi
fi
echo "-----------------------------------------------------------"

# 7. Configure Firewall (firewalld)
print_info "Configuring firewall (firewalld)..."
if command_exists firewall-cmd; then
    if sudo systemctl is-active --quiet firewalld; then
        print_info "firewalld is active."
        SERVICES_TO_ADD=("http" "https")
        for service in "${SERVICES_TO_ADD[@]}"; do
            if sudo firewall-cmd --permanent --query-service="$service" > /dev/null 2>&1; then
                print_success "Firewall rule for $service already exists."
            else
                if sudo firewall-cmd --permanent --add-service="$service"; then
                    print_success "Firewall rule added for $service."
                else
                    print_error "Failed to add firewall rule for $service."
                fi
            fi
        done
        print_info "Reloading firewall rules..."
        if sudo firewall-cmd --reload; then
            print_success "Firewall rules reloaded."
            print_info "Current firewall rules (public zone):"
            sudo firewall-cmd --list-all
        else
            print_error "Failed to reload firewall rules."
        fi
    else
        print_warning "firewalld service is not active. Skipping firewall configuration."
        print_warning "Consider starting and enabling it: sudo systemctl start firewalld && sudo systemctl enable firewalld"
    fi
else
    print_warning "firewall-cmd not found. Cannot configure firewall. Please install and configure firewalld or your preferred firewall manually."
fi
echo "-----------------------------------------------------------"

print_success "AlmaLinux 9 server setup script finished!"
print_info "Next steps:"
if [ -d "$CLONE_DIR" ]; then
  print_info "1. If you were added to the 'docker' group, log out and log back in."
  print_info "2. Navigate to your project directory: cd $CLONE_DIR"
  print_info "3. Review your docker-compose.yml and other project configurations."
  print_info "4. Start your application using: docker compose up --build -d (or similar)"
else
  print_info "1. Ensure your repository is cloned correctly and troubleshoot any errors from the script."
fi
print_info "Good luck!" 