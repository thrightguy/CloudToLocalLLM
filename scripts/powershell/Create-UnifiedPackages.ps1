# CloudToLocalLLM Unified Package Creator (PowerShell)
# Creates multiple package formats for Windows and Linux distributions with comprehensive WSL integration
#
# Unified Package Creation System:
# - Windows Packages: MSI, NSIS, Portable ZIP (native Windows tools)
# - Linux Packages: AUR, Debian, AppImage, Flatpak (WSL-based builds)
# - Multi-Platform Build Architecture with graceful degradation
# - Eliminates redundant build scripts and consolidates package creation
# - Maintains PowerShell orchestration with platform-specific execution environments

[CmdletBinding()]
param(
    # Package Type Selection
    [string[]]$PackageTypes = @('AUR', 'AppImage', 'Flatpak', 'MSI', 'NSIS', 'PortableZip'),

    # Platform-Specific Switches
    [switch]$LinuxOnly,         # Create only Linux packages (AUR, AppImage, Flatpak)
    [switch]$WindowsOnly,       # Create only Windows packages (MSI, NSIS, PortableZip)
    [switch]$AUROnly,           # Create only AUR packages
    [switch]$AppImageOnly,      # Create only AppImage packages
    [switch]$FlatpakOnly,       # Create only Flatpak packages
    [switch]$MSIOnly,           # Create only MSI installer
    [switch]$NSISOnly,          # Create only NSIS installer
    [switch]$PortableOnly,      # Create only portable ZIP package

    # Build Control
    [switch]$SkipBuild,         # Skip Flutter build steps
    [switch]$TestOnly,          # Only test existing packages
    [string]$TargetPlatform = 'all',  # 'windows', 'linux', 'arch', 'ubuntu', 'all'

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

# WSL mount paths for Linux builds (consistent across all WSL distributions)
$WSLProjectRoot = "/mnt/c/Users/chris/Dev/CloudToLocalLLM"
$WSLLinuxBuildDir = "/mnt/c/Users/chris/Dev/CloudToLocalLLM/build/linux/x64/release/bundle"
$WSLWindowsBuildDir = "/mnt/c/Users/chris/Dev/CloudToLocalLLM/build/windows/x64/runner/Release"

# Package output directory structure
$LinuxOutputDir = Join-Path $OutputDir "linux"
$WindowsOutputDir = Join-Path $OutputDir "windows"

# Get version from version manager
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
$Version = & $versionManagerPath get-semantic

# Resolve package types based on switches
$script:ResolvedPackageTypes = @()
if ($AUROnly) { $script:ResolvedPackageTypes = @('AUR') }
elseif ($AppImageOnly) { $script:ResolvedPackageTypes = @('AppImage') }
elseif ($FlatpakOnly) { $script:ResolvedPackageTypes = @('Flatpak') }
elseif ($MSIOnly) { $script:ResolvedPackageTypes = @('MSI') }
elseif ($NSISOnly) { $script:ResolvedPackageTypes = @('NSIS') }
elseif ($PortableOnly) { $script:ResolvedPackageTypes = @('PortableZip') }
elseif ($LinuxOnly) { $script:ResolvedPackageTypes = @('AUR', 'AppImage', 'Flatpak') }
elseif ($WindowsOnly) { $script:ResolvedPackageTypes = @('MSI', 'NSIS', 'PortableZip') }
else { $script:ResolvedPackageTypes = $PackageTypes }

# Package type categorization
$script:LinuxPackageTypes = @('AUR', 'AppImage', 'Flatpak')
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
    Write-Host "                        Options: AUR, AppImage, Flatpak, MSI, NSIS, PortableZip"
    Write-Host "  -LinuxOnly            Create only Linux packages (AUR, AppImage, Flatpak)"
    Write-Host "  -WindowsOnly          Create only Windows packages (MSI, NSIS, PortableZip)"
    Write-Host "  -AUROnly              Create only AUR packages"
    Write-Host "  -AppImageOnly         Create only AppImage packages"
    Write-Host "  -FlatpakOnly          Create only Flatpak packages"
    Write-Host "  -MSIOnly              Create only MSI installer"
    Write-Host "  -NSISOnly             Create only NSIS installer"
    Write-Host "  -PortableOnly         Create only portable ZIP package"
    Write-Host ""
    Write-Host "Build Control:" -ForegroundColor Yellow
    Write-Host "  -SkipBuild            Skip Flutter build steps"
    Write-Host "  -TestOnly             Only test existing packages"
    Write-Host "  -TargetPlatform       Target platform: 'windows', 'linux', 'arch', 'ubuntu', 'all'"
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
    Write-Host "    - WSL with Arch Linux (for AUR packages)"
    Write-Host "    - WSL with Ubuntu 24.04 LTS (for Debian/AppImage/Flatpak)"
    Write-Host "    - Flutter SDK in WSL - auto-installed with -AutoInstall"
    Write-Host "    - Linux build dependencies - auto-installed with -AutoInstall"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Create-UnifiedPackages.ps1                                    # Create all package types"
    Write-Host "  .\Create-UnifiedPackages.ps1 -WindowsOnly -AutoInstall         # Windows packages only"
    Write-Host "  .\Create-UnifiedPackages.ps1 -LinuxOnly -WSLDistro ArchLinux   # Linux packages only"
    Write-Host "  .\Create-UnifiedPackages.ps1 -PackageTypes @('MSI','AUR')      # Specific package types"
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

    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
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

# Helper function to install Chocolatey packages
function Install-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$VerifyCommand,

        [switch]$AutoInstall
    )

    # Check if package is already installed
    try {
        Invoke-Expression $VerifyCommand | Out-Null
        Write-LogSuccess "$DisplayName is already installed"
        return $true
    }
    catch {
        Write-LogInfo "$DisplayName not found"
    }

    if ($AutoInstall) {
        Write-LogInfo "Installing $DisplayName via Chocolatey..."
        try {
            # Ensure Chocolatey is installed
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-LogInfo "Installing Chocolatey..."
                Set-ExecutionPolicy Bypass -Scope Process -Force
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            }

            # Install the package
            choco install $PackageName -y

            # Verify installation
            Invoke-Expression $VerifyCommand | Out-Null
            Write-LogSuccess "$DisplayName installed successfully"
            return $true
        }
        catch {
            Write-LogError "Failed to install $DisplayName via Chocolatey: $($_.Exception.Message)"
            return $false
        }
    }
    else {
        Write-LogWarning "$DisplayName is required but not installed"
        Write-LogInfo "Install manually or use -AutoInstall parameter"
        Write-LogInfo "Install command: choco install $PackageName"
        return $false
    }
}

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

