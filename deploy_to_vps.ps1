param (
    [Parameter(Mandatory=$true)]
    [string]$VpsIp,
    
    [Parameter(Mandatory=$true)]
    [string]$VpsUser = "root",
    
    [string]$SshPort = "22"
)

Write-Host "Starting deployment to VPS ($VpsIp)..." -ForegroundColor Cyan

# Build the Flutter web app
Write-Host "Building Flutter web app..." -ForegroundColor Cyan
Set-Location $flutterAppPath
flutter build web --web-renderer canvaskit --base-href "/$(${env:APP_SUBFOLDER})/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error building Flutter web app" -ForegroundColor Red
    exit 1
}
Set-Location $PSScriptRoot

# Copy build files to Nginx directory
Write-Host "Copying build files to Nginx..." -ForegroundColor Cyan
$nginxWebRoot = "/var/www/${env:APP_SUBFOLDER}"
$sshCommand = "ssh $VpsUser@$VpsIp 'sudo rm -rf $nginxWebRoot/* && sudo mkdir -p $nginxWebRoot'"
Write-Host "Executing: $sshCommand"
Invoke-Expression $sshCommand
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error cleaning Nginx directory on VPS" -ForegroundColor Red
    exit 1
}

$scpCommand = "scp -r .\cloud\build\web\* ${VpsUser}@${VpsIp}:${nginxWebRoot}/"
Write-Host "Executing: $scpCommand"
Invoke-Expression $scpCommand
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error copying build files to VPS" -ForegroundColor Red
    exit 1
}

# Set permissions
$sshCommand = "ssh $VpsUser@$VpsIp 'sudo chown -R www-data:www-data $nginxWebRoot && sudo chmod -R 755 $nginxWebRoot'"

# Copy Docker and Nginx configuration
Write-Host "Copying deployment configuration..." -ForegroundColor Yellow
scp -P $SshPort Dockerfile "${VpsUser}@${VpsIp}:/var/www/cloudtolocalllm/"
scp -P $SshPort docker-compose.yml "${VpsUser}@${VpsIp}:/var/www/cloudtolocalllm/"

# Deploy the app
Write-Host "Deploying app on VPS..." -ForegroundColor Yellow
ssh -p $SshPort "$VpsUser@$VpsIp" "cd /var/www/cloudtolocalllm && docker-compose down && docker-compose up -d"

if ($?) {
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Your app should be available at: http://$VpsIp/" -ForegroundColor Cyan
} else {
    Write-Host "Error deploying app!" -ForegroundColor Red
    exit 1
}

Write-Host "To set up SSL, run the following on your VPS:" -ForegroundColor Yellow
Write-Host "certbot --nginx -d your-domain.com" -ForegroundColor White 