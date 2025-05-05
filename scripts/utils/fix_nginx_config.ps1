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

Write-ColorOutput Green "Fixing Nginx configuration on $VpsHost and setting up SSL..."

# SSH command helper function
function Invoke-SshCommand {
    param ([string]$Command)
    ssh -i $SshKeyPath $VpsHost $Command
}

# Create a proper Nginx config
$nginxConfigContent = @'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        autoindex off;
    }

    location /cloud/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
'@

# Get the current Nginx configuration
$nginxConfigPath = "/etc/nginx/sites-enabled/cloudtolocalllm.conf"
$nginxConfigContent = Get-Content -Path $nginxConfigPath -Raw

# Check if the configuration needs to be updated
if ($nginxConfigContent -notmatch "client_max_body_size") {
    Write-Host "Adding client_max_body_size directive..."
    $nginxConfigContent = $nginxConfigContent -replace "http {", "http {`n    client_max_body_size 100M;"
    Set-Content -Path $nginxConfigPath -Value $nginxConfigContent
}

# Fix config and SSL setup script
$setupScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing Nginx configuration...${NC}"

# Backup the old configuration
if [ -f /etc/nginx/sites-enabled/cloudtolocalllm.conf ]; then
    sudo cp /etc/nginx/sites-enabled/cloudtolocalllm.conf /etc/nginx/sites-enabled/cloudtolocalllm.conf.bak
fi

# Write new configuration
sudo tee /etc/nginx/sites-available/cloudtolocalllm.conf > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name cloudtolocalllm.online www.cloudtolocalllm.online;
    
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        autoindex off;
    }

    location /cloud/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create symlink if it doesn't exist
if [ ! -f /etc/nginx/sites-enabled/cloudtolocalllm.conf ]; then
    sudo ln -s /etc/nginx/sites-available/cloudtolocalllm.conf /etc/nginx/sites-enabled/
fi

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Install certbot
echo -e "${YELLOW}Installing Certbot...${NC}"
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Set up SSL
echo -e "${YELLOW}Setting up SSL certificates...${NC}"
sudo certbot --nginx --non-interactive --agree-tos --email admin@cloudtolocalllm.online -d cloudtolocalllm.online -d www.cloudtolocalllm.online

# Test Nginx with SSL
echo -e "${YELLOW}Testing Nginx with SSL configuration...${NC}"
sudo nginx -t

# Restart Nginx with SSL
sudo systemctl restart nginx

echo -e "${GREEN}Nginx configuration fixed and SSL set up successfully!${NC}"
echo -e "${YELLOW}Your site is now accessible via HTTPS:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${GREEN}https://www.cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$setupScript = $setupScript -replace "`r`n", "`n"

# Create temporary file
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $setupScript -NoNewline -Encoding utf8

# Upload script to server
Write-ColorOutput Yellow "Uploading fix script to VPS..."
scp -i $SshKeyPath $tempFile "${VpsHost}:~/fix_nginx_and_ssl.sh"

# Fix line endings, make executable and run
Write-ColorOutput Yellow "Fixing Nginx config and setting up SSL..."
Invoke-SshCommand "sed -i 's/\r$//' ~/fix_nginx_and_ssl.sh && chmod +x ~/fix_nginx_and_ssl.sh && ./fix_nginx_and_ssl.sh"

# Clean up temporary file
Remove-Item -Force $tempFile

Write-ColorOutput Green "Nginx configuration fixed and SSL set up successfully!"
Write-ColorOutput Yellow "Your website is now accessible via HTTPS:"
Write-Host "https://cloudtolocalllm.online"
Write-Host "https://www.cloudtolocalllm.online" 