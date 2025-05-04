# Setup Beta Environment for CloudToLocalLLM
# This script sets up a beta environment at beta.cloudtolocalllm.online

param (
    [Parameter(Mandatory=$true)]
    [string]$sshConnection  # Format: user@your-vps-ip
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up beta environment at beta.cloudtolocalllm.online..." -ForegroundColor Cyan

# 1. First, copy all files to the server
Write-Host "Preparing web files locally..." -ForegroundColor Green
# Create beta versions of the files if needed
Copy-Item index.html beta_index.html
Copy-Item auth0-callback.html beta_auth0-callback.html
# Copy css directory
if (!(Test-Path -Path "beta_css")) {
    New-Item -ItemType Directory -Path "beta_css"
    Copy-Item -Path "css\*" -Destination "beta_css\" -Recurse
}

Write-Host "Uploading files to server..." -ForegroundColor Green
# Create commands to execute on the server
$remoteCommands = @"
# Create directory for beta site
mkdir -p /opt/cloudtolocalllm/beta_portal

# Update Nginx configuration
cat > /etc/nginx/conf.d/beta.cloudtolocalllm.online.conf << 'EOF'
server {
    listen 80;
    server_name beta.cloudtolocalllm.online;
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name beta.cloudtolocalllm.online;
    
    ssl_certificate /etc/letsencrypt/live/cloudtolocalllm.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloudtolocalllm.online/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    
    root /opt/cloudtolocalllm/beta_portal;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Reload Nginx to apply configuration
systemctl reload nginx

# Issue SSL certificate for beta subdomain if needed
certbot --nginx -d beta.cloudtolocalllm.online --non-interactive --agree-tos --email admin@cloudtolocalllm.online

echo "Beta environment setup complete!"
"@

# Save commands to a temporary file
$remoteCommandsFile = ".\temp_remote_commands.sh"
$remoteCommands | Out-File -FilePath $remoteCommandsFile -Encoding utf8

# Copy files to server
Write-Host "Copying files to server..." -ForegroundColor Green
ssh $sshConnection "mkdir -p /opt/cloudtolocalllm/beta_portal"
scp beta_index.html ${sshConnection}:/opt/cloudtolocalllm/beta_portal/index.html
scp beta_auth0-callback.html ${sshConnection}:/opt/cloudtolocalllm/beta_portal/auth0-callback.html
scp -r beta_css/* ${sshConnection}:/opt/cloudtolocalllm/beta_portal/css/

# Execute remote commands
Write-Host "Configuring Nginx and SSL for beta subdomain..." -ForegroundColor Green
Get-Content $remoteCommandsFile | ssh $sshConnection "bash"

# Clean up
Remove-Item $remoteCommandsFile
Remove-Item beta_index.html
Remove-Item beta_auth0-callback.html
Remove-Item -Recurse -Force beta_css

Write-Host "Beta environment setup completed successfully!" -ForegroundColor Green
Write-Host "The beta site is now available at https://beta.cloudtolocalllm.online" -ForegroundColor Cyan

# Add documentation for beta testing
@"
# Beta Testing Environment

The beta testing environment is now available at: https://beta.cloudtolocalllm.online

## Purpose
- This environment is intended for testing new features before they go live
- The login functionality and container management can be tested here
- User data in the beta environment may be reset or deleted without notice

## Features Being Tested
- Auth0 integration for user authentication
- Container management system
- User-specific environments with end-to-end encryption

## Feedback
Please submit any feedback or issues to our development team.
"@ | Out-File -FilePath "BETA_TESTING.md" -Encoding utf8

Write-Host "Documentation created: BETA_TESTING.md" -ForegroundColor Green 