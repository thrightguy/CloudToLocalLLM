# CloudToLocalLLM - PowerShell Script Organization Main Script
# This script organizes all PowerShell scripts in the root directory into appropriate subfolders

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "CloudToLocalLLM - PowerShell Script Organization" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Step 1: Run the script organization script
Write-Host "`nStep 1: Organizing scripts into folders..." -ForegroundColor Green
try {
    & "$PSScriptRoot\scripts\organize_scripts.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Script organization failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "Error organizing scripts: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Update references to the scripts in other files
Write-Host "`nStep 2: Updating references in other files..." -ForegroundColor Green
try {
    & "$PSScriptRoot\scripts\update_references.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Reference updates failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Host "Error updating references: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Final messages and instructions
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Script Organization Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "`nAll PowerShell scripts have been organized into folders under 'scripts/':" -ForegroundColor White
Write-Host "- build/   - Application build scripts" -ForegroundColor White
Write-Host "- deploy/  - Deployment scripts" -ForegroundColor White
Write-Host "- release/ - Release management scripts" -ForegroundColor White
Write-Host "- auth0/   - Auth0 integration scripts" -ForegroundColor White
Write-Host "- utils/   - Utility scripts" -ForegroundColor White

Write-Host "`nIMPORTANT: Please review the changes and test the application to ensure everything works correctly." -ForegroundColor Yellow
Write-Host "Some manual adjustments may be needed for scripts with hardcoded paths." -ForegroundColor Yellow

Write-Host "`nNext steps:" -ForegroundColor Green
Write-Host "1. Verify the application builds and works correctly" -ForegroundColor White
Write-Host "2. Commit the changes to version control" -ForegroundColor White
Write-Host "3. Update documentation if needed" -ForegroundColor White

# Remind to push to GitHub if desired
Write-Host "`nDon't forget to push the changes to GitHub if you're satisfied with the reorganization." -ForegroundColor Cyan

exit 0 