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

Write-ColorOutput Green "Deploying cloud app to $VpsHost..."

# Create temporary directory for cloud app files
$tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy cloud directory contents to temp directory
Write-ColorOutput Yellow "Preparing cloud app files..."
Copy-Item -Path "cloud/*" -Destination $tempDir -Recurse

# Create deployment script
$deployScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Starting cloud app deployment...${NC}"

# Stop any existing containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker stop cloudtolocalllm-web 2>/dev/null || true
docker rm cloudtolocalllm-web 2>/dev/null || true

# Create app directory in the web root
echo -e "${YELLOW}Creating app directory...${NC}"
mkdir -p /var/www/html/cloud
cd /var/www/html/cloud

# Extract uploaded files
echo -e "${YELLOW}Extracting uploaded files...${NC}"
tar -xzf /tmp/cloud_app.tar.gz -C .

# Build and start Docker container
echo -e "${YELLOW}Building and starting Docker container...${NC}"
docker-compose down || true
docker-compose build --no-cache
docker-compose up -d

# Update Nginx configuration to proxy requests to the cloud app
echo -e "${YELLOW}Updating Nginx configuration...${NC}"

# Create Nginx proxy configuration
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
        proxy_pass http://localhost:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# Restart nginx container
echo -e "${YELLOW}Restarting Nginx container...${NC}"
cd /var/www/html
docker-compose restart webserver

echo -e "${GREEN}Cloud app deployment completed successfully!${NC}"
echo -e "${YELLOW}Your cloud app should now be accessible at:${NC}"
echo -e "${GREEN}https://cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$deployScript = $deployScript -replace "`r`n", "`n"
$deployScriptPath = [System.IO.Path]::Combine($tempDir, "deploy.sh")
Set-Content -Path $deployScriptPath -Value $deployScript -NoNewline -Encoding utf8

# Create archive of cloud files
Write-ColorOutput Yellow "Creating archive of cloud files..."
$archivePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "cloud_app.tar.gz")
Push-Location $tempDir
tar -czf $archivePath .
Pop-Location

# Upload archive to server
Write-ColorOutput Yellow "Uploading cloud files to VPS..."
scp -i $SshKeyPath $archivePath "${VpsHost}:/tmp/cloud_app.tar.gz"

# Upload and run deployment script
Write-ColorOutput Yellow "Running deployment script on VPS..."
scp -i $SshKeyPath $deployScriptPath "${VpsHost}:/tmp/deploy.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/deploy.sh && sudo /tmp/deploy.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Recurse -Force $tempDir
Remove-Item -Force $archivePath

Write-ColorOutput Green "Cloud app deployment completed!"
Write-ColorOutput Yellow "Your cloud app should now be accessible at:"
Write-Host "https://cloudtolocalllm.online" 