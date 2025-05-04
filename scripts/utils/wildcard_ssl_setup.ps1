param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    
    [Parameter(Mandatory=$true)]
    [string]$CertificateFilePath,
    
    [Parameter(Mandatory=$true)]
    [string]$PrivateKeyFilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$CaBundle = ""
)

# Colors for better readability
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) { Write-Output $args }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "Setting up wildcard SSL certificate for CloudToLocalLLM on $VpsHost..."

# Verify certificate files exist
if (-not (Test-Path $CertificateFilePath)) {
    Write-ColorOutput Red "Certificate file not found at $CertificateFilePath"
    exit 1
}

if (-not (Test-Path $PrivateKeyFilePath)) {
    Write-ColorOutput Red "Private key file not found at $PrivateKeyFilePath"
    exit 1
}

if ($CaBundle -ne "" -and -not (Test-Path $CaBundle)) {
    Write-ColorOutput Red "CA Bundle file not found at $CaBundle"
    exit 1
}

# Create a temporary directory to prepare the certificate
$tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
New-Item -Path $tempDir -ItemType Directory | Out-Null

try {
    # Copy certificate files to temp directory
    Copy-Item -Path $CertificateFilePath -Destination "$tempDir/certificate.crt"
    Copy-Item -Path $PrivateKeyFilePath -Destination "$tempDir/private.key"
    
    # If CA bundle provided, create a full chain certificate
    if ($CaBundle -ne "") {
        Write-ColorOutput Yellow "Creating fullchain certificate with CA Bundle..."
        Copy-Item -Path $CaBundle -Destination "$tempDir/ca_bundle.crt"
        
        # Combine certificate and CA bundle
        Get-Content "$tempDir/certificate.crt", "$tempDir/ca_bundle.crt" | 
            Set-Content -Path "$tempDir/fullchain.pem" -Encoding utf8
    } else {
        # Just rename the certificate
        Copy-Item -Path "$tempDir/certificate.crt" -Destination "$tempDir/fullchain.pem"
    }
    
    # Rename the private key
    Copy-Item -Path "$tempDir/private.key" -Destination "$tempDir/privkey.pem"
    
    # Create the script to setup wildcard SSL
    $wildcardSslScript = @'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Setting up wildcard SSL certificate...${NC}"

# Create directory for Nginx SSL
mkdir -p /opt/cloudtolocalllm/nginx/ssl

# Copy certificates to Nginx
echo -e "${YELLOW}Installing SSL certificates to Nginx directory...${NC}"
cp /tmp/ssl_certs/fullchain.pem /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
cp /tmp/ssl_certs/privkey.pem /opt/cloudtolocalllm/nginx/ssl/privkey.pem
chmod 644 /opt/cloudtolocalllm/nginx/ssl/fullchain.pem
chmod 600 /opt/cloudtolocalllm/nginx/ssl/privkey.pem

# Backup existing Nginx configuration
echo -e "${YELLOW}Backing up existing Nginx configuration...${NC}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
mkdir -p /opt/cloudtolocalllm/nginx/conf.d/backup_$TIMESTAMP
cp /opt/cloudtolocalllm/nginx/conf.d/*.conf /opt/cloudtolocalllm/nginx/conf.d/backup_$TIMESTAMP/ 2>/dev/null || true

# Update Nginx configuration with wildcard SSL
echo -e "${YELLOW}Updating Nginx configurations to use wildcard SSL...${NC}"

# Check if Nginx container is running
echo -e "${YELLOW}Checking Nginx container status...${NC}"
if [ "$(docker ps -q -f name=nginx-proxy)" ]; then
    echo -e "${GREEN}Nginx container is running.${NC}"
else
    echo -e "${RED}Nginx container is not running! Starting it...${NC}"
    cd /opt/cloudtolocalllm
    docker-compose up -d nginx-proxy
fi

# Restart Nginx container
echo -e "${YELLOW}Restarting Nginx container to apply SSL certificates...${NC}"
cd /opt/cloudtolocalllm
docker-compose restart nginx-proxy

# Check if port 443 is accessible
echo -e "${YELLOW}Checking if port 443 is open...${NC}"
if nc -zv localhost 443 2>/dev/null; then
    echo -e "${GREEN}Port 443 is open.${NC}"
else
    echo -e "${RED}Port 443 is not open! Check Nginx configuration.${NC}"
fi

# Double-check Nginx config
echo -e "${YELLOW}Checking Nginx configuration inside container...${NC}"
docker exec -it nginx-proxy nginx -t || echo -e "${RED}Nginx configuration has errors!${NC}"

echo -e "${GREEN}Wildcard SSL certificate has been installed!${NC}"
echo -e "${GREEN}Your certificate should now cover all subdomains of cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Main portal:${NC} ${GREEN}https://cloudtolocalllm.online${NC}"
echo -e "${YELLOW}API service:${NC} ${GREEN}https://api.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}Users portal:${NC} ${GREEN}https://users.cloudtolocalllm.online${NC}"
echo -e "${YELLOW}User instances:${NC} ${GREEN}https://[username].users.cloudtolocalllm.online${NC}"

# Test the certificates
echo -e "${YELLOW}Testing SSL connection...${NC}"
if command -v curl &>/dev/null; then
    # Check main domain
    echo -e "${YELLOW}Testing main domain...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://cloudtolocalllm.online)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo -e "${GREEN}Main domain HTTPS connection successful!${NC}"
    else
        echo -e "${RED}Main domain HTTPS connection failed with code $HTTP_CODE!${NC}"
    fi
    
    # Check API subdomain
    echo -e "${YELLOW}Testing API subdomain...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://api.cloudtolocalllm.online)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo -e "${GREEN}API subdomain HTTPS connection successful!${NC}"
    else
        echo -e "${RED}API subdomain HTTPS connection failed with code $HTTP_CODE!${NC}"
    fi
    
    # Check users subdomain
    echo -e "${YELLOW}Testing users subdomain...${NC}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 https://users.cloudtolocalllm.online)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo -e "${GREEN}Users subdomain HTTPS connection successful!${NC}"
    else
        echo -e "${RED}Users subdomain HTTPS connection failed with code $HTTP_CODE!${NC}"
    fi
fi

echo -e "${GREEN}Wildcard SSL certificate setup complete!${NC}"
echo -e "${YELLOW}Note: Your certificate will need to be renewed annually - set a reminder!${NC}"
'@

    # Convert to Unix line endings (LF)
    $wildcardSslScript = $wildcardSslScript -replace "`r`n", "`n"
    Set-Content -Path "$tempDir/setup_wildcard_ssl.sh" -Value $wildcardSslScript -NoNewline -Encoding utf8
    
    # Upload certificate files and script to the VPS
    Write-ColorOutput Yellow "Uploading SSL certificate files to VPS..."
    ssh -i $SshKeyPath $VpsHost "mkdir -p /tmp/ssl_certs"
    scp -i $SshKeyPath "$tempDir/fullchain.pem" "${VpsHost}:/tmp/ssl_certs/fullchain.pem"
    scp -i $SshKeyPath "$tempDir/privkey.pem" "${VpsHost}:/tmp/ssl_certs/privkey.pem"
    scp -i $SshKeyPath "$tempDir/setup_wildcard_ssl.sh" "${VpsHost}:/tmp/setup_wildcard_ssl.sh"
    
    # Run the setup script
    Write-ColorOutput Yellow "Running wildcard SSL setup script on VPS..."
    ssh -i $SshKeyPath $VpsHost "chmod +x /tmp/setup_wildcard_ssl.sh && sudo /tmp/setup_wildcard_ssl.sh"
    
    # Clean up temporary files on VPS
    ssh -i $SshKeyPath $VpsHost "sudo rm -rf /tmp/ssl_certs /tmp/setup_wildcard_ssl.sh"
    
    Write-ColorOutput Green "Wildcard SSL certificate installation complete!"
    Write-ColorOutput Yellow "Your SSL certificate should now cover all subdomains of cloudtolocalllm.online"
    Write-Host "Main portal: https://cloudtolocalllm.online"
    Write-Host "API service: https://api.cloudtolocalllm.online" 
    Write-Host "Users portal: https://users.cloudtolocalllm.online"
    Write-Host "User instances: https://[username].users.cloudtolocalllm.online"
    
    Write-ColorOutput Yellow "Remember: Your wildcard SSL certificate will need to be renewed annually."
    Write-ColorOutput Yellow "Consider setting a calendar reminder one month before expiration."
    
} finally {
    # Clean up temporary directory
    if (Test-Path $tempDir) {
        Remove-Item -Recurse -Force $tempDir
    }
} 