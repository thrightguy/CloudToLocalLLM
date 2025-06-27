# CloudToLocalLLM Unified Package Creator (PowerShell)
# Creates multiple package formats for Windows and Linux distributions with comprehensive WSL integration
#
# Unified Package Creation System:
# - Windows Packages: MSI, NSIS, Portable ZIP (native Windows tools)
# - Linux Packages: DEB (Ubuntu WSL-based builds)
# - Multi-Platform Build Architecture with graceful degradation
# - Eliminates redundant build scripts and consolidates package creation
# - Maintains PowerShell orchestration with platform-specific execution environments

[CmdletBinding()]
param(
    # Package Type Selection
    [string[]]$PackageTypes = @('DEB', 'MSI', 'NSIS', 'PortableZip'),

    # Platform-Specific Switches
    [switch]$LinuxOnly,         # Create only Linux packages (DEB)
    [switch]$WindowsOnly,       # Create only Windows packages (MSI, NSIS, PortableZip)
    [switch]$DEBOnly,           # Create only DEB packages
    [switch]$MSIOnly,           # Create only MSI installer
    [switch]$NSISOnly,          # Create only NSIS installer
    [switch]$PortableOnly,      # Create only portable ZIP package

    # Build Control
    [switch]$SkipBuild,         # Skip Flutter build steps
    [switch]$TestOnly,          # Only test existing packages
    [string]$TargetPlatform = 'all',  # 'windows', 'linux', 'all'

    # Environment Configuration
    [string]$WSLDistro,         # Specific WSL distribution to use
    [switch]$AutoInstall,       # Automatically install missing dependencies
    [switch]$SkipDependencyCheck,  # Skip dependency validation

    # GitHub Release Integration
    [switch]$CreateGitHubRelease,   # Create GitHub release with assets
    [switch]$UpdateReleaseDescription,  # Update release description only
    [switch]$ForceRecreateRelease,  # Force recreate existing release

    [switch]$Help               # Show help information
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
$LinuxBuildDir = Join-Path $ProjectRoot "build\linux\x64\release\bundle"
$WindowsBuildDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"

# WSL mount paths for Linux builds (using Convert-WindowsPathToWSL function)
$WSLLinuxBuildDir = "/mnt/c/Users/chris/Dev/CloudToLocalLLM/build/linux/x64/release/bundle"

# Package output directory structure
$LinuxOutputDir = Join-Path $OutputDir "linux"
$WindowsOutputDir = Join-Path $OutputDir "windows"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
$Version = & $versionManagerPath get-semantic

# Resolve package types based on switches
$script:ResolvedPackageTypes = @()
if ($DEBOnly) { $script:ResolvedPackageTypes = @('DEB') }
elseif ($MSIOnly) { $script:ResolvedPackageTypes = @('MSI') }
elseif ($NSISOnly) { $script:ResolvedPackageTypes = @('NSIS') }
elseif ($PortableOnly) { $script:ResolvedPackageTypes = @('PortableZip') }
elseif ($LinuxOnly) { $script:ResolvedPackageTypes = @('DEB') }
elseif ($WindowsOnly) { $script:ResolvedPackageTypes = @('MSI', 'NSIS', 'PortableZip') }
else { $script:ResolvedPackageTypes = $PackageTypes }

# Package type categorization
$script:LinuxPackageTypes = @('DEB')
$script:WindowsPackageTypes = @('MSI', 'NSIS', 'PortableZip')
$script:RequiresLinuxBuild = $script:ResolvedPackageTypes | Where-Object { $_ -in $script:LinuxPackageTypes }
$script:RequiresWindowsBuild = $script:ResolvedPackageTypes | Where-Object { $_ -in $script:WindowsPackageTypes }

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Unified Package Creator (PowerShell)" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Creates multiple package formats for Windows and Linux distributions" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\Create-UnifiedPackages.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Package Type Selection:" -ForegroundColor Yellow
    Write-Host "  -PackageTypes         Array of package types to create (default: all)"
    Write-Host "                        Options: DEB, MSI, NSIS, PortableZip"
    Write-Host "  -LinuxOnly            Create only Linux packages (DEB)"
    Write-Host "  -WindowsOnly          Create only Windows packages (MSI, NSIS, PortableZip)"
    Write-Host "  -DEBOnly              Create only DEB packages"
    Write-Host "  -MSIOnly              Create only MSI installer"
    Write-Host "  -NSISOnly             Create only NSIS installer"
    Write-Host "  -PortableOnly         Create only portable ZIP package"
    Write-Host ""
    Write-Host "Build Control:" -ForegroundColor Yellow
    Write-Host "  -SkipBuild            Skip Flutter build steps"
    Write-Host "  -TestOnly             Only test existing packages"
    Write-Host "  -TargetPlatform       Target platform: 'windows', 'linux', 'all'"
    Write-Host ""
    Write-Host "Environment Configuration:" -ForegroundColor Yellow
    Write-Host "  -WSLDistro            Specify WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host ""
    Write-Host "GitHub Release Integration:" -ForegroundColor Yellow
    Write-Host "  -CreateGitHubRelease         Create GitHub release with assets"
    Write-Host "  -UpdateReleaseDescription    Update release description only"
    Write-Host "  -ForceRecreateRelease        Force recreate existing release"
    Write-Host ""
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  Windows Packages:" -ForegroundColor Cyan
    Write-Host "    - WiX Toolset (for MSI) - auto-installed with -AutoInstall"
    Write-Host "    - NSIS (for NSIS installer) - auto-installed with -AutoInstall"
    Write-Host "    - Flutter SDK for Windows builds"
    Write-Host "  Linux Packages:" -ForegroundColor Cyan
    Write-Host "    - WSL with Ubuntu (for DEB packages)"
    Write-Host "    - Flutter SDK in WSL - auto-installed with -AutoInstall"
    Write-Host "    - Linux build dependencies - auto-installed with -AutoInstall"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Create-UnifiedPackages.ps1                                    # Create all package types"
    Write-Host "  .\Create-UnifiedPackages.ps1 -WindowsOnly -AutoInstall         # Windows packages only"
    Write-Host "  .\Create-UnifiedPackages.ps1 -LinuxOnly -WSLDistro Ubuntu   # Linux packages only"
    Write-Host "  .\Create-UnifiedPackages.ps1 -PackageTypes @('MSI','DEB')      # Specific package types"
    Write-Host "  .\Create-UnifiedPackages.ps1 -MSIOnly -SkipBuild               # MSI only, skip build"
    Write-Host "  .\Create-UnifiedPackages.ps1 -TestOnly                         # Test existing packages"
    exit 0
}

# Check prerequisites for unified package creation
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites for package types: $($script:ResolvedPackageTypes -join ', ')"

    # Install basic build dependencies
    $requiredPackages = @('git')
    if (-not $SkipBuild) {
        $requiredPackages += 'flutter'
    }

    if (-not (Install-BuildDependencies -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck -RequiredPackages $requiredPackages)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Check Windows-specific prerequisites
    if ($script:RequiresWindowsBuild) {
        Test-WindowsPrerequisites
    }

    # Check Linux-specific prerequisites
    if ($script:RequiresLinuxBuild) {
        Test-LinuxPrerequisites
    }

    Write-LogSuccess "Prerequisites check completed"
}

# Note: Using Install-ChocolateyPackage from BuildEnvironmentUtilities.ps1 instead of local implementation

# Helper function to get SHA256 hash
function Get-SHA256Hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}

# Check Windows-specific prerequisites
function Test-WindowsPrerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking Windows package prerequisites..."

    # Check for Windows package types and install required tools
    $windowsTools = @()

    if ('MSI' -in $script:ResolvedPackageTypes) {
        $windowsTools += @{
            Name = 'WiX Toolset'
            Package = 'wixtoolset'
            VerifyCommand = 'candle.exe -?'
            Description = 'Required for MSI installer creation'
        }
    }

    if ('NSIS' -in $script:ResolvedPackageTypes) {
        $windowsTools += @{
            Name = 'NSIS'
            Package = 'nsis'
            VerifyCommand = 'makensis.exe /VERSION'
            Description = 'Required for NSIS installer creation'
        }
    }

    # Install Windows tools if needed
    foreach ($tool in $windowsTools) {
        if (-not (Install-ChocolateyPackage -PackageName $tool.Package -DisplayName $tool.Name -VerifyCommand $tool.VerifyCommand -AutoInstall:$AutoInstall)) {
            Write-LogWarning "Failed to install $($tool.Name) - $($tool.Package) packages will be skipped"
            $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -notin @('MSI', 'NSIS') }
        }
    }

    Write-LogSuccess "Windows prerequisites check completed"
}

