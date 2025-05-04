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

Write-ColorOutput Green "Fixing npm installation on $VpsHost..."

# Create the fix script
$fixScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Installing Node.js and NPM...${NC}"

# Install Node.js and npm
apt-get update
apt-get install -y nodejs npm

# Verify installation
node -v
npm -v

echo -e "${YELLOW}Installing API dependencies...${NC}"
cd /opt/cloudtolocalllm/data/api
npm install

echo -e "${YELLOW}Installing user manager dependencies...${NC}"
cd /opt/cloudtolocalllm/data/user-manager
npm install

# Restart containers
echo -e "${YELLOW}Restarting containers...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart

echo -e "${GREEN}NPM fix completed!${NC}"
echo -e "${YELLOW}Services should now be fully operational at:${NC}"
echo -e "Main portal: ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "API service: ${GREEN}https://api.cloudtolocalllm.online${NC}"
echo -e "Users portal: ${GREEN}https://users.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Default admin credentials:${NC}"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}admin123${NC}"
'@

# Convert to Unix line endings (LF)
$fixScript = $fixScript -replace "`r`n", "`n"
$fixScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $fixScriptPath -Value $fixScript -NoNewline -Encoding utf8

# Upload and run the fix script
Write-ColorOutput Yellow "Uploading and running fix script on VPS..."
scp -i $SshKeyPath $fixScriptPath "${VpsHost}:/tmp/fix_npm_install.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/fix_npm_install.sh && sudo /tmp/fix_npm_install.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $fixScriptPath

Write-ColorOutput Green "NPM installation fix completed!"
Write-ColorOutput Yellow "Your services are now accessible at:"
Write-Host "Main portal: https://cloudtolocalllm.online"
Write-Host "API service: https://api.cloudtolocalllm.online"
Write-Host "Users portal: https://users.cloudtolocalllm.online"
Write-ColorOutput Yellow "Default admin credentials:"
Write-Host "  Username: admin"
Write-Host "  Password: admin123" 