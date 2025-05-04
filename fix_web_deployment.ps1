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

Write-ColorOutput Green "Fixing web deployment on $VpsHost..."

# SSH command helper function
function Invoke-SshCommand {
    param ([string]$Command)
    ssh -i $SshKeyPath $VpsHost $Command
}

# Create fix script
$fixScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing web deployment...${NC}"

# Go to the project directory
cd /var/www/html

# Clean up orphaned containers
echo -e "${YELLOW}Cleaning up orphaned containers...${NC}"
docker-compose down --remove-orphans
docker rm -f $(docker ps -a -q) || true

# Clean up Docker networks
echo -e "${YELLOW}Cleaning up Docker networks...${NC}"
docker network prune -f

# Stop any running containers using ports 80/443
echo -e "${YELLOW}Ensuring ports 80 and 443 are free...${NC}"
docker ps | grep -E '80|443' | awk '{print $1}' | xargs docker rm -f || true

# Fix Docker Compose file with proper container names
echo -e "${YELLOW}Updating Docker Compose configuration...${NC}"
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    container_name: web
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/html:/usr/share/nginx/html
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    command: "/bin/sh -c 'while :; do sleep 6h & wait $${!}; nginx -s reload; done & nginx -g \"daemon off;\"'"
  
  certbot:
    container_name: certbot
    image: certbot/certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  # Cloud service only
  cloud:
    container_name: cloud
    image: node:20
    working_dir: /app
    volumes:
      - ./cloud:/app
      - ./setup_cloud.sh:/app/setup_cloud.sh
    command: "sh -c 'cd /app && npm install && npm start'"
    ports:
      - "8080:3456"
EOF

# Update Nginx configuration for certificate validation
echo -e "${YELLOW}Updating Nginx configuration...${NC}"
mkdir -p nginx/conf.d nginx/html certbot/conf certbot/www

cat > nginx/conf.d/app.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

# Start Nginx for certificate validation
echo -e "${YELLOW}Starting Nginx for certificate validation...${NC}"
docker-compose up -d web

# Initialize Let's Encrypt files
echo -e "${YELLOW}Initializing Let's Encrypt...${NC}"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "certbot/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "certbot/conf/ssl-dhparams.pem"

# Wait for Nginx to start
echo -e "${YELLOW}Waiting for Nginx to start...${NC}"
sleep 5

# Get SSL certificate (with force renewal)
echo -e "${YELLOW}Getting SSL certificate...${NC}"
docker-compose run --rm certbot certonly --webroot --force-renewal -w /var/www/certbot \
    --email admin@cloudtolocalllm.online --agree-tos --no-eff-email \
    -d cloudtolocalllm.online -d www.cloudtolocalllm.online

# Check if certificate was obtained successfully
if [ ! -f "certbot/conf/live/cloudtolocalllm.online/fullchain.pem" ]; then
    echo -e "${RED}Certificate was not obtained. Check errors above.${NC}"
    exit 1
fi

# Update Nginx configuration with SSL
echo -e "${YELLOW}Updating Nginx configuration for SSL...${NC}"
cat > nginx/conf.d/app.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    server_tokens off;

    ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /cloud/ {
        proxy_pass http://cloud:3456/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create a basic index page
echo -e "${YELLOW}Creating HTML landing page...${NC}"
cat > nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CloudToLocalLLM</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
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
        <p>If you can see this page, the SSL setup is working correctly.</p>
        <p>To access the cloud application, visit: <a href="/cloud/">/cloud/</a></p>
        <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
    </div>
</body>
</html>
EOF

# Restart all containers
echo -e "${YELLOW}Restarting all containers...${NC}"
docker-compose up -d

# Test the SSL setup
echo -e "${YELLOW}Testing SSL configuration...${NC}"
curl -k -I https://localhost

echo -e "${GREEN}Web deployment fix completed!${NC}"
echo -e "${YELLOW}Your site should now be accessible via HTTPS:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}https://www.cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$fixScript = $fixScript -replace "`r`n", "`n"

# Create temporary file
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $fixScript -NoNewline -Encoding utf8

# Upload script to server
Write-ColorOutput Yellow "Uploading fix script to VPS..."
scp -i $SshKeyPath $tempFile "${VpsHost}:~/fix_web_deployment.sh"

# Fix line endings, make executable, and run
Write-ColorOutput Yellow "Running fix script..."
Invoke-SshCommand "sed -i 's/\r$//' ~/fix_web_deployment.sh && chmod +x ~/fix_web_deployment.sh && ./fix_web_deployment.sh"

# Clean up
Remove-Item -Force $tempFile

Write-ColorOutput Green "Web deployment fix completed!"
Write-ColorOutput Yellow "Your website should now be accessible via HTTPS:"
Write-Host "https://cloudtolocalllm.online"
Write-Host "https://www.cloudtolocalllm.online" 