# Check Linux-specific prerequisites
function Test-LinuxPrerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking Linux package prerequisites..."

    # Check WSL availability
    if (-not (Test-WSLAvailable)) {
        Write-LogError "WSL is not available on this system"
        Write-LogInfo "Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install"
        Write-LogWarning "All Linux packages will be skipped"
        $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -notin $script:LinuxPackageTypes }
        return
    }

    # Check for Ubuntu WSL (required for DEB packages)
    $debPackages = @('DEB') | Where-Object { $_ -in $script:ResolvedPackageTypes }
    if ($debPackages) {
        # Use specified WSL distribution or get default Ubuntu distribution
        if ($WSLDistro -and -not [string]::IsNullOrWhiteSpace($WSLDistro)) {
            $script:UbuntuDistro = [string]$WSLDistro.Trim()
            Write-LogInfo "Using specified WSL distribution for DEB packages: $script:UbuntuDistro"
        } else {
            Write-LogInfo "No WSL distribution specified, detecting default Ubuntu distribution..."
            $script:UbuntuDistro = Get-DefaultUbuntuDistribution
        }

        # Ensure UbuntuDistro is a string and not null
        if (-not $script:UbuntuDistro -or $script:UbuntuDistro -isnot [string] -or [string]::IsNullOrWhiteSpace($script:UbuntuDistro)) {
            Write-LogWarning "No Ubuntu WSL distribution found - DEB packages will be skipped"
            $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -ne 'DEB' }
        } else {
            Write-LogInfo "Using Ubuntu WSL distribution for DEB packages: $script:UbuntuDistro"

            # Initialize WSL distribution for automated builds
            try {
                if (Initialize-WSLDistribution -DistroName ([string]$script:UbuntuDistro)) {
                    Test-UbuntuDebianTools
                } else {
                    Write-LogWarning "Failed to initialize Ubuntu WSL distribution - some operations may require manual intervention"
                }
            }
            catch {
                Write-LogError "Failed to configure Ubuntu WSL distribution '$script:UbuntuDistro': $($_.Exception.Message)"
                Write-LogWarning "Some operations may require manual intervention"
            }
        }
    }

    Write-LogSuccess "Linux prerequisites check completed"
}

# Test Arch Linux tools and dependencies
function Test-UbuntuDebianTools {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking Ubuntu tools for DEB package creation..."

    # Check required tools in Ubuntu WSL
    $requiredTools = @('dpkg-deb', 'fakeroot', 'lintian')
    foreach ($tool in $requiredTools) {
        if (-not (Test-WSLCommand -DistroName $script:UbuntuDistro -CommandName $tool)) {
            Write-LogError "Required tool not found in Ubuntu WSL: $tool"
            if ($AutoInstall) {
                Write-LogInfo "Installing Debian packaging tools in Ubuntu WSL..."
                Invoke-WSLCommand -DistroName $script:UbuntuDistro -Command "sudo apt-get update && sudo apt-get install -y debhelper dpkg-dev fakeroot devscripts dh-make lintian build-essential"
            } else {
                Write-LogInfo "Install in Ubuntu WSL: sudo apt-get install debhelper dpkg-dev fakeroot devscripts dh-make lintian"
                Write-LogWarning "DEB packages will be skipped"
                $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -ne 'DEB' }
                return
            }
        }
    }

    # Check Flutter SDK in Ubuntu WSL
    if (-not $SkipBuild) {
        Test-WSLFlutterEnvironment -DistroName $script:UbuntuDistro -PackageManager 'apt'
    }

    Write-LogSuccess "Ubuntu Debian packaging tools verified"
}

# Get the default Ubuntu WSL distribution
function Get-DefaultUbuntuDistribution {
    [CmdletBinding()]
    param()

    # Try common Ubuntu distribution names
    $ubuntuCandidates = @('Ubuntu-24.04', 'Ubuntu-22.04', 'Ubuntu-20.04', 'Ubuntu', 'ubuntu')

    try {
        # Verify distributions exist and are available
        $distributions = Get-WSLDistributions
        if (-not $distributions -or $distributions.Count -eq 0) {
            Write-LogWarning "No WSL distributions found"
            return $null
        }

        foreach ($candidate in $ubuntuCandidates) {
            $ubuntuDistro = $distributions | Where-Object { $_.Name -eq $candidate }

            if ($ubuntuDistro) {
                if ($ubuntuDistro.State -ne 'Running') {
                    Write-LogInfo "Starting WSL distribution '$candidate'..."
                    try {
                        $null = & wsl -d $candidate -- echo "WSL distribution started"
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogSuccess "WSL distribution '$candidate' started successfully"
                        } else {
                            Write-LogError "Failed to start WSL distribution '$candidate'"
                            continue
                        }
                    }
                    catch {
                        Write-LogError "Failed to start WSL distribution '$candidate'"
                        continue
                    }
                }

                Write-LogInfo "Using Ubuntu WSL distribution: $candidate"
                return [string]$candidate
            }
        }

        Write-LogError "No Ubuntu WSL distribution found. Please install Ubuntu WSL distribution."
        Write-LogInfo "Install with: wsl --install -d Ubuntu"
        return $null
    }
    catch {
        Write-LogError "Failed to detect Ubuntu WSL distribution: $($_.Exception.Message)"
        return $null
    }
}

# Test Ubuntu Debian packaging tools
function Test-UbuntuDebianTools {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking Ubuntu tools for DEB package creation..."

    # Check required tools in Ubuntu WSL
    $requiredTools = @('dpkg-deb', 'fakeroot', 'lintian')
    foreach ($tool in $requiredTools) {
        if (-not (Test-WSLCommand -DistroName $script:UbuntuDistro -CommandName $tool)) {
            Write-LogError "Required tool not found in Ubuntu WSL: $tool"
            if ($AutoInstall) {
                Write-LogInfo "Installing Debian packaging tools in Ubuntu WSL..."
                Invoke-WSLCommand -DistroName $script:UbuntuDistro -Command "sudo apt update && sudo apt install -y debhelper dpkg-dev fakeroot devscripts dh-make lintian build-essential"
            } else {
                Write-LogInfo "Install in Ubuntu WSL: sudo apt install debhelper dpkg-dev fakeroot devscripts dh-make lintian"
                Write-LogWarning "DEB packages will be skipped"
                $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -ne 'DEB' }
                return
            }
        }
    }

    # Check Flutter SDK in Ubuntu WSL
    if (-not $SkipBuild) {
        Test-WSLFlutterEnvironment -DistroName $script:UbuntuDistro -PackageManager 'apt'
    }

    Write-LogSuccess "Ubuntu Debian packaging tools verified"
}

# Test WSL Flutter environment
function Test-WSLFlutterEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,

        [Parameter(Mandatory = $true)]
        [string]$PackageManager
    )

    Write-LogInfo "Checking Flutter SDK in WSL distribution: $DistroName"

    try {
        # Check for native Linux Flutter first, then fallback to PATH
        $flutterCheck = Invoke-WSLCommand -DistroName $DistroName -Command "test -f /opt/flutter-linux/bin/flutter && echo '/opt/flutter-linux/bin/flutter' || which flutter || echo 'MISSING'" -PassThru
        if ($flutterCheck -eq "MISSING" -or -not $flutterCheck) {
            Write-LogWarning "Flutter SDK not found in WSL distribution: $DistroName"

            if ($AutoInstall) {
                Write-LogInfo "Installing Flutter SDK in WSL..."
                try {
                    # Try snap installation first (most reliable)
                    Invoke-WSLCommand -DistroName $DistroName -Command "sudo snap install flutter --classic"
                    Write-LogSuccess "Flutter SDK installed via snap"
                }
                catch {
                    Write-LogError "Failed to install Flutter SDK via snap"
                    Write-LogInfo "Manual installation required in WSL:"
                    Write-LogInfo "  1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/linux"
                    Write-LogInfo "  2. Extract to /opt/flutter"
                    Write-LogInfo "  3. Add to PATH: export PATH=`$PATH:/opt/flutter/bin"
                    throw "Flutter SDK installation failed"
                }
            }
            else {
                Write-LogError "Flutter SDK is required in WSL for Linux builds"
                Write-LogInfo "Install Flutter in WSL or use -AutoInstall parameter"
                throw "Flutter SDK not available"
            }
        }
        else {
            Write-LogSuccess "Flutter SDK found in WSL: $flutterCheck"
        }

        # Verify Linux build dependencies
        Write-LogInfo "Checking Linux build dependencies in $DistroName..."
        $buildDeps = @()
        if ($PackageManager -eq 'pacman') {
            $buildDeps = @('base-devel', 'cmake', 'ninja', 'pkg-config', 'gtk3')
        } elseif ($PackageManager -eq 'apt') {
            $buildDeps = @('build-essential', 'cmake', 'ninja-build', 'pkg-config', 'libgtk-3-dev')
        }

        $missingDeps = @()
        foreach ($dep in $buildDeps) {
            $depCheckCommand = ""
            if ($PackageManager -eq 'pacman') {
                $depCheckCommand = "pacman -Q $dep"
            } elseif ($PackageManager -eq 'apt') {
                $depCheckCommand = "dpkg -s $dep"
            }

            $depCheck = Invoke-WSLCommand -DistroName $DistroName -Command "$depCheckCommand || echo 'MISSING'" -PassThru

            if ($depCheck -eq "MISSING" -or -not $depCheck) {
                $missingDeps += $dep
            }
        }

        if ($missingDeps.Count -gt 0) {
            Write-LogWarning "Missing Linux build dependencies: $($missingDeps -join ', ')"

            if ($AutoInstall) {
                Write-LogInfo "Installing missing dependencies in $DistroName..."
                $installCmd = ""
                if ($PackageManager -eq 'pacman') {
                    $installCmd = "sudo pacman -S --noconfirm $($missingDeps -join ' ')"
                } elseif ($PackageManager -eq 'apt') {
                    $installCmd = "sudo apt-get update && sudo apt-get install -y $($missingDeps -join ' ')"
                }
                Invoke-WSLCommand -DistroName $DistroName -Command $installCmd
                Write-LogSuccess "Linux build dependencies installed"
            }
            else {
                Write-LogError "Linux build dependencies are required"
                Write-LogInfo "Install in ${DistroName}: sudo $($PackageManager) install $($missingDeps -join ' ')"
                Write-LogInfo "Or use -AutoInstall parameter"
                throw "Build dependencies not available"
            }
        }
        else {
            Write-LogSuccess "All Linux build dependencies are available"
        }
    }
    catch {
        Write-LogError "Failed to verify WSL Flutter environment: $($_.Exception.Message)"
        throw
    }
}

