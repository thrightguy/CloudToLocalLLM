# Usage: ./scripts/setup/commit_only.ps1 [commit message]
param(
    [string]$Message = "Update project"
)

Write-Host "[STATUS] Adding all changes..."
git add .
Write-Host "[STATUS] Committing..."
git commit -m "$Message" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[INFO] Nothing to commit."
}
Write-Host "[STATUS] To push your changes, run:"
Write-Host "    git push"
Write-Host "[INFO] After pushing, SSH into your VPS and run:"
Write-Host "    cd /opt/cloudtolocalllm && git pull" 