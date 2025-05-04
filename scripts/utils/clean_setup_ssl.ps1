param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Complete Docker cleanup and SSL setup on $VpsHost..."

# SSH command helper function
function Invoke-SshCommand {
    param ([string]$Command)
    ssh -i $SshKeyPath $VpsHost $Command
}

# Create cleanup and SSL setup script
$cleanupScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting complete cleanup and SSL setup...${NC}"

# Kill all Docker containers regardless of state
echo -e "${YELLOW}Stopping all Docker containers...${NC}"
docker kill $(docker ps -q) 2>/dev/null || true

# Remove all containers
echo -e "${YELLOW}Removing all Docker containers...${NC}"
docker rm -f $(docker ps -a -q) 2>/dev/null || true

# Remove all Docker networks
echo -e "${YELLOW}Removing all Docker networks...${NC}"
docker network rm $(docker network ls -q) 2>/dev/null || true

# Remove all Docker images (optional, commented out for safety)
# echo -e "${YELLOW}Removing all Docker images...${NC}"
# docker rmi -f $(docker images -q) 2>/dev/null || true

# Clean up Docker system
echo -e "${YELLOW}Cleaning up Docker system...${NC}"
docker system prune -af --volumes

# Ensure project directory exists with clean structure
echo -e "${YELLOW}Creating clean project structure...${NC}"
rm -rf /var/www/html
mkdir -p /var/www/html
cd /var/www/html

# Create simple Docker Compose file with only web server
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  webserver:
    container_name: webserver
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./web:/usr/share/nginx/html
      - ./nginx:/etc/nginx/conf.d
      - ./ssl:/etc/nginx/ssl
EOF

# Create directories
mkdir -p web nginx ssl

# Create a simple index.html
cat > web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudToLocalLLM</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            color: #0066cc;
        }
        .container {
            border: 1px solid #ddd;
            padding: 20px;
            border-radius: 5px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <h1>CloudToLocalLLM</h1>
    <div class="container">
        <h2>Welcome to CloudToLocalLLM</h2>
        <p>If you can see this page, the web server is working correctly.</p>
        <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
    </div>
</body>
</html>
EOF

# Create nginx config for HTTP first
cat > nginx/default.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

# Start the web server
echo -e "${YELLOW}Starting web server...${NC}"
docker-compose up -d

# Wait for the web server to start
echo -e "${YELLOW}Waiting for web server to start...${NC}"
sleep 5

# Test if the web server is running
echo -e "${YELLOW}Testing web server...${NC}"
curl -I http://localhost

# Install Certbot standalone for SSL
echo -e "${YELLOW}Installing Certbot...${NC}"
apt-get update
apt-get install -y certbot

# Stop the web server to free port 80 for certbot
echo -e "${YELLOW}Stopping web server for Certbot...${NC}"
docker-compose down

# Get SSL certificate using standalone mode
echo -e "${YELLOW}Getting SSL certificate with Certbot standalone...${NC}"
certbot certonly --standalone --non-interactive --agree-tos --email admin@cloudtolocalllm.online \
  -d cloudtolocalllm.online -d www.cloudtolocalllm.online

# Check if certificate was created
if [ ! -d "/etc/letsencrypt/live/cloudtolocalllm.online" ]; then
    echo -e "${RED}Failed to obtain SSL certificate. Check errors above.${NC}"
    exit 1
fi

# Copy certificates to nginx ssl directory
echo -e "${YELLOW}Copying SSL certificates...${NC}"
cp /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem /var/www/html/ssl/fullchain.pem
cp /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem /var/www/html/ssl/privkey.pem

# Create nginx config for HTTPS
cat > nginx/default.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

# Restart the web server with SSL
echo -e "${YELLOW}Starting web server with SSL...${NC}"
docker-compose up -d

# Create a certbot renewal hook
echo -e "${YELLOW}Creating Certbot renewal hook...${NC}"
mkdir -p /etc/letsencrypt/renewal-hooks/post
cat > /etc/letsencrypt/renewal-hooks/post/copy-certs.sh << 'EOF'
#!/bin/bash
cp /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem /var/www/html/ssl/fullchain.pem
cp /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem /var/www/html/ssl/privkey.pem
docker exec webserver nginx -s reload
EOF
chmod +x /etc/letsencrypt/renewal-hooks/post/copy-certs.sh

# Create a cronjob for certbot renewal
echo -e "${YELLOW}Setting up automatic certificate renewal...${NC}"
(crontab -l 2>/dev/null || echo "") | grep -v certbot | { cat; echo "0 3 * * * certbot renew --quiet"; } | crontab -

echo -e "${GREEN}SSL setup completed successfully!${NC}"
echo -e "${YELLOW}Your website is now accessible via HTTPS:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}https://www.cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$cleanupScript = $cleanupScript -replace "`r`n", "`n"

# Create temporary file
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $cleanupScript -NoNewline -Encoding utf8

# Upload script to server
Write-ColorOutput Yellow "Uploading cleanup script to VPS..."
scp -i $SshKeyPath $tempFile "${VpsHost}:~/clean_setup_ssl.sh"

# Fix line endings, make executable, and run
Write-ColorOutput Yellow "Running cleanup and SSL setup script..."
Invoke-SshCommand "sed -i 's/\r$//' ~/clean_setup_ssl.sh && chmod +x ~/clean_setup_ssl.sh && ./clean_setup_ssl.sh"

# Clean up
Remove-Item -Force $tempFile

Write-ColorOutput Green "Cleanup and SSL setup completed!"
Write-ColorOutput Yellow "Your website should now be accessible via HTTPS:"
Write-Host "https://cloudtolocalllm.online"
Write-Host "https://www.cloudtolocalllm.online" 