# Build Flutter applications for multiple platforms
function Build-FlutterApps {
    [CmdletBinding()]
    param()

    if ($SkipBuild) {
        Write-LogInfo "Skipping Flutter build as requested"
        return
    }

    Write-LogInfo "Building Flutter applications for required platforms..."

    # Build for Windows if Windows packages are requested
    if ($script:RequiresWindowsBuild) {
        Build-WindowsFlutterApp
    }

    # Build for Linux if Linux packages are requested
    if ($script:RequiresLinuxBuild) {
        Build-LinuxFlutterApp
    }

    Write-LogSuccess "All required Flutter builds completed"
}

# Build Flutter application for Windows
function Build-WindowsFlutterApp {
    [CmdletBinding()]
    param()

    Write-LogInfo "Building Flutter application for Windows..."

    Push-Location $ProjectRoot
    try {
        # Get dependencies
        Write-LogInfo "Running flutter pub get..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get dependencies for Flutter app"
        }

        # Build for Windows
        Write-LogInfo "Running flutter build windows --release..."
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Flutter app for Windows"
        }

        # Verify build output
        $mainExecutable = Join-Path $WindowsBuildDir "cloudtolocalllm.exe"
        if (-not (Test-Path $mainExecutable)) {
            throw "Flutter Windows executable not found after build"
        }

        Write-LogSuccess "Windows Flutter application built successfully"
        Write-LogInfo "Build output available at: $WindowsBuildDir"
    }
    catch {
        Write-LogError "Failed to build Flutter app for Windows: $($_.Exception.Message)"
        throw
    }
    finally {
        Pop-Location
    }
}

# Build Flutter application for Linux using WSL
function Build-LinuxFlutterApp {
    [CmdletBinding()]
    param()

    Write-LogInfo "Building Flutter application for Linux using WSL..."

    # Determine which WSL distribution to use for Linux builds
    $linuxDistro = $null
    if ('DEB' -in $script:ResolvedPackageTypes -and $script:UbuntuDistro) {
        $linuxDistro = $script:UbuntuDistro
        Write-LogInfo "Using Ubuntu WSL distribution for Linux build (DEB package required)"
    }

    if (-not $linuxDistro) {
        throw "No suitable WSL distribution available for Linux builds"
    }

    try {
        # Determine Flutter path (prefer native Linux installation)
        $flutterPath = Invoke-WSLCommand -DistroName $linuxDistro -Command "test -f /opt/flutter-linux/bin/flutter && echo '/opt/flutter-linux/bin/flutter' || which flutter" -PassThru
        if (-not $flutterPath) {
            throw "Flutter SDK not found in WSL distribution"
        }

        # Clean up path to remove any double slashes or trailing slashes
        $flutterPath = $flutterPath.Trim() -replace '/+', '/'

        Write-LogInfo "Using Flutter at: $flutterPath"

        # Get dependencies using WSL Flutter
        Write-LogInfo "Running flutter pub get in WSL ($linuxDistro)..."
        Invoke-WSLCommand -DistroName $linuxDistro -WorkingDirectory $ProjectRoot -Command "$flutterPath pub get"

        # Build for Linux using WSL Flutter with proper environment
        Write-LogInfo "Running flutter build linux --release in WSL ($linuxDistro)..."
        Invoke-WSLCommand -DistroName $linuxDistro -WorkingDirectory $ProjectRoot -Command "PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig $flutterPath build linux --release"

        # Verify build output (using Windows path since files are accessible via mount)
        $mainExecutable = Join-Path $LinuxBuildDir "cloudtolocalllm"
        if (-not (Test-Path $mainExecutable)) {
            throw "Flutter Linux executable not found after WSL build"
        }

        # Verify WSL build output using WSL path
        $wslExecutableCheck = Invoke-WSLCommand -DistroName $linuxDistro -Command "test -f `"$WSLLinuxBuildDir/cloudtolocalllm`" && echo 'EXISTS'" -PassThru
        if ($wslExecutableCheck -ne "EXISTS") {
            throw "Flutter Linux executable not accessible via WSL mount"
        }

        Write-LogSuccess "Linux Flutter application built successfully using WSL"
        Write-LogInfo "Build output available at: $LinuxBuildDir"
        Write-LogInfo "WSL mount path: $WSLLinuxBuildDir"
    }
    catch {
        Write-LogError "Failed to build Flutter app for Linux in WSL: $($_.Exception.Message)"
        Write-LogInfo "Ensure WSL distribution '$linuxDistro' has Flutter SDK and Linux build dependencies"
        throw
    }
}

# Create all requested packages
function New-UnifiedPackages {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating packages: $($script:ResolvedPackageTypes -join ', ')"

    # Create output directory structure
    New-DirectoryIfNotExists -Path $LinuxOutputDir
    New-DirectoryIfNotExists -Path $WindowsOutputDir

    # Track successful and failed packages
    $script:SuccessfulPackages = @()
    $script:FailedPackages = @()

    # Create Linux packages
    $linuxPackagesToCreate = $script:ResolvedPackageTypes | Where-Object { $_ -in $script:LinuxPackageTypes }
    if ($linuxPackagesToCreate) {
        New-LinuxPackages -PackageTypes $linuxPackagesToCreate
    }

    # Create Windows packages
    $windowsPackagesToCreate = $script:ResolvedPackageTypes | Where-Object { $_ -in $script:WindowsPackageTypes }
    if ($windowsPackagesToCreate) {
        New-WindowsPackages -PackageTypes $windowsPackagesToCreate
    }

    # Display summary
    Show-PackageSummary
}

# Create Linux packages
function New-LinuxPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PackageTypes
    )

    Write-LogInfo "Creating Linux packages: $($PackageTypes -join ', ')"

    foreach ($packageType in $PackageTypes) {
        try {
            switch ($packageType) {
                'DEB' {
                    if ($script:UbuntuDistro) {
                        New-DEBPackage
                        $script:SuccessfulPackages += 'DEB'
                    } else {
                        Write-LogWarning "Skipping DEB package - no Ubuntu WSL distribution available"
                        $script:FailedPackages += @{ Package = 'DEB'; Reason = 'No Ubuntu WSL distribution' }
                    }
                }
                default {
                    Write-LogWarning "Unknown Linux package type: $packageType"
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

# Create Windows packages
function New-WindowsPackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PackageTypes
    )

    Write-LogInfo "Creating Windows packages: $($PackageTypes -join ', ')"

    foreach ($packageType in $PackageTypes) {
        try {
            switch ($packageType) {
                'MSI' {
                    New-MSIPackage
                    $script:SuccessfulPackages += 'MSI'
                }
                'NSIS' {
                    New-NSISPackage
                    $script:SuccessfulPackages += 'NSIS'
                }
                'PortableZip' {
                    New-PortableZipPackage
                    $script:SuccessfulPackages += 'PortableZip'
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


Package Type: AUR Binary Package
Architecture: x86_64
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Contents:
- Flutter Linux application (cloudtolocalllm)
- Integrated system tray functionality using tray_manager
- All required libraries and data files

Installation:
This package is designed for AUR (Arch User Repository) installation.
Use: yay -S cloudtolocalllm

For more information, visit:
https://github.com/imrightguy/CloudToLocalLLM
"@ | Set-Content -Path $packageInfo -Encoding UTF8

    # Create archive using WSL with standardized path conversion
    Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $aurOutputDir -Command "tar -czf `"$packageName.tar.gz`" `"$packageName/`""

    # Generate checksum
    $checksumOutput = Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $aurOutputDir -Command "sha256sum `"$packageName.tar.gz`"" -PassThru
    $checksum = ($checksumOutput -split '\s+')[0]

    # Save checksum file
    $checksumFile = Join-Path $aurOutputDir "$packageName.tar.gz.sha256"
    $checksumOutput | Set-Content -Path $checksumFile -Encoding UTF8

    # Update PKGBUILD if it exists
    $aurDir = Join-Path $ProjectRoot "aur-package"
    if (Test-Path $aurDir) {
        Update-AurPackage -Checksum $checksum
    }

    # Cleanup temporary directory
    Remove-Item $packageDir -Recurse -Force

    Write-LogSuccess "AUR package created: $packageName.tar.gz"
}



# Create AppImage package
function New-AppImagePackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating AppImage package..."

    $packageName = "CloudToLocalLLM-$Version-x86_64.AppImage"
    $appImageOutputDir = Join-Path $LinuxOutputDir "appimage"
    New-DirectoryIfNotExists -Path $appImageOutputDir

    # Create AppImage using Arch Linux WSL
    $wslAppImageDir = Convert-WindowsPathToWSL -WindowsPath $appImageOutputDir

    # Create desktop file content
    $desktopFile = @"
[Desktop Entry]
Type=Application
Name=CloudToLocalLLM
Comment=Bridge cloud-hosted web interfaces with local LLM instances
Exec=cloudtolocalllm
Icon=cloudtolocalllm
Categories=Network;Development;
Terminal=false
StartupWMClass=CloudToLocalLLM
"@

    # Create AppImage build script
    $buildScript = @"
#!/bin/bash
set -e

cd "$wslAppImageDir"

# Download linuxdeploy if not exists
if [ ! -f linuxdeploy ]; then
    wget -O linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
    chmod +x linuxdeploy
fi

# Create AppDir structure
rm -rf AppDir
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/pixmaps

# Copy application binary
cp "$WSLLinuxBuildDir/cloudtolocalllm" AppDir/usr/bin/

# Create desktop file
cat > AppDir/usr/share/applications/cloudtolocalllm.desktop << 'EOF'
$desktopFile
EOF

# Create simple icon (placeholder)
convert -size 256x256 xc:blue -fill white -gravity center -pointsize 24 -annotate +0+0 'CTLLM' AppDir/usr/share/pixmaps/cloudtolocalllm.png || echo "Warning: ImageMagick not available, using placeholder icon"

# Build AppImage
./linuxdeploy --appdir AppDir --desktop-file AppDir/usr/share/applications/cloudtolocalllm.desktop --icon-file AppDir/usr/share/pixmaps/cloudtolocalllm.png --output appimage

# Rename to expected filename
if [ -f CloudToLocalLLM-*.AppImage ]; then
    mv CloudToLocalLLM-*.AppImage "$packageName"
fi

# Generate checksum
sha256sum "$packageName" > "$packageName.sha256"

echo "AppImage created: $packageName"
"@

    # Execute build script in Arch Linux WSL
    $tempScript = Join-Path $env:TEMP "build-appimage.sh"

    # Ensure Unix line endings for the script
    $buildScriptUnix = $buildScript -replace "`r`n", "`n" -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempScript, $buildScriptUnix, $utf8NoBom)

    $wslTempScript = Convert-WindowsPathToWSL -WindowsPath $tempScript

    try {
        Invoke-WSLCommand -DistroName $script:ArchDistro -Command "bash $wslTempScript"
        Write-LogSuccess "AppImage package created: $packageName"
    } catch {
        Write-LogError "AppImage creation failed: $($_.Exception.Message)"
        throw
    } finally {
        Remove-Item $tempScript -ErrorAction SilentlyContinue
    }
}

# Create Flatpak package
function New-FlatpakPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating Flatpak package..."

    $packageName = "cloudtolocalllm-$Version.flatpak"
    $flatpakOutputDir = Join-Path $LinuxOutputDir "flatpak"
    New-DirectoryIfNotExists -Path $flatpakOutputDir

    # Create Flatpak manifest and build using WSL
    $manifestFile = Join-Path $flatpakOutputDir "online.cloudtolocalllm.CloudToLocalLLM.yml"
    $flatpakManifest = @"
app-id: online.cloudtolocalllm.CloudToLocalLLM
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: cloudtolocalllm
finish-args:
  - --share=network
  - --share=ipc
  - --socket=x11
  - --socket=wayland
  - --device=dri
  - --filesystem=home
  - --talk-name=org.freedesktop.Notifications
  - --talk-name=org.kde.StatusNotifierWatcher
  - --talk-name=org.ayatana.indicator.application
modules:
  - name: cloudtolocalllm
    buildsystem: simple
    build-commands:
      - install -Dm755 cloudtolocalllm /app/bin/cloudtolocalllm
      - install -Dm644 cloudtolocalllm.desktop /app/share/applications/online.cloudtolocalllm.CloudToLocalLLM.desktop
      - install -Dm644 cloudtolocalllm.png /app/share/icons/hicolor/256x256/apps/online.cloudtolocalllm.CloudToLocalLLM.png
    sources:
      - type: archive
        url: https://github.com/imrightguy/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-$Version-x86_64.tar.gz
        sha256: PLACEHOLDER_SHA256
"@

    Set-Content -Path $manifestFile -Value $flatpakManifest -Encoding UTF8

    # Build Flatpak using WSL (requires flatpak-builder)
    $buildCommand = "flatpak-builder --repo=repo --force-clean build-dir online.cloudtolocalllm.CloudToLocalLLM.yml"

    try {
        if (Test-WSLCommand -DistroName $script:ArchDistro -CommandName "flatpak-builder") {
            Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $flatpakOutputDir -Command $buildCommand
            Write-LogSuccess "Flatpak package created: $packageName"
        } else {
            Write-LogWarning "flatpak-builder not available in WSL. Install with: sudo pacman -S flatpak-builder"
            Write-LogInfo "Flatpak manifest created at: $manifestFile"
        }
    } catch {
        Write-LogWarning "Flatpak build failed: $($_.Exception.Message)"
        Write-LogInfo "Flatpak manifest created at: $manifestFile"
    }
}

