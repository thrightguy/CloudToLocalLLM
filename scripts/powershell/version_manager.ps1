# CloudToLocalLLM Version Management Utility (PowerShell)
# Provides unified version management across all platforms and build systems

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('get', 'get-semantic', 'get-build', 'info', 'increment', 'set', 'validate', 'prepare', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [string]$Parameter,

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

# Script configuration
$ProjectRoot = Get-ProjectRoot
$PubspecFile = Join-Path $ProjectRoot "pubspec.yaml"
$AppConfigFile = Join-Path $ProjectRoot "lib/config/app_config.dart"
$SharedVersionFile = Join-Path $ProjectRoot "lib/shared/lib/version.dart"
$SharedPubspecFile = Join-Path $ProjectRoot "lib/shared/pubspec.yaml"
$AssetsVersionFile = Join-Path $ProjectRoot "assets/version.json"

# Extract version components from pubspec.yaml
function Get-VersionFromPubspec {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path $PubspecFile)) {
        Write-LogError "pubspec.yaml not found at $PubspecFile"
        exit 1
    }
    
    $content = Get-Content $PubspecFile
    $versionLine = $content | Where-Object { $_ -match '^version:' } | Select-Object -First 1
    
    if (-not $versionLine) {
        Write-LogError "No version found in pubspec.yaml"
        exit 1
    }
    
    # Extract version (format: version: MAJOR.MINOR.PATCH+BUILD_NUMBER)
    if ($versionLine -match 'version:\s*(.+)') {
        return $matches[1].Trim()
    }
    
    Write-LogError "Could not parse version from pubspec.yaml"
    exit 1
}

# Extract semantic version (without build number)
function Get-SemanticVersion {
    [CmdletBinding()]
    param()
    
    $fullVersion = Get-VersionFromPubspec
    if ($fullVersion -match '^([^+]+)') {
        return $matches[1]
    }
    return $fullVersion
}

# Extract build number
function Get-BuildNumber {
    [CmdletBinding()]
    param()
    
    $fullVersion = Get-VersionFromPubspec
    if ($fullVersion -match '\+(.+)$') {
        return $matches[1]
    }
    return "1"
}

# Generate new build number based on current timestamp (YYYYMMDDHHMM format)
function New-BuildNumber {
    [CmdletBinding()]
    param()
    
    return Get-Date -Format "yyyyMMddHHmm"
}

# Increment build number - generates placeholder for build-time injection
function New-IncrementBuildNumber {
    [CmdletBinding()]
    param()
    
    # Generate placeholder timestamp that will be replaced at build time
    return "BUILD_TIME_PLACEHOLDER"
}

# Check if version qualifies for GitHub release
function Test-GitHubReleaseRequired {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    $parts = $Version -split '\.'
    if ($parts.Count -ge 3) {
        $minor = [int]$parts[1]
        $patch = [int]$parts[2]
        
        # Only create GitHub releases for major version updates (x.0.0)
        return ($minor -eq 0 -and $patch -eq 0)
    }
    
    return $false
}

# Increment version based on type (major, minor, patch, build)
function Step-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('major', 'minor', 'patch', 'build')]
        [string]$IncrementType
    )
    
    $currentVersion = Get-SemanticVersion
    $parts = $currentVersion -split '\.'
    
    if ($parts.Count -ne 3) {
        Write-LogError "Invalid version format: $currentVersion. Expected format: MAJOR.MINOR.PATCH"
        exit 1
    }
    
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($IncrementType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
        'build' {
            # No semantic version change for build increment
        }
    }
    
    return "$major.$minor.$patch"
}

# Update version in pubspec.yaml
function Update-PubspecVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )
    
    $fullVersion = "$NewVersion+$NewBuildNumber"
    Write-LogInfo "Updating pubspec.yaml version to $fullVersion"
    
    # Create backup
    Copy-Item $PubspecFile "$PubspecFile.backup" -Force
    
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
    Write-LogSuccess "Updated pubspec.yaml version to $fullVersion"
}

# Update version in app_config.dart
function Update-AppConfigVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    Write-LogInfo "Updating app_config.dart version to $NewVersion"

    if (-not (Test-Path $AppConfigFile)) {
        Write-LogWarning "app_config.dart not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $AppConfigFile "$AppConfigFile.backup" -Force

    # Update version constant
    $content = Get-Content $AppConfigFile -Raw
    $updatedContent = $content -replace "static const String appVersion = '[^']*';", "static const String appVersion = '$NewVersion';"

    Set-Content -Path $AppConfigFile -Value $updatedContent -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated app_config.dart version to $NewVersion"
}