# Helper function to find WSL distributions
function Find-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Purpose  # 'Arch' or 'Ubuntu'
    )

    try {
        $wslDistros = wsl --list --quiet | Where-Object { $_ -and $_.Trim() }

        foreach ($distro in $wslDistros) {
            $distroName = $distro.Trim()
            if ($Purpose -eq 'Arch' -and ($distroName -match 'arch|manjaro' -or $distroName -eq 'ArchLinux')) {
                Write-LogInfo "Found Arch Linux WSL distribution: $distroName"
                return $distroName
            }
            elseif ($Purpose -eq 'Ubuntu' -and ($distroName -match 'ubuntu|debian' -or $distroName -eq 'Ubuntu')) {
                Write-LogInfo "Found Ubuntu WSL distribution: $distroName"
                return $distroName
            }
        }

        Write-LogWarning "No suitable $Purpose WSL distribution found"
        Write-LogInfo "Available distributions: $($wslDistros -join ', ')"
        return $null
    }
    catch {
        Write-LogError "Failed to query WSL distributions: $($_.Exception.Message)"
        return $null
    }
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

    # Check for Arch Linux WSL (required for AUR packages)
    if ('AUR' -in $script:ResolvedPackageTypes) {
        $script:ArchDistro = $WSLDistro
        if (-not $script:ArchDistro) {
            $script:ArchDistro = Find-WSLDistribution -Purpose 'Arch'
        }

        if (-not $script:ArchDistro) {
            Write-LogWarning "No Arch Linux WSL distribution found - AUR packages will be skipped"
            $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -ne 'AUR' }
        } else {
            Write-LogInfo "Using Arch Linux WSL distribution: $script:ArchDistro"
            Test-ArchLinuxTools
        }
    }

    # Use Arch Linux WSL for AppImage and Flatpak packages (unified Linux build environment)
    $archPackages = @('AppImage', 'Flatpak') | Where-Object { $_ -in $script:ResolvedPackageTypes }
    if ($archPackages -and $script:ArchDistro) {
        Write-LogInfo "Using Arch Linux WSL distribution for AppImage/Flatpak: $script:ArchDistro"
        Test-ArchLinuxPackageTools
    } elseif ($archPackages) {
        Write-LogWarning "No Arch Linux WSL distribution found - AppImage/Flatpak packages will be skipped"
        $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -notin @('AppImage', 'Flatpak') }
    }

    Write-LogSuccess "Linux prerequisites check completed"
}