# Create DEB package
function New-DEBPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating DEB package..."

    $packageName = "cloudtolocalllm_$Version-1_amd64.deb"
    $debOutputDir = Join-Path $LinuxOutputDir "deb"
    New-DirectoryIfNotExists -Path $debOutputDir

    # Create DEB package using Ubuntu WSL
    $wslDebOutputDir = Convert-WindowsPathToWSL -WindowsPath $debOutputDir
    $wslProjectRoot = Convert-WindowsPathToWSL -WindowsPath $ProjectRoot

    # Create DEB build script
    $buildScript = @"
#!/bin/bash
set -e

cd "$wslProjectRoot"

# Create temporary build directory
BUILD_DIR="/tmp/cloudtolocalllm-deb-build"
rm -rf "\$BUILD_DIR"
mkdir -p "\$BUILD_DIR"

# Copy debian package structure
cp -r packaging/deb/* "\$BUILD_DIR/"

# Copy Flutter Linux build to package structure
mkdir -p "\$BUILD_DIR/usr/bin"
cp -r build/linux/x64/release/bundle/* "\$BUILD_DIR/usr/bin/"

# Rename the main executable
mv "\$BUILD_DIR/usr/bin/cloudtolocalllm" "\$BUILD_DIR/usr/bin/cloudtolocalllm" 2>/dev/null || true

# Copy icon if it exists
if [ -f "assets/icons/app_icon.png" ]; then
    cp "assets/icons/app_icon.png" "\$BUILD_DIR/usr/share/pixmaps/cloudtolocalllm.png"
elif [ -f "linux/cloudtolocalllm.png" ]; then
    cp "linux/cloudtolocalllm.png" "\$BUILD_DIR/usr/share/pixmaps/cloudtolocalllm.png"
fi

# Update control file with correct version and installed size
INSTALLED_SIZE=\$(du -sk "\$BUILD_DIR" | cut -f1)
sed -i "s/Version: .*/Version: $Version/" "\$BUILD_DIR/DEBIAN/control"
sed -i "s/Installed-Size: .*/Installed-Size: \$INSTALLED_SIZE/" "\$BUILD_DIR/DEBIAN/control"

# Set correct permissions
chmod 755 "\$BUILD_DIR/DEBIAN/postinst"
chmod 755 "\$BUILD_DIR/DEBIAN/postrm"
chmod 755 "\$BUILD_DIR/usr/bin/cloudtolocalllm"

# Build the DEB package
cd "\$BUILD_DIR/.."
dpkg-deb --build cloudtolocalllm-deb-build "$wslDebOutputDir/$packageName"

# Verify the package
if [ -f "$wslDebOutputDir/$packageName" ]; then
    echo "DEB package created successfully: $packageName"
    lintian "$wslDebOutputDir/$packageName" || echo "Lintian warnings (non-critical)"
else
    echo "Failed to create DEB package"
    exit 1
fi

# Cleanup
rm -rf "\$BUILD_DIR"
"@

    # Write build script to temporary file with Unix line endings
    $tempScript = Join-Path $env:TEMP "build-deb.sh"

    # Ensure Unix line endings for the script
    $buildScriptUnix = $buildScript -replace "`r`n", "`n" -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempScript, $buildScriptUnix, $utf8NoBom)

    $wslTempScript = Convert-WindowsPathToWSL -WindowsPath $tempScript

    try {
        Invoke-WSLCommand -DistroName $script:UbuntuDistro -Command "bash $wslTempScript"
        Write-LogSuccess "DEB package created: $packageName"
    } catch {
        Write-LogError "DEB package creation failed: $($_.Exception.Message)"
        throw
    } finally {
        Remove-Item $tempScript -ErrorAction SilentlyContinue
    }
}

# Create MSI package
function New-MSIPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating MSI package..."

    # Note: MSI creation typically doesn't require admin privileges for compilation
    # Only installation of the MSI requires admin privileges

    $packageName = "CloudToLocalLLM-$Version-x64.msi"
    $msiOutputDir = Join-Path $WindowsOutputDir "msi"
    New-DirectoryIfNotExists -Path $msiOutputDir

    # Verify Windows build exists
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build output not found at $WindowsBuildDir"
    }

    # Verify all required files exist
    $requiredFiles = @(
        @{ Path = "cloudtolocalllm.exe"; Critical = $true },
        @{ Path = "flutter_windows.dll"; Critical = $true },
        @{ Path = "icudtl.dat"; Critical = $true },
        @{ Path = "data\app.so"; Critical = $true }
    )

    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $WindowsBuildDir $file.Path
        if (-not (Test-Path $filePath)) {
            if ($file.Critical) {
                $missingFiles += $file.Path
            } else {
                Write-LogWarning "Optional file missing: $($file.Path)"
            }
        } else {
            Write-LogInfo "Found required file: $($file.Path)"
        }
    }

    if ($missingFiles.Count -gt 0) {
        throw "Critical files missing from Windows build: $($missingFiles -join ', '). Run 'flutter build windows --release' first."
    }

    # Check for data directory
    $dataDir = Join-Path $WindowsBuildDir "data"
    if (-not (Test-Path $dataDir)) {
        throw "Required data directory missing: $dataDir"
    }

    # Check if flutter_assets directory exists and prepare heat harvesting
    $flutterAssetsDir = Join-Path $WindowsBuildDir "data\flutter_assets"
    $includeFlutterAssetsGroup = Test-Path $flutterAssetsDir

    # Create WiX source file
    $wixSource = Join-Path $env:TEMP "CloudToLocalLLM.wxs"
    $productId = [System.Guid]::NewGuid().ToString()
    $upgradeCode = "12345678-1234-1234-1234-123456789012" # Fixed upgrade code for upgrades

    # Build feature component references
    $featureRefs = @(
        "      <ComponentGroupRef Id=`"ProductComponents`" />",
        "      <ComponentGroupRef Id=`"FlutterRuntime`" />"
    )

    if ($includeFlutterAssetsGroup) {
        $featureRefs += "      <ComponentGroupRef Id=`"FlutterAssets`" />"
        $featureRefs += "      <ComponentGroupRef Id=`"FlutterAssetsGroup`" />"
    }

    @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="$productId" Name="CloudToLocalLLM" Language="1033" Version="$Version" Manufacturer="CloudToLocalLLM Team" UpgradeCode="$upgradeCode">
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perUser" />

    <MajorUpgrade DowngradeErrorMessage="A newer version of [ProductName] is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Feature Id="ProductFeature" Title="CloudToLocalLLM" Level="1">
