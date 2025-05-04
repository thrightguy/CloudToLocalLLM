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

Write-ColorOutput Green "Deploying Auth0 login updates to $VpsHost..."

# Create a local build
Write-ColorOutput Yellow "Building web app locally..."
$buildResult = Invoke-Expression "flutter build web --release" | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "Failed to build web app locally."
    Write-Host $buildResult
    exit 1
}

# Create a temporary directory for web files
$tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
New-Item -Path $tempDir -ItemType Directory | Out-Null
$webBuildDir = "build/web"

# Copy web build files to temp directory
Write-ColorOutput Yellow "Copying web build files..."
Copy-Item -Path $webBuildDir/* -Destination $tempDir -Recurse

# Create deployment script for the VPS
$deployScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Updating Auth0 login functionality on VPS...${NC}"

# Make sure we're in the deployment directory
cd /opt/cloudtolocalllm

# Update the web files in the Nginx container
echo -e "${YELLOW}Deploying web files to Nginx...${NC}"
# Create a backup of current web files
mkdir -p /opt/cloudtolocalllm/nginx/html/backup_$(date +%Y%m%d%H%M%S)
cp -r /opt/cloudtolocalllm/nginx/html/* /opt/cloudtolocalllm/nginx/html/backup_$(date +%Y%m%d%H%M%S)/ 2>/dev/null || true

# Ensure the directory exists
mkdir -p /opt/cloudtolocalllm/nginx/html

# Clear existing web files
rm -rf /opt/cloudtolocalllm/nginx/html/*

# Copy the new web files from uploaded directory
cp -r /tmp/web_build/* /opt/cloudtolocalllm/nginx/html/

# Update Auth0 client ID in the configuration
echo -e "${YELLOW}Updating Auth0 client ID...${NC}"
AUTH0_CLIENT_ID="your_auth0_client_id"

# Find and update the Auth0 client ID in the JS files
find /opt/cloudtolocalllm/nginx/html -name "*.js" -exec sed -i "s/your_auth0_client_id/$AUTH0_CLIENT_ID/g" {} \;

# Ensure proper permissions
chmod -R 755 /opt/cloudtolocalllm/nginx/html

# Verify Nginx config and restart container
echo -e "${YELLOW}Restarting Nginx container...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart nginx-proxy

echo -e "${GREEN}Auth0 login update deployed successfully!${NC}"
echo -e "${YELLOW}The updated login page is now live at: ${NC}${GREEN}https://cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$deployScript = $deployScript -replace "`r`n", "`n"
$deployScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $deployScriptPath -Value $deployScript -NoNewline -Encoding utf8

# Upload web files and deployment script to the VPS
Write-ColorOutput Yellow "Uploading web files to VPS..."
ssh -i $SshKeyPath $VpsHost "mkdir -p /tmp/web_build"
scp -i $SshKeyPath -r "$tempDir/*" "${VpsHost}:/tmp/web_build/"

Write-ColorOutput Yellow "Uploading and running the deployment script on VPS..."
scp -i $SshKeyPath $deployScriptPath "${VpsHost}:/tmp/deploy_auth0_login.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/deploy_auth0_login.sh && sudo /tmp/deploy_auth0_login.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force -Recurse $tempDir
Remove-Item -Force $deployScriptPath

Write-ColorOutput Green "Auth0 login update deployment complete!"
Write-ColorOutput Yellow "The updated login functionality is now live at:"
Write-Host "https://cloudtolocalllm.online" 