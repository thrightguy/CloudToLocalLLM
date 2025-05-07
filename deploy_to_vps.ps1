# SSH connection details
$VPS_IP = "162.254.34.115"
$SSH_KEY = Join-Path $PSScriptRoot "cloudadmin_key"

Write-Host "Connecting to VPS..." -ForegroundColor Yellow

# SSH into VPS with key authentication
ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$VPS_IP 