$($featureRefs -join "`n")
    </Feature>
  </Product>

  <Fragment>
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="LocalAppDataFolder">
        <Directory Id="INSTALLFOLDER" Name="CloudToLocalLLM">
          <Directory Id="DATAFOLDER" Name="data">
            <Directory Id="FLUTTERASSETSFOLDER" Name="flutter_assets" />
          </Directory>
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="CloudToLocalLLM"/>
      </Directory>
    </Directory>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
      <Component Id="MainExecutable" Guid="*">
        <File Id="CloudToLocalLLMExe" Source="$WindowsBuildDir\cloudtolocalllm.exe" KeyPath="yes" />
        <Shortcut Id="ApplicationStartMenuShortcut"
                  Name="CloudToLocalLLM"
                  Description="Bridge cloud-hosted web interfaces with local LLM instances"
                  Target="[#CloudToLocalLLMExe]"
                  WorkingDirectory="INSTALLFOLDER"
                  Directory="ApplicationProgramsFolder" />
        <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall"/>
        <RegistryValue Root="HKCU" Key="Software\CloudToLocalLLM" Name="installed" Type="integer" Value="1" KeyPath="no"/>
      </Component>
    </ComponentGroup>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="FlutterRuntime" Directory="INSTALLFOLDER">
      <Component Id="FlutterDLL" Guid="*">
        <File Id="FlutterWindowsDLL" Source="$WindowsBuildDir\flutter_windows.dll" />
      </Component>
      <Component Id="ICUData" Guid="*">
        <File Id="ICUDataFile" Source="$WindowsBuildDir\icudtl.dat" />
      </Component>
    </ComponentGroup>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="FlutterAssets" Directory="DATAFOLDER">
      <Component Id="FlutterAssetsComponent" Guid="*">
        <File Id="AppSO" Source="$WindowsBuildDir\data\app.so" />
        <CreateFolder />
      </Component>
    </ComponentGroup>
  </Fragment>
</Wix>
"@ | Set-Content -Path $wixSource -Encoding UTF8

    try {
        # Find WiX tools - check multiple possible locations
        $wixPaths = @(
            "C:\Program Files (x86)\WiX Toolset v3.14\bin",
            "C:\Program Files (x86)\WiX Toolset v3.11\bin",
            "C:\Program Files\WiX Toolset v3.14\bin",
            "C:\Program Files\WiX Toolset v3.11\bin"
        )

        $candleExe = $null
        $lightExe = $null

        foreach ($wixPath in $wixPaths) {
            $testCandle = Join-Path $wixPath "candle.exe"
            $testLight = Join-Path $wixPath "light.exe"
            if ((Test-Path $testCandle) -and (Test-Path $testLight)) {
                $candleExe = $testCandle
                $lightExe = $testLight
                Write-LogInfo "Found WiX tools at: $wixPath"
                break
            }
        }

        if (-not $candleExe) {
            throw "WiX Toolset not found. Please install WiX Toolset v3.11 or v3.14."
        }

        # Generate heat file for flutter_assets if directory exists
        $heatWxs = Join-Path $env:TEMP "FlutterAssets.wxs"
        $heatObj = Join-Path $env:TEMP "FlutterAssets.wixobj"

        if ($includeFlutterAssetsGroup) {
            Write-LogInfo "Harvesting flutter_assets directory with heat.exe..."
            $heatExe = Join-Path (Split-Path $candleExe) "heat.exe"

            if (Test-Path $heatExe) {
                & $heatExe dir $flutterAssetsDir -cg FlutterAssetsGroup -gg -scom -sreg -sfrag -srd -dr FLUTTERASSETSFOLDER -out $heatWxs
                if ($LASTEXITCODE -eq 0) {
                    Write-LogInfo "Compiling heat-generated WiX source..."
                    & $candleExe -out $heatObj $heatWxs
                    if ($LASTEXITCODE -ne 0) {
                        Write-LogWarning "Heat compilation failed, continuing without flutter_assets"
                        $heatObj = $null
                    }
                } else {
                    Write-LogWarning "Heat harvesting failed, continuing without flutter_assets"
                    $heatObj = $null
                }
            } else {
                Write-LogWarning "Heat.exe not found, flutter_assets will not be included"
                $heatObj = $null
            }
        } else {
            Write-LogWarning "Flutter assets directory not found: $flutterAssetsDir"
            $heatObj = $null
        }

        Write-LogInfo "Compiling WiX source with candle.exe..."
        # Compile with candle
        $wixObj = Join-Path $env:TEMP "CloudToLocalLLM.wixobj"
        & $candleExe -out $wixObj $wixSource
        if ($LASTEXITCODE -ne 0) {
            throw "WiX candle compilation failed with exit code $LASTEXITCODE"
        }

        Write-LogInfo "Linking MSI with light.exe..."
        # Link with light - include heat object if available
        $msiPath = Join-Path $msiOutputDir $packageName
        $lightArgs = @("-out", $msiPath, $wixObj, "-sice:ICE64", "-sice:ICE91")

        if ($heatObj -and (Test-Path $heatObj)) {
            Write-LogInfo "Including flutter_assets in MSI..."
            $lightArgs += $heatObj
        }

        & $lightExe $lightArgs
        if ($LASTEXITCODE -ne 0) {
            throw "WiX light linking failed with exit code $LASTEXITCODE"
        }

        # Validate MSI was created successfully
        if (-not (Test-Path $msiPath)) {
            throw "MSI file was not created: $msiPath"
        }

        $msiInfo = Get-Item $msiPath
        if ($msiInfo.Length -lt 1MB) {
            Write-LogWarning "MSI file seems unusually small: $($msiInfo.Length) bytes"
        }

        Write-LogInfo "MSI package size: $([math]::Round($msiInfo.Length / 1MB, 2)) MB"

        # Generate checksum
        $checksum = Get-SHA256Hash -FilePath $msiPath
        "$checksum  $packageName" | Set-Content -Path "$msiPath.sha256" -Encoding UTF8

        Write-LogSuccess "MSI package created successfully: $packageName"
        Write-LogInfo "MSI location: $msiPath"
    }
    finally {
        # Cleanup temporary files
        if (Test-Path $wixSource) { Remove-Item $wixSource -ErrorAction SilentlyContinue }
        if (Test-Path $wixObj) { Remove-Item $wixObj -ErrorAction SilentlyContinue }
        if ($heatWxs -and (Test-Path $heatWxs)) { Remove-Item $heatWxs -ErrorAction SilentlyContinue }
        if ($heatObj -and (Test-Path $heatObj)) { Remove-Item $heatObj -ErrorAction SilentlyContinue }
    }
}

# Create NSIS package
function New-NSISPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating NSIS package..."

    # Note: NSIS creation typically doesn't require admin privileges for compilation
    # Only installation of the NSIS installer requires admin privileges

    $packageName = "CloudToLocalLLM-$Version-Setup.exe"
    $nsisOutputDir = Join-Path $WindowsOutputDir "nsis"
    New-DirectoryIfNotExists -Path $nsisOutputDir

    # Verify Windows build exists
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build output not found at $WindowsBuildDir"
    }

    # Create NSIS script
    $nsisScript = Join-Path $env:TEMP "CloudToLocalLLM.nsi"
    @"
!define APPNAME "CloudToLocalLLM"
!define COMPANYNAME "CloudToLocalLLM Team"
!define DESCRIPTION "Bridge cloud-hosted web interfaces with local LLM instances"
!define VERSIONMAJOR 3
!define VERSIONMINOR 6
!define VERSIONBUILD 0
!define HELPURL "https://github.com/imrightguy/CloudToLocalLLM"
!define UPDATEURL "https://cloudtolocalllm.online"
!define ABOUTURL "https://cloudtolocalllm.online"
!define INSTALLSIZE 50000

RequestExecutionLevel admin
InstallDir "`$PROGRAMFILES\`${APPNAME}"
Name "`${APPNAME}"
outFile "$nsisOutputDir\$packageName"

page directory
page instfiles

