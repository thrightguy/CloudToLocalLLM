#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting VPS deployment setup...${NC}"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update
sudo apt upgrade -y

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx

# Start and enable Docker
echo -e "${YELLOW}Configuring Docker...${NC}"
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
sudo usermod -aG docker $USER

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
RUN dart pub global activate flutter_tools && \
    flutter pub get && \
    flutter build web --release

# Use a lightweight server image to serve the web app
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

echo -e "${GREEN}VPS setup completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy your Flutter web app files to $PROJECT_DIR"
echo "2. Run: cd $PROJECT_DIR && docker-compose up -d"
echo "3. To set up SSL, run: sudo certbot --nginx -d your-domain.com"
echo "4. Configure your domain's DNS to point to this VPS's IP address"

# Print instructions for Windows app deployment
echo -e "\n${GREEN}Windows App Deployment Instructions:${NC}"
echo "1. Build the Windows app using: flutter build windows"
echo "2. Package the app using the existing scripts"
echo "3. Upload the release to GitHub" 