# Test Arch Linux tools and dependencies
function Test-ArchLinuxTools {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking Arch Linux tools for AUR package creation..."

    # Check required tools in Arch WSL
    $requiredTools = @('makepkg', 'tar', 'gzip', 'sha256sum')
    foreach ($tool in $requiredTools) {
        if (-not (Test-WSLCommand -DistroName $script:ArchDistro -CommandName $tool)) {
            Write-LogError "Required tool not found in Arch WSL: $tool"
            if ($AutoInstall) {
                Write-LogInfo "Installing base-devel in Arch WSL..."
                Invoke-WSLCommand -DistroName $script:ArchDistro -Command "sudo pacman -S --noconfirm base-devel"
            } else {
                Write-LogInfo "Install in Arch WSL: sudo pacman -S base-devel"
                Write-LogWarning "AUR packages will be skipped"
                $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -ne 'AUR' }
                return
            }
        }
    }

    # Check Flutter SDK in Arch WSL
    if (-not $SkipBuild) {
        Test-WSLFlutterEnvironment -DistroName $script:ArchDistro -PackageManager 'pacman'
    }

    Write-LogSuccess "Arch Linux tools verified"
}

# Test Arch Linux package tools and dependencies
function Test-ArchLinuxPackageTools {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking Arch Linux tools for AppImage/Flatpak package creation..."

    # Check required tools in Arch WSL
    $requiredTools = @('tar', 'gzip', 'sha256sum')
    foreach ($tool in $requiredTools) {
        if (-not (Test-WSLCommand -DistroName $script:ArchDistro -CommandName $tool)) {
            Write-LogError "Required tool not found in Arch WSL: $tool"
            if ($AutoInstall) {
                Write-LogInfo "Installing core tools in Arch WSL..."
                Invoke-WSLCommand -DistroName $script:ArchDistro -Command "sudo pacman -S --noconfirm tar gzip coreutils"
            } else {
                Write-LogInfo "Install in Arch WSL: sudo pacman -S tar gzip coreutils"
                Write-LogWarning "AppImage/Flatpak packages will be skipped"
                $script:ResolvedPackageTypes = $script:ResolvedPackageTypes | Where-Object { $_ -notin @('AppImage', 'Flatpak') }
                return
            }
        }
    }

    # Install package-specific tools
    if ('AppImage' -in $script:ResolvedPackageTypes -and $AutoInstall) {
        Write-LogInfo "Installing AppImage tools in Arch WSL..."
        Invoke-WSLCommand -DistroName $script:ArchDistro -Command "sudo pacman -S --noconfirm wget fuse2 desktop-file-utils"
    }

    if ('Flatpak' -in $script:ResolvedPackageTypes -and $AutoInstall) {
        Write-LogInfo "Installing Flatpak tools in Arch WSL..."
        Invoke-WSLCommand -DistroName $script:ArchDistro -Command "sudo pacman -S --noconfirm flatpak flatpak-builder"
    }

    Write-LogSuccess "Arch Linux package tools verified"
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
        $flutterCheck = Invoke-WSLCommand -DistroName $DistroName -Command "which flutter || echo 'MISSING'" -PassThru
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
        Write-LogInfo "Checking Linux build dependencies in WSL..."
        $buildDeps = @('build-essential', 'cmake', 'ninja-build', 'pkg-config', 'libgtk-3-dev')
        $missingDeps = @()

        foreach ($dep in $buildDeps) {
            if ($PackageManager -eq 'apt') {
                $depCheck = Invoke-WSLCommand -DistroName $DistroName -Command "dpkg -l | grep -E '^ii.*$dep' || echo 'MISSING'" -PassThru
            } else {
                $depCheck = Invoke-WSLCommand -DistroName $DistroName -Command "pacman -Q $dep || echo 'MISSING'" -PassThru
            }

            if ($depCheck -eq "MISSING" -or -not $depCheck) {
                $missingDeps += $dep
            }
        }

        if ($missingDeps.Count -gt 0) {
            Write-LogWarning "Missing Linux build dependencies: $($missingDeps -join ', ')"

            if ($AutoInstall) {
                Write-LogInfo "Installing missing dependencies in WSL..."
                if ($PackageManager -eq 'apt') {
                    $installCmd = "sudo apt update && sudo apt install -y $($missingDeps -join ' ')"
                } else {
                    $installCmd = "sudo pacman -S --noconfirm $($missingDeps -join ' ')"
                }
                Invoke-WSLCommand -DistroName $DistroName -Command $installCmd
                Write-LogSuccess "Linux build dependencies installed"
            }
            else {
                Write-LogError "Linux build dependencies are required"
                if ($PackageManager -eq 'apt') {
                    Write-LogInfo "Install in WSL: sudo apt install -y $($missingDeps -join ' ')"
                } else {
                    Write-LogInfo "Install in WSL: sudo pacman -S $($missingDeps -join ' ')"
                }
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

    # Use the first available WSL distribution that supports Linux builds
    $linuxDistro = $script:ArchDistro
    if (-not $linuxDistro) {
        $linuxDistro = $script:UbuntuDistro
    }

    if (-not $linuxDistro) {
        throw "No suitable WSL distribution available for Linux builds"
    }

    try {
        # Get dependencies using WSL Flutter
        Write-LogInfo "Running flutter pub get in WSL ($linuxDistro)..."
        Invoke-WSLCommand -DistroName $linuxDistro -WorkingDirectory $WSLProjectRoot -Command "flutter pub get"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get dependencies for Flutter app in WSL"
        }

        # Build for Linux using WSL Flutter
        Write-LogInfo "Running flutter build linux --release in WSL ($linuxDistro)..."
        Invoke-WSLCommand -DistroName $linuxDistro -WorkingDirectory $WSLProjectRoot -Command "flutter build linux --release"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Flutter app in WSL"
        }

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
                'AUR' {
                    if ($script:ArchDistro) {
                        New-AURPackage
                        $script:SuccessfulPackages += 'AUR'
                    } else {
                        Write-LogWarning "Skipping AUR package - no Arch Linux WSL distribution available"
                        $script:FailedPackages += @{ Package = 'AUR'; Reason = 'No Arch Linux WSL distribution' }
                    }
                }

                'AppImage' {
                    if ($script:UbuntuDistro) {
                        New-AppImagePackage
                        $script:SuccessfulPackages += 'AppImage'
                    } else {
                        Write-LogWarning "Skipping AppImage package - no Ubuntu WSL distribution available"
                        $script:FailedPackages += @{ Package = 'AppImage'; Reason = 'No Ubuntu WSL distribution' }
                    }
                }
                'Flatpak' {
                    if ($script:UbuntuDistro) {
                        New-FlatpakPackage
                        $script:SuccessfulPackages += 'Flatpak'
                    } else {
                        Write-LogWarning "Skipping Flatpak package - no Ubuntu WSL distribution available"
                        $script:FailedPackages += @{ Package = 'Flatpak'; Reason = 'No Ubuntu WSL distribution' }
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

# Create AUR package
function New-AURPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating AUR package..."

    $packageName = "cloudtolocalllm-$Version-x86_64"
    $packageDir = Join-Path $LinuxOutputDir "aur\$packageName"
    $aurOutputDir = Join-Path $LinuxOutputDir "aur"

    # Create package structure
    New-DirectoryIfNotExists -Path $aurOutputDir
    if (Test-Path $packageDir) {
        Remove-Item $packageDir -Recurse -Force
    }
    New-DirectoryIfNotExists -Path $packageDir

    # Copy Linux build output
    if (Test-Path $LinuxBuildDir) {
        Copy-Item "$LinuxBuildDir\*" $packageDir -Recurse -Force

        # Verify essential files
        $mainExecutable = Join-Path $packageDir "cloudtolocalllm"
        if (-not (Test-Path $mainExecutable)) {
            throw "Failed to copy main executable for AUR package"
        }
    } else {
        throw "Linux build output not found at $LinuxBuildDir"
    }

    # Add AUR-specific metadata
    $packageInfo = Join-Path $packageDir "PACKAGE_INFO.txt"
    @"
CloudToLocalLLM v$Version
========================

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

    # Create archive using WSL
    $wslAurOutputDir = "/mnt/c/Users/chris/Dev/CloudToLocalLLM/dist/linux/aur"
    Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $wslAurOutputDir -Command "tar -czf `"$packageName.tar.gz`" `"$packageName/`""

    # Generate checksum
    $checksumOutput = Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $wslAurOutputDir -Command "sha256sum `"$packageName.tar.gz`"" -PassThru
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
    $buildScript | Set-Content -Path $tempScript -Encoding UTF8
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
    $wslFlatpakDir = Convert-WindowsPathToWSL -WindowsPath $flatpakOutputDir
    $buildCommand = "cd `"$wslFlatpakDir`" && flatpak-builder --repo=repo --force-clean build-dir online.cloudtolocalllm.CloudToLocalLLM.yml"

    try {
        if (Test-WSLCommand -DistroName $script:ArchDistro -CommandName "flatpak-builder") {
            Invoke-WSLCommand -DistroName $script:ArchDistro -Command $buildCommand
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

# Create MSI package
function New-MSIPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating MSI package..."

    $packageName = "CloudToLocalLLM-$Version-x64.msi"
    $msiOutputDir = Join-Path $WindowsOutputDir "msi"
    New-DirectoryIfNotExists -Path $msiOutputDir

    # Verify Windows build exists
    if (-not (Test-Path $WindowsBuildDir)) {
        throw "Windows build output not found at $WindowsBuildDir"
    }

    # Create WiX source file
    $wixSource = Join-Path $env:TEMP "CloudToLocalLLM.wxs"
    $productId = [System.Guid]::NewGuid().ToString()
    $upgradeCode = "12345678-1234-1234-1234-123456789012" # Fixed upgrade code for upgrades

    @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="$productId" Name="CloudToLocalLLM" Language="1033" Version="$Version" Manufacturer="CloudToLocalLLM Team" UpgradeCode="$upgradeCode">
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" />

    <MajorUpgrade DowngradeErrorMessage="A newer version of [ProductName] is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Feature Id="ProductFeature" Title="CloudToLocalLLM" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
  </Product>

  <Fragment>
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="CloudToLocalLLM" />
      </Directory>
    </Directory>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
      <Component Id="MainExecutable" Guid="*">
        <File Id="CloudToLocalLLMExe" Source="$WindowsBuildDir\cloudtolocalllm.exe" KeyPath="yes" />
      </Component>
    </ComponentGroup>
  </Fragment>
</Wix>
"@ | Set-Content -Path $wixSource -Encoding UTF8

    try {
        # Compile with candle
        $wixObj = Join-Path $env:TEMP "CloudToLocalLLM.wixobj"
        & candle.exe -out $wixObj $wixSource
        if ($LASTEXITCODE -ne 0) {
            throw "WiX candle compilation failed"
        }

        # Link with light
        $msiPath = Join-Path $msiOutputDir $packageName
        & light.exe -out $msiPath $wixObj
        if ($LASTEXITCODE -ne 0) {
            throw "WiX light linking failed"
        }

        # Generate checksum
        $checksum = Get-SHA256Hash -FilePath $msiPath
        "$checksum  $packageName" | Set-Content -Path "$msiPath.sha256" -Encoding UTF8

        Write-LogSuccess "MSI package created: $packageName"
    }
    finally {
        # Cleanup temporary files
        if (Test-Path $wixSource) { Remove-Item $wixSource }
        if (Test-Path $wixObj) { Remove-Item $wixObj }
    }
}

# Create NSIS package
function New-NSISPackage {
    [CmdletBinding()]
    param()

    Write-LogInfo "Creating NSIS package..."

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
        # Compile with makensis
        & makensis.exe $nsisScript
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
                'Debian' {
                    $debDir = Join-Path $LinuxOutputDir "debian"
                    $debPackage = Get-ChildItem $debDir -Filter "*.deb" | Select-Object -First 1
                    if ($debPackage) {
                        Write-LogInfo "Testing Debian package: $($debPackage.Name)"
                        if ($debPackage.Length -gt 0) {
                            Write-LogSuccess "Debian package integrity test passed"
                        } else {
                            Write-LogError "Debian package is empty"
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
        Set-Content -Path $pkgbuildFile -Value $updatedContent -Encoding UTF8

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
        Set-Content -Path $pkgbuildFile -Value $updatedContent -Encoding UTF8

        Write-LogInfo "Regenerating .SRCINFO using WSL..."
        # Change to AUR directory and regenerate .SRCINFO using WSL
        $wslAurDir = "/mnt/c/Users/chris/Dev/CloudToLocalLLM/aur-package"
        Invoke-WSLCommand -DistroName $script:ArchDistro -WorkingDirectory $wslAurDir -Command "makepkg --printsrcinfo > .SRCINFO"

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