# Update version in shared/lib/version.dart
function Update-SharedVersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,

        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )

    Write-LogInfo "Updating shared/lib/version.dart to $NewVersion"

    if (-not (Test-Path $SharedVersionFile)) {
        Write-LogWarning "shared/lib/version.dart not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $SharedVersionFile "$SharedVersionFile.backup" -Force

    # Generate build timestamp and ensure build number is in YYYYMMDDHHMM format
    $buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $buildNumberInt = $NewBuildNumber

    # Read current content
    $content = Get-Content $SharedVersionFile -Raw

    # Update all version constants
    $content = $content -replace "static const String mainAppVersion = '[^']*';", "static const String mainAppVersion = '$NewVersion';"
    $content = $content -replace "static const int mainAppBuildNumber = [0-9]*;", "static const int mainAppBuildNumber = $buildNumberInt;"
    $content = $content -replace "static const String tunnelManagerVersion = '[^']*';", "static const String tunnelManagerVersion = '$NewVersion';"
    $content = $content -replace "static const int tunnelManagerBuildNumber = [0-9]*;", "static const int tunnelManagerBuildNumber = $buildNumberInt;"
    $content = $content -replace "static const String sharedLibraryVersion = '[^']*';", "static const String sharedLibraryVersion = '$NewVersion';"
    $content = $content -replace "static const int sharedLibraryBuildNumber = [0-9]*;", "static const int sharedLibraryBuildNumber = $buildNumberInt;"
    $content = $content -replace "static const String buildTimestamp = '[^']*';", "static const String buildTimestamp = '$buildTimestamp';"

    Set-Content -Path $SharedVersionFile -Value $content -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated shared/lib/version.dart to $NewVersion"
}

# Update version in shared/pubspec.yaml
function Update-SharedPubspecVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,

        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )

    $fullVersion = "$NewVersion+$NewBuildNumber"
    Write-LogInfo "Updating shared/pubspec.yaml version to $fullVersion"

    if (-not (Test-Path $SharedPubspecFile)) {
        Write-LogWarning "shared/pubspec.yaml not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $SharedPubspecFile "$SharedPubspecFile.backup" -Force

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
    Write-LogSuccess "Updated shared/pubspec.yaml version to $fullVersion"
}

# Update version in assets/version.json
function Update-AssetsVersionJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,

        [Parameter(Mandatory = $true)]
        [string]$NewBuildNumber
    )

    Write-LogInfo "Updating assets/version.json to $NewVersion"

    if (-not (Test-Path $AssetsVersionFile)) {
        Write-LogWarning "assets/version.json not found, skipping update"
        return
    }

    # Create backup
    Copy-Item $AssetsVersionFile "$AssetsVersionFile.backup" -Force

    # Generate build timestamp
    $buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Read current git commit (preserve existing value if available)
    $gitCommit = "unknown"
    if (Test-Command "git") {
        try {
            $gitCommit = git rev-parse --short HEAD 2>$null
            if (-not $gitCommit) { $gitCommit = "unknown" }
        }
        catch {
            $gitCommit = "unknown"
        }
    }

    # Read and update JSON content
    $content = Get-Content $AssetsVersionFile -Raw
    $content = $content -replace '"version": "[^"]*"', "`"version`": `"$NewVersion`""
    $content = $content -replace '"build_number": "[^"]*"', "`"build_number`": `"$NewBuildNumber`""
    $content = $content -replace '"build_date": "[^"]*"', "`"build_date`": `"$buildTimestamp`""

    # Only update git_commit if we successfully got one
    if ($gitCommit -ne "unknown") {
        $content = $content -replace '"git_commit": "[^"]*"', "`"git_commit`": `"$gitCommit`""
    }

    Set-Content -Path $AssetsVersionFile -Value $content -Encoding UTF8 -NoNewline
    Write-LogSuccess "Updated assets/version.json to $NewVersion"
}

# Validate version format
function Test-VersionFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        Write-LogError "Invalid version format: $Version. Expected format: MAJOR.MINOR.PATCH"
        exit 1
    }
    
    Write-LogSuccess "Version format is valid: $Version"
}

