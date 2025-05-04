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

Write-ColorOutput Green "Deploying SSL fix script to $VpsHost..."

# Read the script content
$scriptContent = Get-Content -Path "direct_ssl_fix.sh" -Raw

# Convert CRLF to LF
$scriptContent = $scriptContent -replace "`r`n", "`n"

# Create temporary file with Unix line endings
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $scriptContent -NoNewline -Encoding utf8

# Upload script to server
Write-ColorOutput Yellow "Uploading SSL fix script to VPS..."
scp -i $SshKeyPath $tempFile "${VpsHost}:~/ssl_fix.sh"

# Make executable and run
Write-ColorOutput Yellow "Running SSL fix script..."
ssh -i $SshKeyPath $VpsHost "chmod +x ~/ssl_fix.sh && sudo ~/ssl_fix.sh"

# Clean up
Remove-Item -Force $tempFile

Write-ColorOutput Green "SSL fix script completed!"
Write-ColorOutput Yellow "Your website should now be accessible via HTTPS:"
Write-Host "https://cloudtolocalllm.online"
Write-Host "https://www.cloudtolocalllm.online" 