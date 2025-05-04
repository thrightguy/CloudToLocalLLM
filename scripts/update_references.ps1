# CloudToLocalLLM - Update Script References
# This script updates references to relocated PowerShell scripts in other files

# Function to update file references
function Update-FileReferences {
    param (
        [string]$FilePath,
        [hashtable]$ReplacementMap
    )

    if (Test-Path $FilePath) {
        Write-Host "Updating references in $FilePath..." -ForegroundColor Cyan
        
        # Read the content of the file
        $content = Get-Content -Path $FilePath -Raw
        
        # Apply replacements
        $replacementCount = 0
        foreach ($oldPath in $ReplacementMap.Keys) {
            $newPath = $ReplacementMap[$oldPath]
            
            # Check if the replacement is needed
            if ($content -match [regex]::Escape($oldPath)) {
                $content = $content -replace [regex]::Escape($oldPath), $newPath
                $replacementCount++
            }
        }
        
        # Update the file if changes were made
        if ($replacementCount -gt 0) {
            Set-Content -Path $FilePath -Value $content
            Write-Host "  Updated $replacementCount references" -ForegroundColor Green
        } else {
            Write-Host "  No references found to update" -ForegroundColor Yellow
        }
    } else {
        Write-Host "File $FilePath not found. Skipping." -ForegroundColor Red
    }
}

# Create replacement map
$replacements = @{}

# Build scripts
$buildScriptList = @(
    "build.ps1",
    "build_android.ps1",
    "build_windows_admin_installer.ps1", 
    "build_windows_with_license.ps1",
    "prepare_cloud_build.ps1"
)
foreach ($script in $buildScriptList) {
    $replacements[$script] = "scripts\build\$script"
}

# Release scripts - these need special attention
$replacements["clean_releases.ps1"] = "scripts\release\clean_releases.ps1"
$replacements["check_for_updates.ps1"] = "scripts\release\check_for_updates.ps1"

# Utils scripts - Setup-Ollama.ps1 is especially important
$replacements["Setup-Ollama.ps1"] = "scripts\utils\Setup-Ollama.ps1"

# Find files that might contain references to these scripts
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "CloudToLocalLLM - Updating Script References" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Update ISS installer files
$issFiles = @(
    "CloudToLocalLLM.iss",
    "CloudToLocalLLM_AdminOnly.iss",
    "CloudToLocalLLM_Simple.iss",
    "Basic.iss"
)

foreach ($issFile in $issFiles) {
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$issFile"
    Update-FileReferences -FilePath $filePath -ReplacementMap $replacements
}

# Update build scripts that were moved
$buildFiles = @(
    "scripts\build\build_windows_with_license.ps1",
    "scripts\build\build_windows_admin_installer.ps1", 
    "scripts\build\build.ps1"
)

foreach ($buildFile in $buildFiles) {
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$buildFile"
    Update-FileReferences -FilePath $filePath -ReplacementMap $replacements
}

# Update README and documentation files
$docFiles = @(
    "README.md",
    "RELEASE_INSTRUCTIONS.md",
    "RELEASE_MANAGEMENT.md",
    "WINDOWS_RELEASE_NOTES.md",
    "WINDOWS_APP_RELEASE_SUMMARY.md"
)

foreach ($docFile in $docFiles) {
    $filePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$docFile"
    Update-FileReferences -FilePath $filePath -ReplacementMap $replacements
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Reference updates complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan 