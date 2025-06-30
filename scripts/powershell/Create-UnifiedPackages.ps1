# CloudToLocalLLM Unified Package Creator (PowerShell)
# Creates multiple package formats for Windows and Linux distributions

[CmdletBinding()]
param(
    # Package Types
    [string[]]$PackageTypes = @('Windows', 'PortableZip'),
    
    # Build Configuration
    [switch]$Clean,
    [switch]$SkipBuild,
    [string]$OutputPath,
    
    # Environment Configuration
    [string]$WSLDistro,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
    
    # GitHub Release Integration
    [switch]$CreateGitHubRelease,
    [switch]$UpdateReleaseDescription,
    [switch]$ForceRecreateRelease,
    
    [switch]$Help
)

# Import build environment utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
}
else {
    Write-Error "BuildEnvironmentUtilities module not found at $utilsPath"
    exit 1
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$OutputDir = Join-Path $ProjectRoot "dist"

# Platform-specific build directories
$WindowsBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

# Package output directory structure
$WindowsOutputDir = Join-Path $OutputDir "windows"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
$Version = & $versionManagerPath get-semantic

# Global tracking variables
$script:SuccessfulPackages = @()
$script:FailedPackages = @()

# Show help information
function Show-Help {
    Write-Host "CloudToLocalLLM Unified Package Creator" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\Create-UnifiedPackages.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Package Types:" -ForegroundColor Yellow
    Write-Host "  -PackageTypes Windows,PortableZip    Create specific package types"
    Write-Host ""
    Write-Host "Build Options:" -ForegroundColor Yellow
    Write-Host "  -Clean                               Clean build directories first"
    Write-Host "  -SkipBuild                          Skip Flutter build step"
    Write-Host "  -OutputPath <path>                  Custom output directory"
    Write-Host ""
    Write-Host "Environment:" -ForegroundColor Yellow
    Write-Host "  -AutoInstall                        Install missing dependencies"
    Write-Host "  -SkipDependencyCheck               Skip dependency validation"
    Write-Host ""
    Write-Host "GitHub Integration:" -ForegroundColor Yellow
    Write-Host "  -CreateGitHubRelease               Create GitHub release with assets"
    Write-Host "  -UpdateReleaseDescription          Update release description only"
    Write-Host "  -ForceRecreateRelease              Force recreate existing release"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\Create-UnifiedPackages.ps1"
    Write-Host "  .\Create-UnifiedPackages.ps1 -PackageTypes Windows,PortableZip -Clean"
    Write-Host "  .\Create-UnifiedPackages.ps1 -CreateGitHubRelease"
}

# Create directory if it doesn't exist
function New-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-LogInfo "Created directory: $Path"
    }
}

# Build Flutter application for Windows
function Build-FlutterWindows {
    Write-LogInfo "Building Flutter application for Windows using native Windows Flutter..."

    try {
        # Clean if requested
        if ($Clean) {
            Write-LogInfo "Cleaning Flutter build..."
            Invoke-WindowsFlutterCommand -FlutterArgs "clean" -WorkingDirectory $ProjectRoot
        }

        # Get dependencies
        Write-LogInfo "Running flutter pub get..."
        Invoke-WindowsFlutterCommand -FlutterArgs "pub get" -WorkingDirectory $ProjectRoot

        # Build for Windows
        Write-LogInfo "Running flutter build windows --release..."
        Invoke-WindowsFlutterCommand -FlutterArgs "build windows --release" -WorkingDirectory $ProjectRoot

        # Verify build output
        $mainExecutable = Join-Path $WindowsBuildDir "cloudtolocalllm.exe"
        if (-not (Test-Path $mainExecutable)) {
            throw "Flutter Windows executable not found after build"
        }

        Write-LogSuccess "Windows Flutter application built successfully using native Windows Flutter"
        Write-LogInfo "Build output available at: $WindowsBuildDir"
    }
    finally {
        Pop-Location
    }
}

# Create portable ZIP package for Windows
function New-PortableZipPackage {
    Write-LogInfo "Creating portable ZIP package..."
    
    $packageName = "cloudtolocalllm-$Version-portable.zip"
    $zipOutputDir = Join-Path $WindowsOutputDir "portable"
    New-Directory -Path $zipOutputDir
    
    # Verify Windows build exists
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build directory not found. Run Flutter build first."
    }
    
    $zipPath = Join-Path $zipOutputDir $packageName
    
    # Create ZIP archive
    Write-LogInfo "Creating ZIP archive: $packageName"
    Compress-Archive -Path "$WindowsBuildDir\*" -DestinationPath $zipPath -Force
    
    # Generate checksum
    $checksum = Get-SHA256Hash -FilePath $zipPath
    "$checksum  $packageName" | Set-Content -Path "$zipPath.sha256" -Encoding UTF8
    
    Write-LogSuccess "Portable ZIP package created: $packageName"
}

