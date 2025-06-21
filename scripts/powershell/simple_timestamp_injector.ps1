# CloudToLocalLLM Simple Timestamp Injector (PowerShell)
# Generates a real timestamp and immediately updates all version files
# Eliminates the BUILD_TIME_PLACEHOLDER system that causes deployment failures

[CmdletBinding()]
param(
    [switch]$VerboseOutput,
    [switch]$DryRun,
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
$PubspecFile = Join-Path $ProjectRoot "pubspec.yaml"
$AssetsVersionFile = Join-Path $ProjectRoot "assets/version.json"
$SharedVersionFile = Join-Path $ProjectRoot "lib/shared/lib/version.dart"
$SharedPubspecFile = Join-Path $ProjectRoot "lib/shared/pubspec.yaml"
$AppConfigFile = Join-Path $ProjectRoot "lib/config/app_config.dart"

# Show usage information
function Show-Usage {
    Write-Host "CloudToLocalLLM Simple Timestamp Injector (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "    .\simple_timestamp_injector.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "    -VerboseOutput  Enable verbose output"
    Write-Host "    -DryRun         Show what would be done without making changes"
    Write-Host "    -Help           Show this help message"
    Write-Host ""
    Write-Host "DESCRIPTION:" -ForegroundColor Yellow
    Write-Host "    Generates a real timestamp in YYYYMMDDHHMM format and immediately updates"
    Write-Host "    all version files with this timestamp. Eliminates the BUILD_TIME_PLACEHOLDER"
    Write-Host "    system that causes 'Invalid version number' errors during flutter pub get."
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "    .\simple_timestamp_injector.ps1                      # Update all version files with current timestamp"
    Write-Host "    .\simple_timestamp_injector.ps1 -VerboseOutput      # Verbose output"
    Write-Host "    .\simple_timestamp_injector.ps1 -DryRun             # Show what would be done"
    Write-Host ""
    Write-Host "FILES UPDATED:" -ForegroundColor Yellow
    Write-Host "    - pubspec.yaml"
    Write-Host "    - assets/version.json"
    Write-Host "    - lib/shared/lib/version.dart"
    Write-Host "    - lib/shared/pubspec.yaml"
    Write-Host "    - lib/config/app_config.dart (semantic version only)"
}

# Generate timestamp in YYYYMMDDHHMM format
function New-Timestamp {
    return Get-Date -Format "yyyyMMddHHmm"
}

# Generate ISO timestamp for JSON
function New-ISOTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Get current semantic version from pubspec.yaml
function Get-SemanticVersionFromPubspec {
    if (-not (Test-Path $PubspecFile)) {
        Write-LogError "pubspec.yaml not found: $PubspecFile"
        exit 1
    }
    
    $content = Get-Content $PubspecFile
    $versionLine = $content | Where-Object { $_ -match '^version:' } | Select-Object -First 1
    
    if (-not $versionLine) {
        Write-LogError "Version line not found in pubspec.yaml"
        exit 1
    }
    
    # Extract semantic version (before +)
    $fullVersion = ($versionLine -replace '^version:\s*', '').Trim()
    return $fullVersion -split '\+' | Select-Object -First 1
}

# Get git commit hash
function Get-GitCommit {
    if (Test-Command "git") {
        try {
            $commit = git rev-parse --short HEAD 2>$null
            if ($commit) { return $commit } else { return "unknown" }
        }
        catch {
            return "unknown"
        }
    }
    return "unknown"
}

# Update pubspec.yaml with real timestamp
function Update-PubspecVersionWithTimestamp {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp
    )
    
    $fullVersion = "$SemanticVersion+$BuildTimestamp"
    Write-LogInfo "Updating pubspec.yaml to $fullVersion"
    
    if ($DryRun) {
        Write-LogInfo "DRY RUN: Would update pubspec.yaml version to $fullVersion"
        return
    }
    
    # Update version line
    $content = Get-Content $PubspecFile
    $updatedContent = $content | ForEach-Object {
        if ($_ -match '^version:') {
            "version: $fullVersion"
        }
        else {
            $_
        }
    }
    
    Set-Content -Path $PubspecFile -Value $updatedContent -Encoding UTF8
    
    if ($VerboseOutput) {
        Write-LogInfo "Updated $PubspecFile"
    }
}

# Update assets/version.json with real timestamp
function Update-AssetsVersionJsonWithTimestamp {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp,
        [string]$ISOTimestamp,
        [string]$GitCommit
    )
    
    Write-LogInfo "Updating assets/version.json"
    
    if ($DryRun) {
        Write-LogInfo "DRY RUN: Would update assets/version.json with build_number: $BuildTimestamp"
        return
    }
    
    # Create/update the JSON file
    $jsonContent = @{
        version = $SemanticVersion
        build_number = $BuildTimestamp
        build_date = $ISOTimestamp
        git_commit = $GitCommit
    } | ConvertTo-Json -Depth 2
    
    Set-Content -Path $AssetsVersionFile -Value $jsonContent -Encoding UTF8
    
    if ($VerboseOutput) {
        Write-LogInfo "Updated $AssetsVersionFile"
    }
}