section "install"
    setOutPath `$INSTDIR
    file "$WindowsBuildDir\cloudtolocalllm.exe"

    writeUninstaller "`$INSTDIR\uninstall.exe"

    createDirectory "`$SMPROGRAMS\`${APPNAME}"
    createShortCut "`$SMPROGRAMS\`${APPNAME}\`${APPNAME}.lnk" "`$INSTDIR\cloudtolocalllm.exe"
    createShortCut "`$DESKTOP\`${APPNAME}.lnk" "`$INSTDIR\cloudtolocalllm.exe"

    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "DisplayName" "`${APPNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "UninstallString" "`$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "InstallLocation" "`$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "Publisher" "`${COMPANYNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "HelpLink" "`${HELPURL}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "URLUpdateInfo" "`${UPDATEURL}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "URLInfoAbout" "`${ABOUTURL}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "DisplayVersion" "$Version"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}" "EstimatedSize" `${INSTALLSIZE}
sectionEnd

section "uninstall"
    delete "`$INSTDIR\cloudtolocalllm.exe"
    delete "`$INSTDIR\uninstall.exe"
    rmDir "`$INSTDIR"

    delete "`$SMPROGRAMS\`${APPNAME}\`${APPNAME}.lnk"
    rmDir "`$SMPROGRAMS\`${APPNAME}"
    delete "`$DESKTOP\`${APPNAME}.lnk"

    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APPNAME}"
sectionEnd
"@ | Set-Content -Path $nsisScript -Encoding UTF8

    try {
        # Find NSIS tools
        $nsisPath = "C:\Program Files (x86)\NSIS"
        $makensisExe = Join-Path $nsisPath "makensis.exe"

        if (-not (Test-Path $makensisExe)) {
            throw "NSIS makensis.exe not found at $makensisExe. Please install NSIS."
        }

        # Compile with makensis
        & $makensisExe $nsisScript
        if ($LASTEXITCODE -ne 0) {
            throw "NSIS compilation failed"
        }

        # Generate checksum
        $installerPath = Join-Path $nsisOutputDir $packageName
        $checksum = Get-SHA256Hash -FilePath $installerPath
        "$checksum  $packageName" | Set-Content -Path "$installerPath.sha256" -Encoding UTF8

        Write-LogSuccess "NSIS package created: $packageName"
    }
    finally {
        # Cleanup temporary files
        if (Test-Path $nsisScript) { Remove-Item $nsisScript }
    }
}

# Create Portable ZIP package
function New-PortableZipPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating Portable ZIP package..."

    $packageName = "CloudToLocalLLM-$Version-Portable.zip"
    $portableOutputDir = Join-Path $WindowsOutputDir "portable"
    New-DirectoryIfNotExists -Path $portableOutputDir

    # Verify Windows build exists
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build output not found at $WindowsBuildDir"
    }

    # Create temporary portable directory
    $tempPortableDir = Join-Path $env:TEMP "CloudToLocalLLM-Portable"
    if (Test-Path $tempPortableDir) {
        Remove-Item $tempPortableDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempPortableDir | Out-Null

    try {
        # Copy Windows build output
        Copy-Item "$WindowsBuildDir\*" $tempPortableDir -Recurse -Force

        # Create launcher script
        $launcherScript = Join-Path $tempPortableDir "CloudToLocalLLM-Portable.bat"
        @"
@echo off
REM CloudToLocalLLM Portable Launcher
REM Sets up portable environment and launches the application

set SCRIPT_DIR=%~dp0
set APP_DIR=%SCRIPT_DIR%
set DATA_DIR=%SCRIPT_DIR%data

REM Create data directory if it doesn't exist
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

REM Set environment variables for portable mode
set CLOUDTOLOCALLLM_PORTABLE=1
set CLOUDTOLOCALLLM_DATA_DIR=%DATA_DIR%

REM Launch the application
"%APP_DIR%\cloudtolocalllm.exe" %*
"@ | Set-Content -Path $launcherScript -Encoding ASCII

        # Create README for portable usage
        $readmeFile = Join-Path $tempPortableDir "README.txt"
        @"
CloudToLocalLLM v$Version - Portable Edition
==========================================

This is a portable version of CloudToLocalLLM that can be run from any location
without installation.

Quick Start:
1. Extract this ZIP file to any folder
2. Run CloudToLocalLLM-Portable.bat to start the application
3. All data will be stored in the 'data' subfolder

Features:
- No installation required
- Self-contained with all dependencies
- Portable data storage
- System tray integration
- Local LLM connection management

Requirements:
- Windows 10 version 1903 or later
- Visual C++ Redistributable (usually pre-installed)

For more information, visit:
https://github.com/imrightguy/CloudToLocalLLM

Support:
https://cloudtolocalllm.online
"@ | Set-Content -Path $readmeFile -Encoding UTF8

        # Create ZIP archive
        $zipPath = Join-Path $portableOutputDir $packageName
        Compress-Archive -Path "$tempPortableDir\*" -DestinationPath $zipPath -Force

        # Generate checksum
        $checksum = Get-SHA256Hash -FilePath $zipPath
        "$checksum  $packageName" | Set-Content -Path "$zipPath.sha256" -Encoding UTF8

        Write-LogSuccess "Portable ZIP package created: $packageName"
    }
    finally {
        # Cleanup temporary directory
        if (Test-Path $tempPortableDir) {
            Remove-Item $tempPortableDir -Recurse -Force
        }
    }
}

# Display package creation summary
function Show-PackageSummary {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "CloudToLocalLLM Unified Package Creation Summary" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""

    if ($script:SuccessfulPackages.Count -gt 0) {
        Write-Host "[SUCCESS] Successfully created packages:" -ForegroundColor Green
        foreach ($package in $script:SuccessfulPackages) {
            Write-Host "  ✅ $package" -ForegroundColor Green
        }
        Write-Host ""
    }

    if ($script:FailedPackages.Count -gt 0) {
        Write-Host "[FAILED] Failed to create packages:" -ForegroundColor Red
        foreach ($failure in $script:FailedPackages) {
            Write-Host "  ❌ $($failure.Package): $($failure.Reason)" -ForegroundColor Red
        }
        Write-Host ""
    }

    # Show package locations
    Write-Host "[LOCATIONS] Package output directories:" -ForegroundColor Blue
    if (Test-Path $LinuxOutputDir) {
        Write-Host "  Linux packages: $LinuxOutputDir" -ForegroundColor Blue
        Get-ChildItem $LinuxOutputDir -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Replace($LinuxOutputDir, "").TrimStart('\')
            Write-Host "    • $relativePath" -ForegroundColor Gray
        }
    }
    if (Test-Path $WindowsOutputDir) {
        Write-Host "  Windows packages: $WindowsOutputDir" -ForegroundColor Blue
        Get-ChildItem $WindowsOutputDir -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Replace($WindowsOutputDir, "").TrimStart('\')
            Write-Host "    • $relativePath" -ForegroundColor Gray
        }
    }
    Write-Host ""

    # Show next steps
    Write-Host "[NEXT STEPS]" -ForegroundColor Yellow
    Write-Host "1. Test packages on target platforms" -ForegroundColor Yellow
    Write-Host "2. Upload to GitHub releases" -ForegroundColor Yellow
    Write-Host "3. Update package repositories (AUR, etc.)" -ForegroundColor Yellow
    Write-Host "4. Deploy to VPS using deploy_vps.ps1" -ForegroundColor Yellow
    Write-Host ""

    # Determine exit code
    if ($script:FailedPackages.Count -eq 0) {
        Write-Host "[RESULT] All requested packages created successfully! 🎉" -ForegroundColor Green
        return 0
    } elseif ($script:SuccessfulPackages.Count -gt 0) {
        Write-Host "[RESULT] Partial success - some packages created, some failed" -ForegroundColor Yellow
        return 1
    } else {
        Write-Host "[RESULT] All package creation failed" -ForegroundColor Red
        return 2
    }
}

# Test unified package integrity
function Test-UnifiedPackageIntegrity {
    [CmdletBinding()]
    param()

    if ($script:SuccessfulPackages.Count -eq 0) {
        Write-LogWarning "No packages were created successfully - skipping integrity tests"
        return
    }

    Write-LogInfo "Testing package integrity for created packages..."

    foreach ($packageType in $script:SuccessfulPackages) {
        try {
            switch ($packageType) {
                'AUR' {
                    $aurDir = Join-Path $LinuxOutputDir "aur"
                    $aurPackage = Get-ChildItem $aurDir -Filter "*.tar.gz" | Select-Object -First 1
                    if ($aurPackage) {
                        Write-LogInfo "Testing AUR package: $($aurPackage.Name)"
                        # Basic file existence test
                        if ($aurPackage.Length -gt 0) {
                            Write-LogSuccess "AUR package integrity test passed"
                        } else {
                            Write-LogError "AUR package is empty"
                        }
                    }
                }

                'MSI' {
                    $msiDir = Join-Path $WindowsOutputDir "msi"
                    $msiPackage = Get-ChildItem $msiDir -Filter "*.msi" | Select-Object -First 1
                    if ($msiPackage) {
                        Write-LogInfo "Testing MSI package: $($msiPackage.Name)"
                        if ($msiPackage.Length -gt 0) {
                            Write-LogSuccess "MSI package integrity test passed"
                        } else {
                            Write-LogError "MSI package is empty"
                        }
                    }
                }
                'NSIS' {
                    $nsisDir = Join-Path $WindowsOutputDir "nsis"
                    $nsisPackage = Get-ChildItem $nsisDir -Filter "*.exe" | Select-Object -First 1
                    if ($nsisPackage) {
                        Write-LogInfo "Testing NSIS package: $($nsisPackage.Name)"
                        if ($nsisPackage.Length -gt 0) {
                            Write-LogSuccess "NSIS package integrity test passed"
                        } else {
                            Write-LogError "NSIS package is empty"
                        }
                    }
                }
                'PortableZip' {
                    $portableDir = Join-Path $WindowsOutputDir "portable"
                    $portablePackage = Get-ChildItem $portableDir -Filter "*.zip" | Select-Object -First 1
                    if ($portablePackage) {
                        Write-LogInfo "Testing Portable ZIP package: $($portablePackage.Name)"
                        if ($portablePackage.Length -gt 0) {
                            Write-LogSuccess "Portable ZIP package integrity test passed"
                        } else {
                            Write-LogError "Portable ZIP package is empty"
                        }
                    }
                }
                default {
                    Write-LogInfo "Integrity test not implemented for package type: $packageType"
                }
            }
        }
        catch {
            Write-LogError "Integrity test failed for $packageType package: $($_.Exception.Message)"
        }
    }

    Write-LogSuccess "Package integrity testing completed"
}

