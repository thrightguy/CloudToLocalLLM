# PowerShell script to prepare the cloud portal build folder
# This script creates a 'cloud' folder and copies only the necessary files for cloud deployment.

$ErrorActionPreference = 'Stop'

$cloudDir = Join-Path $PSScriptRoot 'cloud'

# Remove existing cloud folder if it exists
if (Test-Path $cloudDir) {
    Remove-Item $cloudDir -Recurse -Force
}

# Create cloud folder
New-Item -ItemType Directory -Path $cloudDir | Out-Null

# Copy required directories
Copy-Item -Path (Join-Path $PSScriptRoot 'lib') -Destination $cloudDir -Recurse
Copy-Item -Path (Join-Path $PSScriptRoot 'web') -Destination $cloudDir -Recurse

# Copy required files
Copy-Item -Path (Join-Path $PSScriptRoot 'pubspec.yaml') -Destination $cloudDir
Copy-Item -Path (Join-Path $PSScriptRoot 'Dockerfile') -Destination $cloudDir
Copy-Item -Path (Join-Path $PSScriptRoot 'README_CLOUD_DEPLOY.md') -Destination $cloudDir

Write-Host "Cloud build folder prepared at: $cloudDir"
Write-Host "You can now push the contents of this folder to your cloud GitHub repo."
