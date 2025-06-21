# CloudToLocalLLM Local Resources Verification Script (PowerShell)
# Downloads and verifies CSS and web resources for the web interface

[CmdletBinding()]
param(
    [string]$TargetPath = "/opt/cloudtolocalllm/nginx/html",
    [switch]$UseWSL,
    [string]$WSLDistro,
    [switch]$WindowsPath,
    [string]$WindowsTargetPath = "C:\nginx\html",
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
    Write-Host "CloudToLocalLLM Local Resources Verification Script (PowerShell)" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Downloads and verifies CSS and web resources for the web interface" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\verify_local_resources.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -TargetPath           Target path for resources (default: /opt/cloudtolocalllm/nginx/html)"
    Write-Host "  -UseWSL               Use WSL for Linux operations"
    Write-Host "  -WSLDistro            Specific WSL distribution to use"
    Write-Host "  -WindowsPath          Use Windows paths instead of Linux paths"
    Write-Host "  -WindowsTargetPath    Windows target path (default: C:\nginx\html)"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\verify_local_resources.ps1"
    Write-Host "  .\verify_local_resources.ps1 -UseWSL -WSLDistro Ubuntu"
    Write-Host "  .\verify_local_resources.ps1 -WindowsPath -WindowsTargetPath 'C:\inetpub\wwwroot'"
    exit 0
}

Write-Host "CloudToLocalLLM Local Resources Verification Script (PowerShell)" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host ""

# Determine target path and execution method
if ($WindowsPath) {
    $FinalTargetPath = $WindowsTargetPath
    $UseWSL = $false
    Write-LogInfo "Using Windows paths: $FinalTargetPath"
}
else {
    $FinalTargetPath = $TargetPath
    if (-not $UseWSL) {
        $UseWSL = $true
        Write-LogInfo "Linux paths detected, enabling WSL mode"
    }
    Write-LogInfo "Using Linux paths: $FinalTargetPath"
}

# Check prerequisites
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites..."

    if ($UseWSL) {
        # Find suitable WSL distribution
        if (-not $WSLDistro) {
            $WSLDistro = Find-WSLDistribution -Purpose 'Any'
            if (-not $WSLDistro) {
                Write-LogError "No WSL distribution found. Install WSL: wsl --install"
                exit 1
            }
        }

        # Verify curl is available in WSL
        if (-not (Test-WSLCommand -DistroName $WSLDistro -CommandName "curl")) {
            Write-LogError "curl not found in WSL distribution: $WSLDistro"
            Write-LogError "Install curl: sudo apt install curl (Ubuntu) or sudo pacman -S curl (Arch)"
            exit 1
        }
    }
    else {
        # Check for Windows curl or install dependencies
        $requiredPackages = @('curl')
        if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
            Write-LogError "Failed to install required dependencies"
            exit 1
        }
    }

    Write-LogSuccess "Prerequisites check passed"
}

# Create necessary directories
function New-ResourceDirectories {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating necessary directories..."

    if ($UseWSL) {
        # Create directories using WSL
        $cssDir = "$FinalTargetPath/css"
        $webfontsDir = "$FinalTargetPath/webfonts"
        
        $mkdirCommand = "mkdir -p `"$cssDir`" `"$webfontsDir`""
        try {
            Invoke-WSLCommand -DistroName $WSLDistro -Command $mkdirCommand
        }
        catch {
            Write-LogError "Failed to create directories in WSL: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        # Create directories using Windows
        $cssDir = Join-Path $FinalTargetPath "css"
        $webfontsDir = Join-Path $FinalTargetPath "webfonts"
        
        New-Item -ItemType Directory -Path $cssDir -Force | Out-Null
        New-Item -ItemType Directory -Path $webfontsDir -Force | Out-Null
    }

    Write-LogSuccess "Directories created successfully"
}

# Download a file using appropriate method
function Get-WebResource {
    [CmdletBinding()]
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )

    Write-LogInfo "Downloading $Description..."

    if ($UseWSL) {
        # Download using WSL curl
        $curlCommand = "curl -L `"$Url`" -o `"$OutputPath`""
        try {
            Invoke-WSLCommand -DistroName $WSLDistro -Command $curlCommand
        }
        catch {
            Write-LogError "Failed to download $Description using WSL: $($_.Exception.Message)"
            return $false
        }
    }
    else {
        # Download using Windows
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        }
        catch {
            Write-LogError "Failed to download $Description using Windows: $($_.Exception.Message)"
            return $false
        }
    }

    Write-LogSuccess "Downloaded $Description"
    return $true
}

