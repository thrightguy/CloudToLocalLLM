param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    
    [Parameter(Mandatory=$false)]
    [string]$Domain = "cloudtolocalllm.online"
)

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Starting SSL setup for $Domain on $VpsHost..."

# SSH command helper function
function Invoke-SshCommand {
    param ([string]$Command)
    ssh -i $SshKeyPath $VpsHost $Command
}

# Create SSL setup script
$sslScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN="cloudtolocalllm.online"
EMAIL="admin@${DOMAIN}"

echo -e "${YELLOW}Setting up SSL for ${DOMAIN}...${NC}"

# Install certbot and nginx plugin
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Ensure nginx is running
sudo systemctl start nginx
sudo systemctl enable nginx

# Obtain SSL certificate
echo -e "${YELLOW}Obtaining SSL certificate...${NC}"
sudo certbot --nginx --non-interactive --agree-tos --email "${EMAIL}" -d "${DOMAIN}" -d "www.${DOMAIN}"

# Test SSL configuration
echo -e "${YELLOW}Testing SSL configuration...${NC}"
sudo nginx -t

# Restart nginx to apply changes
sudo systemctl restart nginx

# Set up auto-renewal
echo -e "${YELLOW}Setting up certificate auto-renewal...${NC}"
sudo systemctl status certbot.timer

echo -e "${GREEN}SSL setup completed successfully!${NC}"
echo -e "${YELLOW}Your site is now accessible via HTTPS:${NC}"
echo -e "${GREEN}https://${DOMAIN}${NC}"
echo -e "${GREEN}https://www.${DOMAIN}${NC}"
'@

# Convert to Unix line endings (LF)
$sslScript = $sslScript -replace "`r`n", "`n"

# Create temporary file
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $sslScript -NoNewline -Encoding utf8

# Upload script to server
Write-ColorOutput Yellow "Uploading SSL setup script to VPS..."
scp -i $SshKeyPath $tempFile "${VpsHost}:~/setup_ssl.sh"

# Fix line endings and make executable
Write-ColorOutput Yellow "Setting up SSL certificates..."
Invoke-SshCommand "sed -i 's/\r$//' ~/setup_ssl.sh && chmod +x ~/setup_ssl.sh && ./setup_ssl.sh"

# Clean up temporary file
Remove-Item -Force $tempFile

Write-ColorOutput Green "SSL setup completed!"
Write-ColorOutput Yellow "Your website is now accessible via HTTPS:"
Write-Host "https://$Domain"
Write-Host "https://www.$Domain" 