# Update lib/shared/lib/version.dart with real timestamp
function Update-SharedVersionFileWithTimestamp {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp,
        [string]$ISOTimestamp
    )
    
    Write-LogInfo "Updating lib/shared/lib/version.dart"
    
    if ($DryRun) {
        Write-LogInfo "DRY RUN: Would update version.dart with build numbers: $BuildTimestamp"
        return
    }
    
    if (-not (Test-Path $SharedVersionFile)) {
        Write-LogWarning "lib/shared/lib/version.dart not found, skipping"
        return
    }
    
    # Read and update content
    $content = Get-Content $SharedVersionFile -Raw
    
    # Update build number constants (replace BUILD_TIME_PLACEHOLDER with actual numbers)
    $content = $content -replace "BUILD_TIME_PLACEHOLDER", $BuildTimestamp
    
    # Update semantic version constants
    $content = $content -replace "static const String mainAppVersion = '[^']*'", "static const String mainAppVersion = '$SemanticVersion'"
    $content = $content -replace "static const String tunnelManagerVersion = '[^']*'", "static const String tunnelManagerVersion = '$SemanticVersion'"
    $content = $content -replace "static const String sharedLibraryVersion = '[^']*'", "static const String sharedLibraryVersion = '$SemanticVersion'"
    
    # Update build timestamp
    $content = $content -replace "static const String buildTimestamp = '[^']*'", "static const String buildTimestamp = '$ISOTimestamp'"
    
    Set-Content -Path $SharedVersionFile -Value $content -Encoding UTF8 -NoNewline
    
    if ($VerboseOutput) {
        Write-LogInfo "Updated $SharedVersionFile"
    }
}

# Update lib/shared/pubspec.yaml with real timestamp
function Update-SharedPubspecVersionWithTimestamp {
    param(
        [string]$SemanticVersion,
        [string]$BuildTimestamp
    )
    
    $fullVersion = "$SemanticVersion+$BuildTimestamp"
    Write-LogInfo "Updating lib/shared/pubspec.yaml to $fullVersion"
    
    if ($DryRun) {
        Write-LogInfo "DRY RUN: Would update shared pubspec.yaml version to $fullVersion"
        return
    }
    
    if (-not (Test-Path $SharedPubspecFile)) {
        Write-LogWarning "lib/shared/pubspec.yaml not found, skipping"
        return
    }
    
    # Update version line
    $content = Get-Content $SharedPubspecFile
    $updatedContent = $content | ForEach-Object {
        if ($_ -match '^version:') {
            "version: $fullVersion"
        }
        else {
            $_
        }
    }
    
    Set-Content -Path $SharedPubspecFile -Value $updatedContent -Encoding UTF8
    
    if ($VerboseOutput) {
        Write-LogInfo "Updated $SharedPubspecFile"
    }
}

# Update lib/config/app_config.dart with semantic version
function Update-AppConfigVersionWithTimestamp {
    param(
        [string]$SemanticVersion
    )
    
    Write-LogInfo "Updating lib/config/app_config.dart to $SemanticVersion"
    
    if ($DryRun) {
        Write-LogInfo "DRY RUN: Would update app_config.dart appVersion to $SemanticVersion"
        return
    }
    
    if (-not (Test-Path $AppConfigFile)) {
        Write-LogWarning "lib/config/app_config.dart not found, skipping"
        return
    }
    
    # Update appVersion constant
    $content = Get-Content $AppConfigFile -Raw
    $content = $content -replace "static const String appVersion = '[^']*'", "static const String appVersion = '$SemanticVersion'"
    
    Set-Content -Path $AppConfigFile -Value $content -Encoding UTF8 -NoNewline
    
    if ($VerboseOutput) {
        Write-LogInfo "Updated $AppConfigFile"
    }
}

# Main injection function
function Invoke-TimestampInjection {
    Write-LogInfo "🕒 Starting simple timestamp injection..."
    
    # Generate timestamps
    $buildTimestamp = New-Timestamp
    $isoTimestamp = New-ISOTimestamp
    $gitCommit = Get-GitCommit
    
    # Get current semantic version
    $semanticVersion = Get-SemanticVersionFromPubspec
    
    Write-LogInfo "Generated timestamp: $buildTimestamp"
    Write-LogInfo "Semantic version: $semanticVersion"
    
    if ($VerboseOutput) {
        Write-LogInfo "ISO timestamp: $isoTimestamp"
        Write-LogInfo "Git commit: $gitCommit"
    }
    
    # Update all version files
    Update-PubspecVersionWithTimestamp -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp
    Update-AssetsVersionJsonWithTimestamp -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp -ISOTimestamp $isoTimestamp -GitCommit $gitCommit
    Update-SharedVersionFileWithTimestamp -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp -ISOTimestamp $isoTimestamp
    Update-SharedPubspecVersionWithTimestamp -SemanticVersion $semanticVersion -BuildTimestamp $buildTimestamp
    Update-AppConfigVersionWithTimestamp -SemanticVersion $semanticVersion
    
    if ($DryRun) {
        Write-LogSuccess "DRY RUN: Simple timestamp injection simulation completed"
    }
    else {
        Write-LogSuccess "✅ Simple timestamp injection completed: $semanticVersion+$buildTimestamp"
        Write-LogInfo "All version files updated with real timestamp - no more BUILD_TIME_PLACEHOLDER!"
    }
}

# Validate environment
function Test-Environment {
    if ($VerboseOutput) {
        Write-LogInfo "Validating environment..."
    }
    
    # Check if we're in the right directory
    if (-not (Test-Path $PubspecFile)) {
        Write-LogError "pubspec.yaml not found. Are you in the CloudToLocalLLM project root?"
        exit 1
    }
    
    if ($VerboseOutput) {
        Write-LogInfo "Environment validation passed"
    }
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

# Show header
if ($VerboseOutput) {
    Write-LogInfo "CloudToLocalLLM Simple Timestamp Injector (PowerShell)"
    Write-LogInfo "Project root: $ProjectRoot"
}

# Validate environment
Test-Environment

# Execute timestamp injection
Invoke-TimestampInjection

# Success
if (-not $DryRun) {
    Write-LogSuccess "🎉 Timestamp injection completed successfully!"
    Write-LogInfo "You can now run 'flutter pub get' and 'flutter build' without errors"
}