# Update AUR PKGBUILD and .SRCINFO files using WSL
function Update-AurPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Checksum
    )

    Write-LogInfo "Updating AUR PKGBUILD and .SRCINFO files using WSL..."

    $aurDir = Join-Path $ProjectRoot "aur-package"
    $pkgbuildFile = Join-Path $aurDir "PKGBUILD"

    if (-not (Test-Path $aurDir)) {
        Write-LogWarning "AUR package directory not found: $aurDir"
        return
    }

    if (-not (Test-Path $pkgbuildFile)) {
        Write-LogWarning "PKGBUILD not found: $pkgbuildFile"
        return
    }

    try {
        Write-LogInfo "Updating PKGBUILD version to $Version..."
        # Update pkgver in PKGBUILD
        $pkgbuildContent = Get-Content $pkgbuildFile
        $updatedContent = $pkgbuildContent | ForEach-Object {
            if ($_ -match '^pkgver=') {
                "pkgver=$Version"
            }
            else {
                $_
            }
        }
        # Write updated content back to file with Unix line endings
        $updatedContent = $updatedContent -replace "`r`n", "`n" -replace "`r", "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($pkgbuildFile, $updatedContent, $utf8NoBom)

        Write-LogInfo "Updating PKGBUILD SHA256 checksum..."
        # Update SHA256 checksum in PKGBUILD
        $pkgbuildContent = Get-Content $pkgbuildFile
        $inSha256Section = $false
        $updatedContent = $pkgbuildContent | ForEach-Object {
            if ($_ -match '^sha256sums=\(') {
                $inSha256Section = $true
                $_
            }
            elseif ($inSha256Section -and $_ -match '^\s*\)') {
                $inSha256Section = $false
                $_
            }
            elseif ($inSha256Section -and $_ -match "'[a-f0-9]{64}'") {
                $_ -replace "'[a-f0-9]{64}'", "'$Checksum'"
            }
            else {
                $_
            }
        }
        # Write updated content back to file with Unix line endings
        $updatedContent = $updatedContent -replace "`r`n", "`n" -replace "`r", "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($pkgbuildFile, $updatedContent, $utf8NoBom)

        Write-LogInfo "Regenerating .SRCINFO using WSL..."
        # Change to AUR directory and regenerate .SRCINFO using WSL
        $aurDir = Join-Path $ProjectRoot "aur-package"
        Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $aurDir -Command "makepkg --printsrcinfo > .SRCINFO"

        Write-LogInfo "Validating updated checksums..."
        # Verify the checksum was updated correctly
        $pkgbuildContent = Get-Content $pkgbuildFile -Raw
        if ($pkgbuildContent -match "'([a-f0-9]{64})'") {
            $pkgbuildChecksum = $matches[1]
            if ($pkgbuildChecksum -ne $Checksum) {
                Write-LogError "Checksum validation failed. PKGBUILD: $pkgbuildChecksum, Expected: $Checksum"
                throw "PKGBUILD checksum validation failed"
            }
        }

        Write-LogSuccess "AUR PKGBUILD and .SRCINFO updated successfully"
        Write-LogInfo "Version: $Version"
        Write-LogInfo "SHA256: $Checksum"
    }
    catch {
        Write-LogError "Failed to update AUR package: $($_.Exception.Message)"
        throw
    }
}

# GitHub Release Integration
function Invoke-GitHubReleaseIntegration {
    [CmdletBinding()]
    param()

    Write-LogInfo "Starting GitHub Release Integration..."

    # Import the GitHub release asset management script
    $githubReleaseScript = Join-Path $PSScriptRoot "..\build\Build-GitHubReleaseAssets.ps1"
    if (-not (Test-Path $githubReleaseScript)) {
        Write-LogError "GitHub Release Asset script not found: $githubReleaseScript"
        throw "GitHub Release Asset Management script not available"
    }

    try {
        # Prepare parameters for GitHub release script
        $githubParams = @{
            'PackageTypes' = 'all'
            'SkipBuild' = $true  # We already built packages
            'UploadOnly' = $true
            'VerboseOutput' = $VerboseOutput
        }

        if ($CreateGitHubRelease) {
            $githubParams['CreateGitHubRelease'] = $true
        }

        if ($UpdateReleaseDescription) {
            $githubParams['UpdateReleaseDescription'] = $true
        }

        if ($ForceRecreateRelease) {
            $githubParams['ForceRecreateRelease'] = $true
        }

        if ($AutoInstall) {
            $githubParams['AutoInstall'] = $true
        }

        if ($SkipDependencyCheck) {
            $githubParams['SkipDependencyCheck'] = $true
        }

        # Execute GitHub release asset management
        Write-LogInfo "Executing GitHub Release Asset Management..."
        & $githubReleaseScript @githubParams

        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "GitHub Release Integration completed successfully"
        } else {
            Write-LogError "GitHub Release Integration failed (exit code: $LASTEXITCODE)"
            throw "GitHub Release Asset Management failed"
        }
    }
    catch {
        Write-LogError "GitHub Release Integration failed: $($_.Exception.Message)"
        throw
    }
}