# Check if a file exists using appropriate method
function Test-ResourceFile {
    [CmdletBinding()]
    param([string]$FilePath)

    if ($UseWSL) {
        # Check file existence using WSL
        $testCommand = "test -f `"$FilePath`""
        try {
            Invoke-WSLCommand -DistroName $WSLDistro -Command $testCommand
            return $LASTEXITCODE -eq 0
        }
        catch {
            return $false
        }
    }
    else {
        # Check file existence using Windows
        return Test-Path $FilePath
    }
}

# Download Bulma CSS
function Get-BulmaCSS {
    [CmdletBinding()]
    param()

    $bulmaPath = "$FinalTargetPath/css/bulma.min.css"
    
    if (-not (Test-ResourceFile -FilePath $bulmaPath)) {
        $bulmaUrl = "https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css"
        Get-WebResource -Url $bulmaUrl -OutputPath $bulmaPath -Description "Bulma CSS"
    }
    else {
        Write-LogInfo "Bulma CSS already exists, skipping download"
    }
}

# Download FontAwesome CSS
function Get-FontAwesomeCSS {
    [CmdletBinding()]
    param()

    $fontAwesomePath = "$FinalTargetPath/css/fontawesome.min.css"
    
    if (-not (Test-ResourceFile -FilePath $fontAwesomePath)) {
        $fontAwesomeUrl = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css"
        Get-WebResource -Url $fontAwesomeUrl -OutputPath $fontAwesomePath -Description "FontAwesome CSS"
    }
    else {
        Write-LogInfo "FontAwesome CSS already exists, skipping download"
    }
}

# Download FontAwesome webfonts
function Get-FontAwesomeWebfonts {
    [CmdletBinding()]
    param()

    $solidFontPath = "$FinalTargetPath/webfonts/fa-solid-900.woff2"
    
    if (-not (Test-ResourceFile -FilePath $solidFontPath)) {
        Write-LogInfo "Downloading FontAwesome webfonts..."
        
        $webfonts = @(
            @{ Url = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/fa-solid-900.woff2"; File = "fa-solid-900.woff2" },
            @{ Url = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/fa-regular-400.woff2"; File = "fa-regular-400.woff2" },
            @{ Url = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/webfonts/fa-brands-400.woff2"; File = "fa-brands-400.woff2" }
        )
        
        foreach ($webfont in $webfonts) {
            $outputPath = "$FinalTargetPath/webfonts/$($webfont.File)"
            Get-WebResource -Url $webfont.Url -OutputPath $outputPath -Description "FontAwesome webfont: $($webfont.File)"
        }
    }
    else {
        Write-LogInfo "FontAwesome webfonts already exist, skipping download"
    }
}

# Set proper permissions (Linux only)
function Set-ResourcePermissions {
    [CmdletBinding()]
    param()

    if ($UseWSL) {
        Write-LogInfo "Setting proper permissions..."
        
        $cssDir = "$FinalTargetPath/css"
        $webfontsDir = "$FinalTargetPath/webfonts"
        
        # Set ownership and permissions using WSL
        $permissionsCommand = @"
sudo chown -R www-data:www-data "$cssDir" "$webfontsDir" 2>/dev/null || echo "Note: Could not set www-data ownership (may not be available)"
chmod -R 755 "$cssDir" "$webfontsDir"
"@
        
        try {
            Invoke-WSLCommand -DistroName $WSLDistro -Command $permissionsCommand
        }
        catch {
            Write-LogWarning "Could not set all permissions (this may be normal in some environments)"
        }
        
        Write-LogSuccess "Permissions set successfully"
    }
    else {
        Write-LogInfo "Skipping permission setting on Windows"
    }
}

# Main execution function
function Invoke-Main {
    [CmdletBinding()]
    param()

    Test-Prerequisites
    New-ResourceDirectories
    Get-BulmaCSS
    Get-FontAwesomeCSS
    Get-FontAwesomeWebfonts
    Set-ResourcePermissions

    Write-Host ""
    Write-LogSuccess "Local resources verified and downloaded if needed"
    Write-LogInfo "Target path: $FinalTargetPath"
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
