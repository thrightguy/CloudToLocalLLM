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

Write-ColorOutput Green "Setting up Docker-only environment on $VpsHost..."

# SSH command helper function
function Invoke-SshCommand {
    param ([string]$Command)
    ssh -i $SshKeyPath $VpsHost $Command
}

# SCP command helper function
function Invoke-ScpCommand {
    param ([string]$Source, [string]$Destination)
    scp -i $SshKeyPath $Source "${VpsHost}:$Destination"
}

# Create Docker-only setup script with direct port mapping
$dockerComposeContent = @'
version: '3.8'

services:
  web:
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
    image: certbot/certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  ollama:
    image: ollama/ollama
    networks:
      - llm-network
    volumes:
      - ./check_ollama.sh:/check_ollama.sh
    # Removed GPU requirements
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s
  
  tunnel:
    build:
      context: .
      dockerfile: Dockerfile
    depends_on:
      ollama:
        condition: service_healthy
    networks:
      - llm-network
    volumes:
      - ./lib:/app/lib
      - ./setup_tunnel.sh:/app/setup_tunnel.sh
    command: /bin/bash /app/setup_tunnel.sh
  
  cloud:
    image: node:20
    working_dir: /app
    depends_on:
      tunnel:
        condition: service_started
    networks:
      - llm-network
    volumes:
      - ./cloud:/app
      - ./setup_cloud.sh:/app/setup_cloud.sh
    command: /bin/bash /app/setup_cloud.sh
    ports:
      - "8080:3456"  # Internal port mapping

networks:
  llm-network:
    driver: bridge
'@

# Setup script to remove Nginx and use Docker only
$setupScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up Docker-only environment...${NC}"

# Stop and remove Nginx if installed
echo -e "${YELLOW}Removing Nginx from the system...${NC}"
if command -v nginx &> /dev/null; then
    sudo systemctl stop nginx || true
    sudo systemctl disable nginx || true
    sudo apt-get remove --purge -y nginx nginx-common nginx-full || true
    sudo apt-get autoremove -y
fi

# Setup Docker and Docker Compose
echo -e "${YELLOW}Setting up Docker environment...${NC}"
sudo apt-get update
sudo apt-get install -y docker.io docker-compose curl

# Ensure Docker is running
sudo systemctl start docker
sudo systemctl enable docker

# Create project directory
cd /var/www/html || mkdir -p /var/www/html && cd /var/www/html

# Create directories for Nginx and Certbot
mkdir -p nginx/conf.d nginx/html certbot/conf certbot/www

# Create initial nginx conf
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

    location /cloud/ {
        proxy_pass http://cloud:3456/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create test HTML page
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
        <p>If you can see this page, the Docker setup is working correctly.</p>
        <p>To access the cloud application, visit: <a href="/cloud/">/cloud/</a></p>
        <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
    </div>
</body>
</html>
EOF

# Start containers
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker-compose down || true
docker-compose up -d

# Initialize Let's Encrypt (modify domain as needed)
echo -e "${YELLOW}Initializing Let's Encrypt...${NC}"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "certbot/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "certbot/conf/ssl-dhparams.pem"

# Get SSL certificate
echo -e "${YELLOW}Getting SSL certificate...${NC}"
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot \
    --email admin@cloudtolocalllm.online --agree-tos --no-eff-email \
    -d cloudtolocalllm.online -d www.cloudtolocalllm.online

# Update Nginx configuration to include SSL
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

# Reload Nginx container
echo -e "${YELLOW}Reloading Nginx configuration...${NC}"
docker-compose exec web nginx -s reload

echo -e "${GREEN}Docker-only setup with SSL completed successfully!${NC}"
echo -e "${YELLOW}Your site is now accessible via HTTPS:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}https://www.cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$dockerComposeContent = $dockerComposeContent -replace "`r`n", "`n"
$setupScript = $setupScript -replace "`r`n", "`n"

# Create temporary files
$tempDir = Join-Path $env:TEMP "cloudtolocalllm_docker_only"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

$dockerComposePath = Join-Path $tempDir "docker-compose.yml"
$setupScriptPath = Join-Path $tempDir "docker_only_setup.sh"

Set-Content -Path $dockerComposePath -Value $dockerComposeContent -NoNewline -Encoding utf8
Set-Content -Path $setupScriptPath -Value $setupScript -NoNewline -Encoding utf8

# Upload files to server
Write-ColorOutput Yellow "Uploading files to VPS..."
Invoke-ScpCommand $dockerComposePath "/var/www/html/docker-compose.yml"
Invoke-ScpCommand $setupScriptPath "~/docker_only_setup.sh"

# Fix line endings, make executable, and run
Write-ColorOutput Yellow "Running Docker-only setup script..."
Invoke-SshCommand "sed -i 's/\r$//' ~/docker_only_setup.sh && chmod +x ~/docker_only_setup.sh && ./docker_only_setup.sh"

# Clean up
Remove-Item -Recurse -Force $tempDir

Write-ColorOutput Green "Docker-only setup completed successfully!"
Write-ColorOutput Yellow "Your website is now accessible via HTTPS using Docker only:"
Write-Host "https://cloudtolocalllm.online"
Write-Host "https://www.cloudtolocalllm.online" 