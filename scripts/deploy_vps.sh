#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check system requirements
check_requirements() {
    echo -e "${YELLOW}Checking system requirements...${NC}"
    
    # Check minimum disk space (20GB free)
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if ! [[ "$FREE_SPACE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Could not determine free disk space.${NC}"
        exit 1
    fi
    if [ "$FREE_SPACE" -lt 20 ]; then
        echo -e "${RED}Error: Insufficient disk space. Need at least 20GB free. Found: ${FREE_SPACE}G${NC}"
        exit 1
    fi
    
    # Check minimum memory (4GB)
    TOTAL_MEM=$(free -g | awk 'NR==2 {print $2}')
    if ! [[ "$TOTAL_MEM" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Could not determine total memory.${NC}"
        exit 1
    fi
    if [ "$TOTAL_MEM" -lt 4 ]; then
        echo -e "${RED}Error: Insufficient memory. Need at least 4GB RAM. Found: ${TOTAL_MEM}G${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}System requirements met.${NC}"
}

# Function to backup existing configuration
backup_config() {
    echo -e "${YELLOW}Backing up existing configuration...${NC}"
    BACKUP_DIR="/var/www/cloudtolocalllm_backup_$(date +%Y%m%d_%H%M%S)"
    if [ -d "/var/www/cloudtolocalllm" ]; then
        sudo cp -r /var/www/cloudtolocalllm $BACKUP_DIR
        echo -e "${GREEN}Backup created at $BACKUP_DIR${NC}"
    fi
}

echo -e "${GREEN}Starting VPS deployment setup...${NC}"

# Check system requirements
check_requirements

# Backup existing configuration
backup_config

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update || { echo -e "${RED}Failed to update package list${NC}"; exit 1; }
sudo apt upgrade -y || { echo -e "${RED}Failed to upgrade packages${NC}"; exit 1; }

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx || {
    echo -e "${RED}Failed to install required packages${NC}"
    exit 1
}

# Start and enable Docker
echo -e "${YELLOW}Configuring Docker...${NC}"
sudo systemctl start docker || { echo -e "${RED}Failed to start Docker${NC}"; exit 1; }
sudo systemctl enable docker || { echo -e "${RED}Failed to enable Docker${NC}"; exit 1; }

# Add current user to docker group
sudo usermod -aG docker $USER

# Deep clean existing setup
echo -e "${YELLOW}Performing deep cleanup...${NC}"
CLEANUP_SCRIPT="/var/www/cloudtolocalllm/scripts/deploy/cleanup_containers.sh"
if [ -f "$CLEANUP_SCRIPT" ]; then
    bash "$CLEANUP_SCRIPT" || {
        echo -e "${RED}Cleanup script failed, attempting basic cleanup...${NC}"
        sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
        sudo docker rm $(sudo docker ps -a -q) 2>/dev/null || true
        sudo docker network prune -f
        sudo docker volume prune -f
        sudo docker builder prune -f
    }
else
    echo -e "${YELLOW}Cleanup script not found, performing basic cleanup...${NC}"
    sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
    sudo docker rm $(sudo docker ps -a -q) 2>/dev/null || true
    sudo docker network prune -f
    sudo docker volume prune -f
    sudo docker builder prune -f
fi

# Create project directory
echo -e "${YELLOW}Setting up project directory...${NC}"
PROJECT_DIR="/var/www/cloudtolocalllm"
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR

# Create Nginx configuration
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
cat << EOF | sudo tee /etc/nginx/sites-available/cloudtolocalllm
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable Nginx site
sudo ln -sf /etc/nginx/sites-available/cloudtolocalllm /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Create Docker Compose file
echo -e "${YELLOW}Creating Docker Compose configuration...${NC}"
cat << EOF > $PROJECT_DIR/docker-compose.yml
version: '3'
services:
  web:
    build: .
    ports:
      - "8080:80"
    restart: always
    environment:
      - NODE_ENV=production
EOF

# Create Dockerfile
echo -e "${YELLOW}Creating Dockerfile...${NC}"
cat << EOF > $PROJECT_DIR/Dockerfile
# Use the official Dart image to build the web app
FROM dart:stable AS build
WORKDIR /app
COPY . .
# RUN dart pub global activate flutter_tools && \\
RUN flutter pub get && \\
    flutter build web --release

# Use a lightweight server image to serve the web app
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# Final system check
echo -e "${YELLOW}Performing final system check...${NC}"
sudo docker info || { echo -e "${RED}Docker is not running properly${NC}"; exit 1; }
nginx -t || { echo -e "${RED}Nginx configuration test failed${NC}"; exit 1; }
systemctl is-active docker || { echo -e "${RED}Docker service is not active${NC}"; exit 1; }
systemctl is-active nginx || { echo -e "${RED}Nginx service is not active${NC}"; exit 1; }

echo -e "${GREEN}VPS setup completed successfully!${NC}"
echo -e "${YELLOW}System Status:${NC}"
echo "Docker Version: $(sudo docker --version)"
echo "Docker Compose Version: $(sudo docker-compose --version)"
echo "Nginx Version: $(nginx -v 2>&1)"
echo "Available Disk Space: $(df -h / | awk 'NR==2 {print $4}')"
echo "Memory Usage: $(free -h | awk 'NR==2 {print "Total: "$2"  Used: "$3"  Free: "$4}')"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Copy your Flutter web app files to $PROJECT_DIR"
echo "2. Run: cd $PROJECT_DIR && docker-compose up -d"
echo "3. To set up SSL, run: sudo certbot --nginx -d your-domain.com"
echo "4. Configure your domain's DNS to point to this VPS's IP address"

# Print instructions for Windows app deployment
echo -e "\n${GREEN}Windows App Deployment Instructions:${NC}"
echo "1. Build the Windows app using: flutter build windows"
echo "2. Package the app using the existing scripts"
echo "3. Upload the release to GitHub" 