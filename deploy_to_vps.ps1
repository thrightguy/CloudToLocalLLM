param (
    [Parameter(Mandatory=$true)]
    [string]$VpsIp,
    
    [Parameter(Mandatory=$true)]
    [string]$VpsUser,
    
    [Parameter()]
    [string]$SshPort = "22",
    
    [Parameter()]
    [switch]$InstallDocker = $true,
    
    [Parameter(Mandatory=$true)]
    [string]$IdentityFile = "$env:USERPROFILE\.ssh\id_rsa"
)

# CloudToLocalLLM VPS Deployment Script (PowerShell version)
# This script deploys the CloudToLocalLLM cloud component with a landing page to a VPS

# Output colors with better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# SSH Command helper function - always use identity file
function Invoke-SshCommand($Command) {
    return ssh -p $SshPort -i $IdentityFile "${VpsUser}@${VpsIp}" $Command
}

# SCP Command helper function - always use identity file
function Invoke-ScpCommand($Source, $Destination) {
    return scp -P $SshPort -i $IdentityFile $Source $Destination
}

Write-ColorOutput Green "Starting deployment to VPS (${VpsIp})..."

# Check if SSH key exists
if (-not (Test-Path $IdentityFile)) {
    Write-ColorOutput Red "SSH key not found at $IdentityFile"
    Write-Host "SSH key authentication is mandatory for deployment."
    $createKey = Read-Host "Would you like to create an SSH key pair now? (y/n)"
    
    if ($createKey -eq "y" -or $createKey -eq "Y") {
        Write-ColorOutput Yellow "Creating SSH key pair..."
        
        # Create .ssh directory if it doesn't exist
        if (-not (Test-Path "$env:USERPROFILE\.ssh")) {
            New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" | Out-Null
        }
        
        # Generate SSH key
        ssh-keygen -t rsa -b 4096 -f $IdentityFile -N '""'
        
        Write-ColorOutput Yellow "SSH key created. You must copy the public key to your server before continuing."
        Write-Host "Run this command manually to copy your key:"
        Write-Host "ssh-copy-id -i $IdentityFile ${VpsUser}@${VpsIp} -p $SshPort"
        
        # If ssh-copy-id is not available on Windows, provide alternative instructions
        Write-Host "Or copy this key manually to the server's ~/.ssh/authorized_keys file:"
        $publicKey = Get-Content "$IdentityFile.pub"
        Write-Host $publicKey
        
        $confirmed = Read-Host "Have you copied the key to the server? (y/n)"
        if ($confirmed -ne "y" -and $confirmed -ne "Y") {
            Write-ColorOutput Red "Deployment aborted. Please copy the SSH key to the server before running the script again."
            exit 1
        }
    } else {
        Write-ColorOutput Red "SSH key is required for deployment. Please create an SSH key or specify an existing one with -IdentityFile."
        exit 1
    }
}

# Verify SSH connection works
Write-ColorOutput Yellow "Verifying SSH connection..."
try {
    $testResult = Invoke-SshCommand "echo 'SSH connection successful'"
    if ($testResult -ne "SSH connection successful") {
        throw "SSH key authentication failed"
    }
    Write-ColorOutput Green "SSH connection verified successfully."
}
catch {
    Write-ColorOutput Red "Error connecting to VPS with the specified SSH key."
    Write-Host "Make sure the key is added to the server's authorized_keys file."
    Write-Host "Error details: $_"
    exit 1
}

# Create temporary directory
Write-ColorOutput Yellow "Preparing files for deployment..."
$TempDir = Join-Path $env:TEMP "cloudtolocalllm_deploy_$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TempDir "deploy") | Out-Null

# Copy web files from cloud directory
Copy-Item -Path "cloud\web\*" -Destination (Join-Path $TempDir "deploy") -Recurse

# Create nginx config file and docker configuration files
Write-ColorOutput Yellow "Creating configuration files..."

# Create setup script for Docker installation
$DockerSetupScript = @'
#!/bin/bash
set -e

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    # Update package lists
    apt-get update
    
    # Install prerequisites
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    
    # Add Docker repository - detect OS automatically
    if [ -f /etc/lsb-release ]; then
        # For Ubuntu
        . /etc/lsb-release
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $DISTRIB_CODENAME stable"
    elif [ -f /etc/debian_version ]; then
        # For Debian
        DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
        if [ "$DEBIAN_VERSION" = "10" ]; then
            CODENAME="buster"
        elif [ "$DEBIAN_VERSION" = "11" ]; then
            CODENAME="bullseye"
        else
            CODENAME="bookworm"  # Default to the latest
        fi
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $CODENAME stable"
    else
        echo "Unsupported OS. Please install Docker manually."
        exit 1
    fi
    
    # Install Docker CE
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Enable and start Docker service
    systemctl enable docker
    systemctl start docker
    
    echo "Docker installed successfully!"
