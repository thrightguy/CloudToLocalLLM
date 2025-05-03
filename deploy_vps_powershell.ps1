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

Write-ColorOutput Green "Starting deployment to VPS: $VpsHost"

# Check if SSH key exists
if (-not (Test-Path $SshKeyPath)) {
    Write-ColorOutput Red "SSH key not found at $SshKeyPath"
    exit 1
}

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

# Create temporary directory
$tempDir = Join-Path $env:TEMP "cloudtolocalllm_deploy"
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Create CPU-only docker-compose.yml
$dockerComposeContent = @"
version: '3.8'

services:
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
      - "8080:3456"  # Changed from 3456:3456 to use port 8080
networks:
  llm-network:
    driver: bridge
"@

Set-Content -Path "$tempDir\docker-compose.yml" -Value $dockerComposeContent

# Create nginx configuration file
$nginxConfig = @"
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
        autoindex off;
    }

    location /cloud/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
"@

Set-Content -Path "$tempDir\cloudtolocalllm.conf" -Value $nginxConfig

# Create server setup script
$setupScript = @"
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\${YELLOW}Starting VPS setup and configuration...${NC}"

# Update system and install dependencies
sudo apt update
sudo apt install -y docker.io docker-compose nginx curl git

# Configure Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker \$USER

# Copy docker-compose.yml to /var/www/html
sudo mkdir -p /var/www/html
sudo chown -R \$USER:\$USER /var/www/html
cp docker-compose.yml /var/www/html/

# Configure nginx
sudo cp cloudtolocalllm.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# Create test page
cat > /var/www/html/index.html << 'EOF'
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
        <p>If you can see this page, the web server is working correctly.</p>
        <p>To access the cloud application, visit: <a href="/cloud/">/cloud/</a></p>
        <p>Current time: <script>document.write(new Date().toLocaleString());</script></p>
    </div>
</body>
</html>
EOF

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Configure firewall
if command -v ufw &> /dev/null; then
    sudo ufw allow 80/tcp
    sudo ufw allow 8080/tcp
    echo -e "\${GREEN}UFW firewall ports opened${NC}"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo -e "\${GREEN}FirewallD ports opened${NC}"
fi

# Start Docker containers
cd /var/www/html
sudo docker-compose down || true
sudo docker-compose up -d

# Test connection
echo -e "\${YELLOW}Testing local connection...${NC}"
curl -I http://localhost
curl -I http://localhost:8080

echo -e "\${GREEN}Setup completed successfully!${NC}"
echo -e "\${YELLOW}Your site should now be accessible at:${NC}"
echo -e "\${GREEN}http://cloudtolocalllm.online${NC}"
echo -e "\${GREEN}http://cloudtolocalllm.online/cloud/${NC}"
"@

Set-Content -Path "$tempDir\setup.sh" -Value $setupScript -Encoding UTF8

# Upload files to VPS
Write-ColorOutput Yellow "Uploading configuration files to VPS..."
Invoke-ScpCommand "$tempDir\docker-compose.yml" "~/"
Invoke-ScpCommand "$tempDir\cloudtolocalllm.conf" "~/"
Invoke-ScpCommand "$tempDir\setup.sh" "~/"

# Make the setup script executable and run it
Write-ColorOutput Yellow "Running setup script on VPS..."
Invoke-SshCommand "chmod +x setup.sh && ./setup.sh"

# Clean up temporary directory
Remove-Item -Recurse -Force $tempDir

Write-ColorOutput Green "Deployment completed!"
Write-ColorOutput Yellow "Your application should now be accessible at:"
Write-Host "http://cloudtolocalllm.online"
Write-Host "http://cloudtolocalllm.online/cloud/" 