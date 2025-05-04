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

Write-ColorOutput Green "Building and deploying cloud web app to $VpsHost..."

# Build the Flutter web app locally
Write-ColorOutput Yellow "Building Flutter web app locally..."
Push-Location .\cloud
flutter clean
flutter pub get
flutter build web --release
Pop-Location

# Create deployment script
$deployScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting web app deployment...${NC}"

# Create app directory in the web root
echo -e "${YELLOW}Creating app directory...${NC}"
mkdir -p /var/www/html/web
cd /var/www/html

# Extract uploaded files
echo -e "${YELLOW}Extracting uploaded files...${NC}"
rm -rf /var/www/html/web/* 2>/dev/null || true
tar -xzf /tmp/web_app.tar.gz -C /var/www/html/web

# Update Nginx configuration
echo -e "${YELLOW}Updating Nginx configuration...${NC}"
cat > /var/www/html/nginx/default.conf << 'EOF'
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
        root /usr/share/nginx/html/web;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
EOF

# Restart nginx container
echo -e "${YELLOW}Restarting Nginx container...${NC}"
docker-compose restart webserver

echo -e "${GREEN}Web app deployment completed successfully!${NC}"
echo -e "${YELLOW}Your web app should now be accessible at:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$deployScript = $deployScript -replace "`r`n", "`n"
$deployScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $deployScriptPath -Value $deployScript -NoNewline -Encoding utf8

# Create archive of web build
Write-ColorOutput Yellow "Creating archive of web build..."
$archivePath = [System.IO.Path]::GetTempFileName()
Push-Location .\cloud\build\web
tar -czf $archivePath .
Pop-Location

# Upload archive to server
Write-ColorOutput Yellow "Uploading web files to VPS..."
scp -i $SshKeyPath $archivePath "${VpsHost}:/tmp/web_app.tar.gz"

# Upload and run deployment script
Write-ColorOutput Yellow "Running deployment script on VPS..."
scp -i $SshKeyPath $deployScriptPath "${VpsHost}:/tmp/deploy_web.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/deploy_web.sh && sudo /tmp/deploy_web.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $deployScriptPath
Remove-Item -Force $archivePath

Write-ColorOutput Green "Web app deployment completed!"
Write-ColorOutput Yellow "Your web app should now be accessible at:"
Write-Host "https://cloudtolocalllm.online" 