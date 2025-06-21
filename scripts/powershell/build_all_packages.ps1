# CloudToLocalLLM Unified Package Build Script (PowerShell)
# Builds all package formats with unified version management

[CmdletBinding()]
param(
    [ValidateSet('major', 'minor', 'patch')]
    [string]$Increment,
    
    [switch]$SkipIncrement,
    
    [ValidateSet('all', 'snap', 'debian', 'aur', 'windows')]
    [string]$Packages = 'all',
    
    [switch]$UseWSL,
    [string]$WSLDistro,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
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

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Unified Package Build Script (PowerShell)" -ForegroundColor Blue
    Write-Host "=========================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Builds all package formats with unified version management" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\build_all_packages.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Increment <type>     Increment version (major|minor|patch)"
    Write-Host "  -SkipIncrement        Skip version increment"
    Write-Host "  -Packages <list>      Build specific packages (all|snap|debian|aur|windows)"
    Write-Host "  -UseWSL               Use WSL for Linux operations"
    Write-Host "  -WSLDistro            Specific WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\build_all_packages.ps1"
    Write-Host "  .\build_all_packages.ps1 -Increment minor"
    Write-Host "  .\build_all_packages.ps1 -Packages debian -UseWSL"
    Write-Host "  .\build_all_packages.ps1 -Packages windows -SkipIncrement"
    exit 0
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$ScriptDir = Join-Path $ProjectRoot "scripts\packaging"

Write-Host "CloudToLocalLLM Unified Package Build Script (PowerShell)" -ForegroundColor Blue
Write-Host "=========================================================" -ForegroundColor Blue
Write-Host ""

# Version management functions
function Get-SemanticVersion {
    $versionScript = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionScript) {
        return & powershell -ExecutionPolicy Bypass -File $versionScript -GetSemantic
    }
    else {
        return Get-ProjectVersion
    }
}

function Get-FullVersion {
    $versionScript = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionScript) {
        return & powershell -ExecutionPolicy Bypass -File $versionScript -Get
    }
    else {
        return Get-ProjectVersion
    }
}

function Get-BuildNumber {
    $versionScript = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionScript) {
        return & powershell -ExecutionPolicy Bypass -File $versionScript -GetBuild
    }
    else {
        return (Get-Date -Format "yyyyMMddHHmm")
    }
}

# Increment version based on type
function Invoke-VersionIncrement {
    param([string]$IncrementType)
    
    Write-LogInfo "Incrementing $IncrementType version..."
    
    $versionScript = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionScript) {
        & powershell -ExecutionPolicy Bypass -File $versionScript -Increment $IncrementType
    }
    else {
        Write-LogWarning "Version manager script not found, skipping version increment"
    }
}

# Validate version consistency across all packages
function Test-VersionConsistency {
    Write-LogInfo "Validating version consistency across all packages..."
    
    $semanticVersion = Get-SemanticVersion
    $fullVersion = Get-FullVersion
    $buildNumber = Get-BuildNumber
    
    Write-LogInfo "Semantic Version: $semanticVersion"
    Write-LogInfo "Full Version: $fullVersion"
    Write-LogInfo "Build Number: $buildNumber"
    
    # Validate version format
    $versionScript = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionScript) {
        $result = & powershell -ExecutionPolicy Bypass -File $versionScript -Validate
        if ($LASTEXITCODE -ne 0) {
            Write-LogError "Version validation failed"
            exit 1
        }
    }
    
    Write-LogSuccess "Version validation passed"
}

