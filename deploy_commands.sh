#!/bin/bash
set -e

# Create deployment directory
mkdir -p /opt/cloudtolocalllm/portal
cd /opt/cloudtolocalllm/portal

# Clone GitHub repository
if [ -d ".git" ]; then
    echo "Pulling latest changes..."
    git pull origin main
else
    echo "Cloning repository..."
    git clone https://github.com/thrightguy/CloudToLocalLLM.git .
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create required directories
mkdir -p certbot/www
mkdir -p certbot/conf

# Make initialization script executable
chmod +x init-ssl.sh

# Stop existing containers
if docker-compose -f docker-compose.web.yml ps &>/dev/null; then
    docker-compose -f docker-compose.web.yml down
fi

# Start services
docker-compose -f docker-compose.web.yml up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Initialize SSL
./init-ssl.sh

echo "Deployment completed!"
echo "The portal should now be accessible at https://cloudtolocalllm.online" 