else
    echo "Docker is already installed."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing Docker Compose..."
    
    # Install Docker Compose
    DOCKER_COMPOSE_VERSION="2.23.3"
    OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH_TYPE=$(uname -m)
    
    # Map architecture names
    if [ "$ARCH_TYPE" = "x86_64" ]; then
        ARCH_TYPE="x86_64"
    elif [ "$ARCH_TYPE" = "aarch64" ]; then
        ARCH_TYPE="aarch64"
    else
        echo "Unsupported architecture: $ARCH_TYPE"
        exit 1
    fi
    
    curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-${OS_TYPE}-${ARCH_TYPE}" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symbolic link
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    echo "Docker Compose installed successfully!"
else
    echo "Docker Compose is already installed."
fi

# Make sure Docker configuration directory exists
mkdir -p /etc/docker

# Configure Docker to use BuildKit
echo '{
  "features": {
    "buildkit": true
  }
}' > /etc/docker/daemon.json

# Restart Docker to apply changes
systemctl restart docker

echo "Docker setup completed successfully!"
'@
Set-Content -Path (Join-Path $TempDir "setup_docker.sh") -Value $DockerSetupScript

# Create nginx.conf
$NginxConfContent = @"
server {
    listen 80;
    server_name _;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files `$uri `$uri/ /index.html;
    }
    
    # Redirect server error pages to static page
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
"@
Set-Content -Path (Join-Path $TempDir "nginx.conf") -Value $NginxConfContent

# Create a simple Dockerfile that doesn't require building
$DockerfileContent = @"
FROM nginx:alpine
COPY ./deploy /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
"@
Set-Content -Path (Join-Path $TempDir "Dockerfile") -Value $DockerfileContent

# Create docker-compose.yml
$DockerComposeContent = @"
version: '3'
services:
  cloudtolocalllm:
    container_name: cloudtolocalllm
    image: nginx:alpine
    ports:
      - "80:80"
    restart: always
    volumes:
      - ./deploy:/usr/share/nginx/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
"@
Set-Content -Path (Join-Path $TempDir "docker-compose.yml") -Value $DockerComposeContent

# SSH into the VPS and prepare the environment
Write-ColorOutput Yellow "Preparing VPS environment..."
try {
    Invoke-SshCommand "mkdir -p /var/www/cloudtolocalllm"
}
catch {
    Write-ColorOutput Red "Error connecting to VPS. Please check your SSH key and permissions."
    Write-Host "Error details: $_"
    Remove-Item -Path $TempDir -Recurse -Force
    exit 1
}

# Copy files to VPS
Write-ColorOutput Yellow "Uploading files to VPS..."
try {
    Invoke-ScpCommand -Source (Join-Path $TempDir "*") -Destination "${VpsUser}@${VpsIp}:/var/www/cloudtolocalllm/"
}
catch {
    Write-ColorOutput Red "Error uploading files to VPS. Please check your SSH key and permissions."
    Write-Host "Error details: $_"
    Remove-Item -Path $TempDir -Recurse -Force
    exit 1
}

# Install Docker if the InstallDocker switch is set
if ($InstallDocker) {
    Write-ColorOutput Yellow "Setting up Docker on VPS (this may take a few minutes)..."
    try {
        $dockerSetupResult = Invoke-SshCommand "cd /var/www/cloudtolocalllm && chmod +x setup_docker.sh && sudo ./setup_docker.sh"
        Write-Host $dockerSetupResult
    }
    catch {
        Write-ColorOutput Red "Error during Docker setup!"
        Write-Host "Error details: $_"
        Remove-Item -Path $TempDir -Recurse -Force
        exit 1
    }
}

# Deploy on VPS
Write-ColorOutput Yellow "Deploying application on VPS..."
try {
    $deployResult = Invoke-SshCommand @"
cd /var/www/cloudtolocalllm && 
sudo docker-compose down 2>/dev/null || true && 
sudo docker-compose up -d
"@
    Write-Host $deployResult
}
catch {
    Write-ColorOutput Red "Error during deployment!"
    Write-Host "Error details: $_"
    Remove-Item -Path $TempDir -Recurse -Force
    exit 1
}

# Cleanup temporary files
Remove-Item -Path $TempDir -Recurse -Force

Write-ColorOutput Green "Deployment completed successfully!"
Write-Host "Your landing page should be available at: http://$VpsIp/"
Write-Host ""
Write-ColorOutput Yellow "Next steps:"
Write-Host "1. Configure your domain (if you have one) to point to this IP"
Write-Host "2. Set up SSL with: sudo certbot --nginx -d yourdomain.com" 