# Get SHA256 hash of a file
function Get-SHA256Hash {
    param([string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

# Create Windows packages
function New-WindowsPackages {
    param([string[]]$PackageTypes)
    
    Write-LogInfo "Creating Windows packages: $($PackageTypes -join ', ')"
    
    foreach ($packageType in $PackageTypes) {
        try {
            switch ($packageType) {
                'PortableZip' {
                    New-PortableZipPackage
                    $script:SuccessfulPackages += 'PortableZip'
                }
                'MSI' {
                    Write-LogWarning "MSI package creation not yet implemented"
                    Write-LogInfo "MSI packages require WiX Toolset and additional configuration"
                    Write-LogInfo "For now, use the portable ZIP package for distribution"
                    $script:FailedPackages += @{ Package = $packageType; Reason = 'MSI creation not implemented' }
                }
                'NSIS' {
                    Write-LogWarning "NSIS package creation not yet implemented"
                    Write-LogInfo "NSIS packages require NSIS compiler and installer script"
                    Write-LogInfo "For now, use the portable ZIP package for distribution"
                    $script:FailedPackages += @{ Package = $packageType; Reason = 'NSIS creation not implemented' }
                }
                default {
                    Write-LogWarning "Unknown Windows package type: $packageType"
                    $script:FailedPackages += @{ Package = $packageType; Reason = 'Unknown package type' }
                }
            }
        }
        catch {
            Write-LogError "Failed to create $packageType package: $($_.Exception.Message)"
            $script:FailedPackages += @{ Package = $packageType; Reason = $_.Exception.Message }
        }
    }
}

# Main execution function
function Invoke-Main {
    Write-LogInfo "CloudToLocalLLM Unified Package Creator v$Version"
    Write-LogInfo "=============================================="
    
    # Show help if requested
    if ($Help) {
        Show-Help
        return
    }
    
    # Validate dependencies if not skipped
    if (-not $SkipDependencyCheck) {
        Write-LogInfo "Validating build dependencies..."
        Install-BuildDependencies -AutoInstall:$AutoInstall
    }
    
    # Set output directory
    if ($OutputPath) {
        $script:OutputDir = $OutputPath
        $script:WindowsOutputDir = Join-Path $OutputDir "windows"
    }
    
    # Create output directories
    New-Directory -Path $OutputDir
    New-Directory -Path $WindowsOutputDir
    
    # Build Flutter application if not skipped
    if (-not $SkipBuild) {
        Build-FlutterWindows
    }
    
    # Create packages based on requested types
    $windowsTypes = $PackageTypes | Where-Object { $_ -in @('Windows', 'PortableZip', 'MSI', 'NSIS') }
    
    if ($windowsTypes) {
        New-WindowsPackages -PackageTypes $windowsTypes
    }
    
    # Show summary
    Write-LogInfo ""
    Write-LogInfo "Package Creation Summary"
    Write-LogInfo "========================"
    
    if ($script:SuccessfulPackages.Count -gt 0) {
        Write-LogSuccess "Successfully created packages:"
        $script:SuccessfulPackages | ForEach-Object {
            Write-LogSuccess "  ✓ $_"
        }
    }
    
    if ($script:FailedPackages.Count -gt 0) {
        Write-LogError "Failed packages:"
        $script:FailedPackages | ForEach-Object {
            Write-LogError "  ✗ $($_.Package): $($_.Reason)"
        }
    }
    
    # Show next steps
    Write-Host ""
    Write-Host "NEXT STEPS" -ForegroundColor Yellow
    Write-Host "1. Test packages on target platforms" -ForegroundColor Yellow
    Write-Host "2. Upload to GitHub releases" -ForegroundColor Yellow
    Write-Host "3. Update package repositories" -ForegroundColor Yellow
    Write-Host "4. Deploy to VPS" -ForegroundColor Yellow
    Write-Host ""
    
    # Determine exit code
    if ($script:FailedPackages.Count -eq 0) {
        Write-LogSuccess "All requested packages created successfully!"
        exit 0
    } else {
        Write-LogError "Some packages failed to create. Check the summary above."
        exit 1
    }
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