# Main execution
function Invoke-Main {
    [CmdletBinding()]
    param()

    Write-Host "CloudToLocalLLM Unified Package Creator (PowerShell)" -ForegroundColor Blue
    Write-Host "====================================================" -ForegroundColor Blue
    Write-Host "Version: $Version" -ForegroundColor White
    Write-Host "Package Types: $($script:ResolvedPackageTypes -join ', ')" -ForegroundColor White
    Write-Host "Output Directory: $OutputDir" -ForegroundColor White
    Write-Host ""

    if ($TestOnly) {
        Test-UnifiedPackageIntegrity
        return
    }

    # Execute unified package creation workflow
    try {
        Test-Prerequisites
        Build-FlutterApps
        New-UnifiedPackages
        Test-UnifiedPackageIntegrity

        # GitHub Release Integration
        if ($CreateGitHubRelease -or $UpdateReleaseDescription) {
            Invoke-GitHubReleaseIntegration
        }

        # Return appropriate exit code
        $exitCode = Show-PackageSummary
        exit $exitCode
    }
    catch {
        Write-LogError "Package creation failed: $($_.Exception.Message)"
        Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
        exit 2
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

</final_file_content>

IMPORTANT: For any future changes to this file, use the final_file_content shown above as your reference. This content reflects the current state of the file, including any auto-formatting (e.g., if you used single quotes but the formatter converted them to double quotes). Always base your SEARCH/REPLACE operations on this final version to ensure accuracy.



New problems detected after saving the file:
scripts/powershell/Create-UnifiedPackages.ps1
- [PowerShell Error] Line 740: Missing expression after unary operator '-'.
- [PowerShell Error] Line 740: Unexpected token 'Flutter' in expression or statement.
- [PowerShell Error] Line 741: Missing expression after unary operator '-'.
- [PowerShell Error] Line 741: Unexpected token 'Integrated' in expression or statement.
- [PowerShell Error] Line 742: Missing expression after unary operator '-'.
- [PowerShell Error] Line 742: Unexpected token 'All' in expression or statement.
- [PowerShell Error] Line 748: Missing opening '(' after keyword 'for'.
- [PowerShell Error] Line 753: Unexpected token 'tar' in expression or statement.
- [PowerShell Error] Line 793: Missing ] at end of attribute or type literal.
- [PowerShell Error] Line 793: Unexpected token 'Entry]' in expression or statement.
- [PowerShell Error] Line 812: Missing '(' after 'if' in if statement.
- [PowerShell Error] Line 812: Missing type name after '['.
- [PowerShell Error] Line 827: Missing file specification after redirection operator.
- [PowerShell Error] Line 827: The '<' operator is reserved for future use.
- [PowerShell Error] Line 827: The '<' operator is reserved for future use.
- [PowerShell Error] Line 838: Missing '(' after 'if' in if statement.
- [PowerShell Error] Line 838: Missing type name after '['.
- [PowerShell Error] Line 849: Unexpected token 'build-appimage.sh"

    # Ensure Unix line endings for the script
    $buildScriptUnix = $buildScript -replace "`r`n", "`n" -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempScript, $buildScriptUnix, $utf8NoBom)

    $wslTempScript = Convert-WindowsPathToWSL -WindowsPath $tempScript

    try {
        Invoke-WSLCommand -DistroName $script:ArchDistro -Command "bash' in expression or statement.
- [PowerShell Error] Line 889: Missing expression after unary operator '--'.
- [PowerShell Error] Line 889: Unexpected token 'share=network' in expression or statement.
- [PowerShell Error] Line 890: Missing expression after unary operator '--'.
- [PowerShell Error] Line 890: Unexpected token 'share=ipc' in expression or statement.
- [PowerShell Error] Line 891: Missing expression after unary operator '--'.
- [PowerShell Error] Line 891: Unexpected token 'socket=x11' in expression or statement.
- [PowerShell Error] Line 892: Missing expression after unary operator '--'.
- [PowerShell Error] Line 892: Unexpected token 'socket=wayland' in expression or statement.
- [PowerShell Error] Line 893: Missing expression after unary operator '--'.
- [PowerShell Error] Line 893: Unexpected token 'device=dri' in expression or statement.
- [PowerShell Error] Line 894: Missing expression after unary operator '--'.
- [PowerShell Error] Line 894: Unexpected token 'filesystem=home' in expression or statement.
- [PowerShell Error] Line 895: Missing expression after unary operator '--'.
- [PowerShell Error] Line 895: Unexpected token 'talk-name=org.freedesktop.Notifications' in expression or statement.
- [PowerShell Error] Line 896: Missing expression after unary operator '--'.
- [PowerShell Error] Line 896: Unexpected token 'talk-name=org.kde.StatusNotifierWatcher' in expression or statement.
- [PowerShell Error] Line 897: Missing expression after unary operator '--'.
- [PowerShell Error] Line 897: Unexpected token 'talk-name=org.ayatana.indicator.application' in expression or statement.
- [PowerShell Error] Line 899: Missing expression after unary operator '-'.
- [PowerShell Error] Line 899: Unexpected token 'name:' in expression or statement.
- [PowerShell Error] Line 902: Missing expression after unary operator '-'.
- [PowerShell Error] Line 902: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 903: Missing expression after unary operator '-'.
- [PowerShell Error] Line 903: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 904: Missing expression after unary operator '-'.
- [PowerShell Error] Line 904: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 906: Missing expression after unary operator '-'.
- [PowerShell Error] Line 906: Unexpected token 'type:' in expression or statement.
- [PowerShell Error] Line 914: Unexpected token 'flatpak-builder' in expression or statement.
- [PowerShell Error] Line 969: Unexpected token '}' in expression or statement.
- [PowerShell Error] Line 1132: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1132: Unexpected token 'Flutter' in expression or statement.
- [PowerShell Error] Line 1133: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1133: Unexpected token 'Integrated' in expression or statement.
- [PowerShell Error] Line 1134: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1134: Unexpected token 'All' in expression or statement.
- [PowerShell Error] Line 1140: Missing opening '(' after keyword 'for'.
- [PowerShell Error] Line 1145: Unexpected token 'tar' in expression or statement.
- [PowerShell Error] Line 1185: Missing ] at end of attribute or type literal.
- [PowerShell Error] Line 1185: Unexpected token 'Entry]' in expression or statement.
- [PowerShell Error] Line 1204: Missing '(' after 'if' in if statement.
- [PowerShell Error] Line 1204: Missing type name after '['.
- [PowerShell Error] Line 1219: Missing file specification after redirection operator.
- [PowerShell Error] Line 1219: The '<' operator is reserved for future use.
- [PowerShell Error] Line 1219: The '<' operator is reserved for future use.
- [PowerShell Error] Line 1230: Missing '(' after 'if' in if statement.
- [PowerShell Error] Line 1230: Missing type name after '['.
- [PowerShell Error] Line 1241: Unexpected token 'build-appimage.sh"

    # Ensure Unix line endings for the script
    $buildScriptUnix = $buildScript -replace "`r`n", "`n" -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempScript, $buildScriptUnix, $utf8NoBom)

    $wslTempScript = Convert-WindowsPathToWSL -WindowsPath $tempScript

    try {
        Invoke-WSLCommand -DistroName $script:ArchDistro -Command "bash' in expression or statement.
- [PowerShell Error] Line 1281: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1281: Unexpected token 'share=network' in expression or statement.
- [PowerShell Error] Line 1282: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1282: Unexpected token 'share=ipc' in expression or statement.
- [PowerShell Error] Line 1283: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1283: Unexpected token 'socket=x11' in expression or statement.
- [PowerShell Error] Line 1284: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1284: Unexpected token 'socket=wayland' in expression or statement.
- [PowerShell Error] Line 1285: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1285: Unexpected token 'device=dri' in expression or statement.
- [PowerShell Error] Line 1286: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1286: Unexpected token 'filesystem=home' in expression or statement.
- [PowerShell Error] Line 1287: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1287: Unexpected token 'talk-name=org.freedesktop.Notifications' in expression or statement.
- [PowerShell Error] Line 1288: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1288: Unexpected token 'talk-name=org.kde.StatusNotifierWatcher' in expression or statement.
- [PowerShell Error] Line 1289: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1289: Unexpected token 'talk-name=org.ayatana.indicator.application' in expression or statement.
- [PowerShell Error] Line 1291: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1291: Unexpected token 'name:' in expression or statement.
- [PowerShell Error] Line 1294: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1294: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 1295: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1295: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 1296: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1296: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 1298: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1298: Unexpected token 'type:' in expression or statement.
- [PowerShell Error] Line 1306: Unexpected token 'flatpak-builder' in expression or statement.
- [PowerShell Error] Line 1360: Unexpected token '}' in expression or statement.
- [PowerShell Error] Line 1523: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1523: Unexpected token 'Flutter' in expression or statement.
- [PowerShell Error] Line 1524: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1524: Unexpected token 'Integrated' in expression or statement.
- [PowerShell Error] Line 1525: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1525: Unexpected token 'All' in expression or statement.
- [PowerShell Error] Line 1531: Missing opening '(' after keyword 'for'.
- [PowerShell Error] Line 1536: Unexpected token 'tar' in expression or statement.
- [PowerShell Error] Line 1576: Missing ] at end of attribute or type literal.
- [PowerShell Error] Line 1576: Unexpected token 'Entry]' in expression or statement.
- [PowerShell Error] Line 1595: Missing '(' after 'if' in if statement.
- [PowerShell Error] Line 1595: Missing type name after '['.
- [PowerShell Error] Line 1610: Missing file specification after redirection operator.
- [PowerShell Error] Line 1610: The '<' operator is reserved for future use.
- [PowerShell Error] Line 1610: The '<' operator is reserved for future use.
- [PowerShell Error] Line 1621: Missing '(' after 'if' in if statement.
- [PowerShell Error] Line 1621: Missing type name after '['.
- [PowerShell Error] Line 1632: Unexpected token 'build-appimage.sh"

    # Ensure Unix line endings for the script
    $buildScriptUnix = $buildScript -replace "`r`n", "`n" -replace "`r", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempScript, $buildScriptUnix, $utf8NoBom)

    $wslTempScript = Convert-WindowsPathToWSL -WindowsPath $tempScript

    try {
        Invoke-WSLCommand -DistroName $script:ArchDistro -Command "bash' in expression or statement.
- [PowerShell Error] Line 1672: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1672: Unexpected token 'share=network' in expression or statement.
- [PowerShell Error] Line 1673: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1673: Unexpected token 'share=ipc' in expression or statement.
- [PowerShell Error] Line 1674: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1674: Unexpected token 'socket=x11' in expression or statement.
- [PowerShell Error] Line 1675: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1675: Unexpected token 'socket=wayland' in expression or statement.
- [PowerShell Error] Line 1676: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1676: Unexpected token 'device=dri' in expression or statement.
- [PowerShell Error] Line 1677: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1677: Unexpected token 'filesystem=home' in expression or statement.
- [PowerShell Error] Line 1678: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1678: Unexpected token 'talk-name=org.freedesktop.Notifications' in expression or statement.
- [PowerShell Error] Line 1679: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1679: Unexpected token 'talk-name=org.kde.StatusNotifierWatcher' in expression or statement.
- [PowerShell Error] Line 1680: Missing expression after unary operator '--'.
- [PowerShell Error] Line 1680: Unexpected token 'talk-name=org.ayatana.indicator.application' in expression or statement.
- [PowerShell Error] Line 1682: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1682: Unexpected token 'name:' in expression or statement.
- [PowerShell Error] Line 1685: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1685: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 1686: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1686: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 1687: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1687: Unexpected token 'install' in expression or statement.
- [PowerShell Error] Line 1689: Missing expression after unary operator '-'.
- [PowerShell Error] Line 1689: Unexpected token 'type:' in expression or statement.
- [PowerShell Error] Line 1697: Unexpected token 'flatpak-builder' in expression or statement.
- [PowerShell Error] Line 1751: Unexpected token '}' in expression or statement.<environment_details>
# VSCode Visible Files
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/0
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/1
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/2
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/3
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/4
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/5
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-9
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-8
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-7
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-6
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-5
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-4
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-3
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-2
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-1
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-0
scripts/powershell/Create-UnifiedPackages.ps1

# VSCode Open Tabs
scripts/powershell/Create-UnifiedPackages.ps1

# Current Time
6/26/2025, 9:31:27 PM (America/Toronto, UTC-4:00)

# Context Window Usage
351,762 / 1,048.576K tokens used (34%)

# Current Mode
ACT MODE
</environment_details>

</file_content>

Now that you have the latest state of the file, try the operation again with fewer, more precise SEARCH blocks. For large files especially, it may be prudent to try to limit yourself to <5 SEARCH/REPLACE blocks at a time, then wait for the user to respond with the result of the operation before following up with another replace_in_file call to make additional edits.
(If you run into this error 3 times in a row, you may use the write_to_file tool as a fallback.)
</error><environment_details>
# VSCode Visible Files
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/0
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/1
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/2
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/3
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/4
../../../../response_488e47ff-13b7-4ba1-9f1f-94160bf97091/5
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-9
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-8
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-7
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-6
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-5
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-4
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-3
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-2
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-1
../../../../response_f0178f4b-db27-4aba-b857-e377f750d92d/tools-0
scripts/powershell/Create-UnifiedPackages.ps1

# VSCode Open Tabs
scripts/powershell/Create-UnifiedPackages.ps1

# Current Time
6/26/2025, 9:31:38 PM (America/Toronto, UTC-4:00)

# Context Window Usage
351,762 / 1,048.576K tokens used (34%)

# Current Mode
ACT MODE
</environment_details>