# Display current version information
function Show-VersionInfo {
    [CmdletBinding()]
    param()
    
    $fullVersion = Get-VersionFromPubspec
    $semanticVersion = Get-SemanticVersion
    $buildNumber = Get-BuildNumber
    
    Write-Host "=== CloudToLocalLLM Version Information ===" -ForegroundColor Cyan
    Write-Host "Full Version:     " -NoNewline
    Write-Host $fullVersion -ForegroundColor Green
    Write-Host "Semantic Version: " -NoNewline
    Write-Host $semanticVersion -ForegroundColor Green
    Write-Host "Build Number:     " -NoNewline
    Write-Host $buildNumber -ForegroundColor Green
    Write-Host "Source File:      " -NoNewline
    Write-Host $PubspecFile -ForegroundColor Blue
}

# Check basic dependencies for version management
if (-not $SkipDependencyCheck -and $Command -notin @('get', 'get-semantic', 'get-build', 'info', 'help')) {
    $requiredPackages = @('git')
    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies for version management"
        exit 1
    }
}

# Main command dispatcher
switch ($Command) {
    'get' {
        Get-VersionFromPubspec
    }
    'get-semantic' {
        Get-SemanticVersion
    }
    'get-build' {
        Get-BuildNumber
    }
    'info' {
        Show-VersionInfo
    }
    'increment' {
        if (-not $Parameter) {
            Write-LogError "Usage: .\version_manager.ps1 increment <major|minor|patch|build>"
            exit 1
        }

        $currentVersion = Get-SemanticVersion
        $incrementType = $Parameter

        if ($incrementType -eq 'build') {
            # For build increments, keep same semantic version but increment build number
            $newBuildNumber = New-IncrementBuildNumber
            Test-VersionFormat -Version $currentVersion
            Update-PubspecVersion -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Update-AppConfigVersion -NewVersion $currentVersion
            Update-SharedVersionFile -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Update-SharedPubspecVersion -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Update-AssetsVersionJson -NewVersion $currentVersion -NewBuildNumber $newBuildNumber
            Write-LogInfo "Build number incremented (no GitHub release needed)"
        }
        else {
            # For semantic version changes, generate new timestamp build number
            $newVersion = Step-Version -IncrementType $incrementType
            $newBuildNumber = New-BuildNumber
            Test-VersionFormat -Version $newVersion
            Update-PubspecVersion -NewVersion $newVersion -NewBuildNumber $newBuildNumber
            Update-AppConfigVersion -NewVersion $newVersion
            Update-SharedVersionFile -NewVersion $newVersion -NewBuildNumber $newBuildNumber
            Update-SharedPubspecVersion -NewVersion $newVersion -NewBuildNumber $newBuildNumber
            Update-AssetsVersionJson -NewVersion $newVersion -NewBuildNumber $newBuildNumber

            # Check if GitHub release should be created
            if (Test-GitHubReleaseRequired -Version $newVersion) {
                Write-LogWarning "This is a MAJOR version update - GitHub release should be created!"
                Write-LogInfo "Run: git tag v$newVersion && git push origin v$newVersion"
            }
            else {
                Write-LogInfo "Minor/patch update - no GitHub release needed"
            }
        }

        Show-VersionInfo
    }
    'set' {
        if (-not $Parameter) {
            Write-LogError "Usage: .\version_manager.ps1 set <version>"
            exit 1
        }

        Test-VersionFormat -Version $Parameter
        $newBuildNumber = New-BuildNumber
        Update-PubspecVersion -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Update-AppConfigVersion -NewVersion $Parameter
        Update-SharedVersionFile -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Update-SharedPubspecVersion -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Update-AssetsVersionJson -NewVersion $Parameter -NewBuildNumber $newBuildNumber
        Show-VersionInfo
    }
    'prepare' {
        if (-not $Parameter) {
            Write-LogError "Usage: .\version_manager.ps1 prepare <major|minor|patch|build>"
            exit 1
        }

        $currentVersion = Get-SemanticVersion
        $incrementType = $Parameter

        if ($incrementType -eq 'build') {
            # For build preparation, keep same semantic version with placeholder
            $placeholderBuild = "BUILD_TIME_PLACEHOLDER"
            Test-VersionFormat -Version $currentVersion
            Update-PubspecVersion -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Update-AppConfigVersion -NewVersion $currentVersion
            Update-SharedVersionFile -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Update-SharedPubspecVersion -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Update-AssetsVersionJson -NewVersion $currentVersion -NewBuildNumber $placeholderBuild
            Write-LogInfo "Version prepared for build-time timestamp injection"
        }
        else {
            # For semantic version changes, prepare with placeholder
            $newVersion = Step-Version -IncrementType $incrementType
            $placeholderBuild = "BUILD_TIME_PLACEHOLDER"
            Test-VersionFormat -Version $newVersion
            Update-PubspecVersion -NewVersion $newVersion -NewBuildNumber $placeholderBuild
            Update-AppConfigVersion -NewVersion $newVersion
            Update-SharedVersionFile -NewVersion $newVersion -NewBuildNumber $placeholderBuild
            Update-SharedPubspecVersion -NewVersion $newVersion -NewBuildNumber $placeholderBuild
            Update-AssetsVersionJson -NewVersion $newVersion -NewBuildNumber $placeholderBuild

            # Check if GitHub release should be created
            if (Test-GitHubReleaseRequired -Version $newVersion) {
                Write-LogWarning "This is a MAJOR version update - GitHub release should be created!"
                Write-LogInfo "Run: git tag v$newVersion && git push origin v$newVersion"
            }
            else {
                Write-LogInfo "Minor/patch update - no GitHub release needed"
            }
        }

        Write-LogInfo "Version prepared with placeholder. Use build-time injection during actual build."
        Show-VersionInfo
    }
    'validate' {
        $version = Get-SemanticVersion
        Test-VersionFormat -Version $version
    }
    'help' {
        Write-Host "CloudToLocalLLM Version Manager (PowerShell)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage: .\version_manager.ps1 <command> [arguments]" -ForegroundColor White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Yellow
        Write-Host "  get              Get full version (MAJOR.MINOR.PATCH+BUILD)"
        Write-Host "  get-semantic     Get semantic version (MAJOR.MINOR.PATCH)"
        Write-Host "  get-build        Get build number"
        Write-Host "  info             Show detailed version information"
        Write-Host "  increment <type> Increment version (major|minor|patch|build) - immediate timestamp"
        Write-Host "  prepare <type>   Prepare version (major|minor|patch|build) - build-time timestamp"
        Write-Host "  set <version>    Set specific version (MAJOR.MINOR.PATCH)"
        Write-Host "  validate         Validate current version format"
        Write-Host "  help             Show this help message"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\version_manager.ps1 info"
        Write-Host "  .\version_manager.ps1 increment patch"
        Write-Host "  .\version_manager.ps1 prepare build"
        Write-Host "  .\version_manager.ps1 set 3.1.0"
        Write-Host ""
        Write-Host "CloudToLocalLLM Semantic Versioning Strategy:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  PATCH (0.0.X+YYYYMMDDHHMM) - URGENT FIXES:"
        Write-Host "    • Hotfixes and critical bug fixes requiring immediate deployment"
        Write-Host "    • Security updates and emergency patches"
        Write-Host "    • Critical stability fixes that can't wait for next minor release"
        Write-Host ""
        Write-Host "  MINOR (0.X.0+YYYYMMDDHHMM) - PLANNED FEATURES:"
        Write-Host "    • Feature additions and new functionality"
        Write-Host "    • Quality of life improvements and UI enhancements"
        Write-Host "    • Planned feature releases and capability expansions"
        Write-Host ""
        Write-Host "  MAJOR (X.0.0+YYYYMMDDHHMM) - BREAKING CHANGES:"
        Write-Host "    • Breaking changes and architectural overhauls"
        Write-Host "    • Significant API changes requiring user adaptation"
        Write-Host "    • Major platform or framework migrations"
        Write-Host "    • Creates GitHub release automatically"
        Write-Host ""
        Write-Host "  BUILD (X.Y.Z+YYYYMMDDHHMM) - TIMESTAMP ONLY:"
        Write-Host "    • No semantic version change, only build timestamp update"
        Write-Host "    • Used for CI/CD builds and testing iterations"
        Write-Host ""
        Write-Host "Build Number Format:"
        Write-Host "  YYYYMMDDHHMM     Timestamp format representing build creation time"
    }
    default {
        Write-LogError "Unknown command: $Command"
        Write-Host "Use '.\version_manager.ps1 help' for usage information"
        exit 1
    }
}
