# CloudToLocalLLM - VPS Deployment Script
# This script builds and deploys the web UI to the VPS server

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$VpsConnection,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "~/.ssh/id_rsa",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Display banner
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "CloudToLocalLLM - Web UI Deployment" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Verify SSH connection string format
if (-not ($VpsConnection -match "^[a-zA-Z0-9_\.-]+@[a-zA-Z0-9\.-]+$")) {
    Write-Host "Error: VPS connection should be in the format 'user@hostname'" -ForegroundColor Red
    exit 1
}

# Check if running in Dry Run mode
if ($DryRun) {
    Write-Host "Running in DRY RUN mode. No actual deployment will happen." -ForegroundColor Yellow
}

# Verify the SSH key exists
if (-not (Test-Path $SshKeyPath)) {
    Write-Host "Error: SSH key not found at $SshKeyPath" -ForegroundColor Red
    exit 1
}

# Create a temporary directory for the build
$tempDir = Join-Path $env:TEMP "cloudtolocalllm-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    Write-Host "Preparing web UI files for deployment..." -ForegroundColor Green
    
    # Copy the required files
    if (Test-Path "cloud/web") {
        Copy-Item -Path "cloud/web/*" -Destination $tempDir -Recurse
    } else {
        Write-Host "Error: web directory not found at cloud/web" -ForegroundColor Red
        exit 1
    }
    
    # Copy Docker-related files
    Copy-Item -Path "cloud/Dockerfile" -Destination $tempDir
    Copy-Item -Path "cloud/docker-compose.yml" -Destination $tempDir
    
    # Create deployment script to run on the server using here-string that doesn't expand variables
    $deployScript = @'
#!/bin/bash
set -e

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting web UI deployment...${NC}"

# Create web directory if it doesn't exist
mkdir -p /var/www/html

# Copy web files to the server
cp -r ./* /var/www/html/

# Set proper permissions
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Restart Nginx if it's running
systemctl restart nginx 2>/dev/null || true

echo -e "${GREEN}Web UI deployment completed successfully!${NC}"
echo -e "${YELLOW}Your website should now be available at http://cloudtolocalllm.online${NC}"
'@
    $deployScript | Out-File -FilePath "$tempDir/deploy.sh" -Encoding utf8 -Force
    
    # Convert deploy.sh to Unix line endings and make executable
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $deployScriptContent = Get-Content -Path "$tempDir/deploy.sh" -Raw
        $deployScriptContent = $deployScriptContent -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText("$tempDir/deploy.sh", $deployScriptContent)
    } else {
        # Fallback for older PowerShell versions
        try {
            $null = & cmd /c type "$tempDir\deploy.sh" | cmd /c find /v "" > "$tempDir\deploy_unix.sh"
            Remove-Item -Path "$tempDir\deploy.sh"
            Rename-Item -Path "$tempDir\deploy_unix.sh" -NewName "deploy.sh"
        } catch {
            Write-Host "Warning: Could not convert line endings, but continuing anyway" -ForegroundColor Yellow
        }
    }
    
    if (-not $DryRun) {
        # Use scp to upload files to the server
        Write-Host "Uploading files to VPS..." -ForegroundColor Green
        $uploadCommand = "scp -r -i '$SshKeyPath' '$tempDir\*' '$VpsConnection:/tmp/cloudtolocalllm-deploy'"
        Write-Host "Executing: $uploadCommand" -ForegroundColor Gray
        
        Invoke-Expression "scp -r -i '$SshKeyPath' '$tempDir\*' '$VpsConnection:/tmp/cloudtolocalllm-deploy'"
        
        # Run the deploy script on the server
        Write-Host "Running deployment on VPS..." -ForegroundColor Green
        $sshCommand = "ssh -i '$SshKeyPath' '$VpsConnection' 'mkdir -p /tmp/cloudtolocalllm-deploy && cd /tmp/cloudtolocalllm-deploy && bash deploy.sh'"
        Write-Host "Executing: $sshCommand" -ForegroundColor Gray
        
        Invoke-Expression "ssh -i '$SshKeyPath' '$VpsConnection' 'mkdir -p /tmp/cloudtolocalllm-deploy && cd /tmp/cloudtolocalllm-deploy && bash deploy.sh'"
        
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "DRY RUN: Files prepared for deployment but not uploaded." -ForegroundColor Yellow
        Write-Host "Files would be uploaded to: $VpsConnection:/tmp/cloudtolocalllm-deploy" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: Deployment failed with error: $_" -ForegroundColor Red
    exit 1
} finally {
    # Clean up the temporary directory
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Deployment process completed!" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Note: This was a dry run. No changes were made." -ForegroundColor Yellow
} else {
    Write-Host "Your website is now available at http://cloudtolocalllm.online" -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Cyan 