# Update Flutter app configuration with current version
function Update-FlutterVersion {
    Write-LogInfo "Updating Flutter application version configuration..."
    
    $semanticVersion = Get-SemanticVersion
    $buildNumber = Get-BuildNumber
    
    # Update app_config.dart with current version
    $appConfigFile = Join-Path $ProjectRoot "lib\config\app_config.dart"
    if (Test-Path $appConfigFile) {
        $content = Get-Content $appConfigFile -Raw
        $content = $content -replace "static const String appVersion = '[^']*';", "static const String appVersion = '$semanticVersion';"
        Set-Content -Path $appConfigFile -Value $content -Encoding UTF8 -NoNewline
        Write-LogSuccess "Updated app_config.dart with version $semanticVersion"
    }
    
    # Create version.json asset for runtime version access
    $assetsDir = Join-Path $ProjectRoot "assets"
    if (-not (Test-Path $assetsDir)) {
        New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    }
    
    # Get git commit hash
    $gitCommit = "unknown"
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $gitCommit = & git rev-parse --short HEAD 2>$null
            if ($LASTEXITCODE -ne 0) {
                $gitCommit = "unknown"
            }
        }
    }
    catch {
        $gitCommit = "unknown"
    }
    
    $versionJson = @{
        version = $semanticVersion
        build_number = $buildNumber
        build_date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        git_commit = $gitCommit
    } | ConvertTo-Json -Depth 2
    
    $versionJsonPath = Join-Path $assetsDir "version.json"
    Set-Content -Path $versionJsonPath -Value $versionJson -Encoding UTF8
    
    Write-LogSuccess "Created version.json asset"
}

