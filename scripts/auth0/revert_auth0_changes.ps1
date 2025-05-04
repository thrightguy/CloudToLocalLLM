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

Write-ColorOutput Green "Reverting Auth0 login changes on $VpsHost..."

# Create revert script for the VPS
$revertScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Reverting Auth0 login changes...${NC}"

# Make sure we're in the deployment directory
cd /opt/cloudtolocalllm

# Find the most recent backup
echo -e "${YELLOW}Finding most recent backup...${NC}"
LATEST_BACKUP=$(find /opt/cloudtolocalllm/nginx/html/backup_* -type d | sort -r | head -n 1)

if [ -z "$LATEST_BACKUP" ]; then
    echo -e "${RED}No backup found! Unable to revert.${NC}"
    exit 1
fi

echo -e "${GREEN}Found backup: $LATEST_BACKUP${NC}"

# Restore the backup
echo -e "${YELLOW}Restoring backup...${NC}"
rm -rf /opt/cloudtolocalllm/nginx/html/*
cp -r $LATEST_BACKUP/* /opt/cloudtolocalllm/nginx/html/

# Ensure proper permissions
chmod -R 755 /opt/cloudtolocalllm/nginx/html

# Restart Nginx container
echo -e "${YELLOW}Restarting Nginx container...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart nginx-proxy

echo -e "${GREEN}Auth0 login changes reverted successfully!${NC}"
echo -e "${YELLOW}The previous version is now live at: ${NC}${GREEN}https://cloudtolocalllm.online${NC}"
'@

# Convert to Unix line endings (LF)
$revertScript = $revertScript -replace "`r`n", "`n"
$revertScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $revertScriptPath -Value $revertScript -NoNewline -Encoding utf8

# Upload and run the script on the VPS
Write-ColorOutput Yellow "Uploading and running revert script on VPS..."
scp -i $SshKeyPath $revertScriptPath "${VpsHost}:/tmp/revert_auth0_changes.sh"
ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/revert_auth0_changes.sh && sudo /tmp/revert_auth0_changes.sh"

# Clean up
Write-ColorOutput Yellow "Cleaning up temporary files..."
Remove-Item -Force $revertScriptPath

Write-ColorOutput Green "Auth0 login changes have been reverted!"
Write-ColorOutput Yellow "The previous version is now live at:"
Write-Host "https://cloudtolocalllm.online" 