# Build Snap package
function Build-SnapPackage {
    Write-LogInfo "Building Snap package..."

    if (-not $UseWSL) {
        Write-LogWarning "Skipping Snap build (WSL required for Linux operations)"
        return $true
    }

    $snapScript = Join-Path $ScriptDir "build_snap.sh"
    if (-not (Test-Path $snapScript)) {
        Write-LogWarning "Snap build script not found, skipping"
        return $true
    }

    try {
        $wslScriptPath = Convert-WindowsPathToWSL -WindowsPath $snapScript
        $wslProjectRoot = Convert-WindowsPathToWSL -WindowsPath $ProjectRoot
        $buildCommand = "cd `"$wslProjectRoot/scripts/packaging`" && bash build_snap.sh"
        
        Invoke-WSLCommand -DistroName $WSLDistro -Command $buildCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Snap build completed"
            return $true
        }
        else {
            Write-LogError "Snap build failed"
            return $false
        }
    }
    catch {
        Write-LogError "Snap build failed: $($_.Exception.Message)"
        return $false
    }
}

# Build Debian package
function Build-DebianPackage {
    Write-LogInfo "Building Debian package..."

    $debScript = Join-Path $PSScriptRoot "build_deb.ps1"
    if (-not (Test-Path $debScript)) {
        Write-LogError "Debian build script not found: $debScript"
        return $false
    }

    try {
        $params = @()
        if ($UseWSL) { $params += '-UseWSL' }
        if ($WSLDistro) { $params += '-WSLDistro', $WSLDistro }
        if ($AutoInstall) { $params += '-AutoInstall' }
        if ($SkipDependencyCheck) { $params += '-SkipDependencyCheck' }
        
        & powershell -ExecutionPolicy Bypass -File $debScript @params
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Debian package build completed"
            return $true
        }
        else {
            Write-LogError "Debian package build failed"
            return $false
        }
    }
    catch {
        Write-LogError "Debian package build failed: $($_.Exception.Message)"
        return $false
    }
}

# Build AUR package
function Build-AURPackage {
    Write-LogInfo "Building AUR package..."

    $aurScript = Join-Path $PSScriptRoot "create_unified_aur_package.ps1"
    if (-not (Test-Path $aurScript)) {
        Write-LogError "AUR build script not found: $aurScript"
        return $false
    }

    try {
        $params = @()
        if ($UseWSL) { $params += '-UseWSL' }
        if ($WSLDistro) { $params += '-WSLDistro', $WSLDistro }
        if ($AutoInstall) { $params += '-AutoInstall' }
        if ($SkipDependencyCheck) { $params += '-SkipDependencyCheck' }
        
        & powershell -ExecutionPolicy Bypass -File $aurScript @params
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "AUR package build completed"
            return $true
        }
        else {
            Write-LogError "AUR package build failed"
            return $false
        }
    }
    catch {
        Write-LogError "AUR package build failed: $($_.Exception.Message)"
        return $false
    }
}

# Build Windows package
function Build-WindowsPackage {
    Write-LogInfo "Building Windows package..."

    $windowsScript = Join-Path $PSScriptRoot "build_unified_package.ps1"
    if (-not (Test-Path $windowsScript)) {
        Write-LogError "Windows build script not found: $windowsScript"
        return $false
    }

    try {
        $params = @()
        if ($AutoInstall) { $params += '-AutoInstall' }
        if ($SkipDependencyCheck) { $params += '-SkipDependencyCheck' }
        
        & powershell -ExecutionPolicy Bypass -File $windowsScript @params
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Windows package build completed"
            return $true
        }
        else {
            Write-LogError "Windows package build failed"
            return $false
        }
    }
    catch {
        Write-LogError "Windows package build failed: $($_.Exception.Message)"
        return $false
    }
}

# Validate all generated packages
function Test-GeneratedPackages {
    Write-LogInfo "Validating generated packages..."

    $version = Get-SemanticVersion
    $distDir = Join-Path $ProjectRoot "dist"
    $validationErrors = 0

    # Check Snap package
    $snapPackage = Join-Path $distDir "cloudtolocalllm_${version}_amd64.snap"
    if (Test-Path $snapPackage) {
        Write-LogSuccess "Snap package found: cloudtolocalllm_${version}_amd64.snap"
        $snapChecksum = "$snapPackage.sha256"
        if (Test-Path $snapChecksum) {
            Write-LogSuccess "Snap package checksum found"
        }
        else {
            Write-LogError "Snap package checksum missing"
            $validationErrors++
        }
    }
    else {
        Write-LogWarning "Snap package not found (may have been skipped)"
    }

    # Check Debian package
    $debianPackage = Join-Path $distDir "debian\cloudtolocalllm_${version}_amd64.deb"
    if (Test-Path $debianPackage) {
        Write-LogSuccess "Debian package found: cloudtolocalllm_${version}_amd64.deb"
        $debianChecksum = "$debianPackage.sha256"
        if (Test-Path $debianChecksum) {
            Write-LogSuccess "Debian package checksum found"
        }
        else {
            Write-LogError "Debian package checksum missing"
            $validationErrors++
        }
    }
    else {
        Write-LogWarning "Debian package not found (may have been skipped)"
    }

    # Check AUR package
    $aurPackage = Join-Path $distDir "cloudtolocalllm-${version}-x86_64.tar.gz"
    if (Test-Path $aurPackage) {
        Write-LogSuccess "AUR package found: cloudtolocalllm-${version}-x86_64.tar.gz"
        $aurChecksum = "$aurPackage.sha256"
        if (Test-Path $aurChecksum) {
            Write-LogSuccess "AUR package checksum found"
        }
        else {
            Write-LogError "AUR package checksum missing"
            $validationErrors++
        }
    }
    else {
        Write-LogWarning "AUR package not found (may have been skipped)"
    }

    # Check Windows package
    $windowsPackage = Join-Path $distDir "CloudToLocalLLM-${version}-windows-x64.zip"
    if (Test-Path $windowsPackage) {
        Write-LogSuccess "Windows package found: CloudToLocalLLM-${version}-windows-x64.zip"
        $windowsChecksum = "$windowsPackage.sha256"
        if (Test-Path $windowsChecksum) {
            Write-LogSuccess "Windows package checksum found"
        }
        else {
            Write-LogError "Windows package checksum missing"
            $validationErrors++
        }
    }
    else {
        Write-LogWarning "Windows package not found (may have been skipped)"
    }

    if ($validationErrors -gt 0) {
        Write-LogError "Package validation failed with $validationErrors errors"
        return $false
    }
    else {
        Write-LogSuccess "All packages validated successfully"
        return $true
    }
}

# Generate build summary
function Show-BuildSummary {
    Write-LogInfo "Generating build summary..."

    $version = Get-SemanticVersion
    $fullVersion = Get-FullVersion
    $buildNumber = Get-BuildNumber
    $distDir = Join-Path $ProjectRoot "dist"

    Write-Host ""
    Write-Host "=== CloudToLocalLLM Build Summary ===" -ForegroundColor Cyan
    Write-Host "Semantic Version: $version"
    Write-Host "Full Version: $fullVersion"
    Write-Host "Build Number: $buildNumber"
    Write-Host "Build Date: $(Get-Date)"
    Write-Host ""
    Write-Host "Generated Packages:" -ForegroundColor Yellow

    # List all generated packages with sizes
    $snapPackage = Join-Path $distDir "cloudtolocalllm_${version}_amd64.snap"
    if (Test-Path $snapPackage) {
        $size = [math]::Round((Get-Item $snapPackage).Length / 1MB, 2)
        Write-Host "  Snap: cloudtolocalllm_${version}_amd64.snap ($size MB)"
    }

    $debianPackage = Join-Path $distDir "debian\cloudtolocalllm_${version}_amd64.deb"
    if (Test-Path $debianPackage) {
        $size = [math]::Round((Get-Item $debianPackage).Length / 1MB, 2)
        Write-Host "  Debian: cloudtolocalllm_${version}_amd64.deb ($size MB)"
    }

    $aurPackage = Join-Path $distDir "cloudtolocalllm-${version}-x86_64.tar.gz"
    if (Test-Path $aurPackage) {
        $size = [math]::Round((Get-Item $aurPackage).Length / 1MB, 2)
        Write-Host "  AUR: cloudtolocalllm-${version}-x86_64.tar.gz ($size MB)"
    }

    $windowsPackage = Join-Path $distDir "CloudToLocalLLM-${version}-windows-x64.zip"
    if (Test-Path $windowsPackage) {
        $size = [math]::Round((Get-Item $windowsPackage).Length / 1MB, 2)
        Write-Host "  Windows: CloudToLocalLLM-${version}-windows-x64.zip ($size MB)"
    }

    Write-Host ""
    Write-Host "Distribution Directory: $distDir"
    Write-Host ""
}

# Main execution function
function Invoke-Main {
    Write-LogInfo "Starting CloudToLocalLLM unified package build..."

    # Check prerequisites
    $requiredPackages = @('git')
    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Set up WSL if needed
    if ($UseWSL -and -not $WSLDistro) {
        $WSLDistro = Find-WSLDistribution -Purpose 'Any'
        if (-not $WSLDistro) {
            Write-LogError "No WSL distribution found. Install WSL: wsl --install"
            exit 1
        }
    }

    # Increment version if requested
    if ($Increment -and -not $SkipIncrement) {
        Invoke-VersionIncrement -IncrementType $Increment
    }

    # Validate version consistency
    Test-VersionConsistency

    # Update Flutter version configuration
    Update-FlutterVersion

    # Build packages based on selection
    $buildErrors = 0

    switch ($Packages) {
        'all' {
            if (-not (Build-WindowsPackage)) { $buildErrors++ }
            if (-not (Build-DebianPackage)) { $buildErrors++ }
            if (-not (Build-AURPackage)) { $buildErrors++ }
            if (-not (Build-SnapPackage)) { $buildErrors++ }
        }
        'windows' {
            if (-not (Build-WindowsPackage)) { $buildErrors++ }
        }
        'debian' {
            if (-not (Build-DebianPackage)) { $buildErrors++ }
        }
        'aur' {
            if (-not (Build-AURPackage)) { $buildErrors++ }
        }
        'snap' {
            if (-not (Build-SnapPackage)) { $buildErrors++ }
        }
        default {
            Write-LogError "Invalid package selection: $Packages"
            exit 1
        }
    }

    # Validate generated packages
    if (-not (Test-GeneratedPackages)) {
        $buildErrors++
    }

    # Generate summary
    Show-BuildSummary

    # Final status
    if ($buildErrors -eq 0) {
        Write-LogSuccess "All package builds completed successfully!"
        exit 0
    }
    else {
        Write-LogError "Package build completed with $buildErrors errors"
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
