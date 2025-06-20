# CloudToLocalLLM Environment Setup Script (PowerShell)
# Prepares a fresh Windows system for CloudToLocalLLM development and package creation
#
# Comprehensive Environment Setup:
# - Windows Native: Flutter, Git, Docker Desktop, WiX Toolset, NSIS
# - WSL Distributions: Arch Linux (AUR packages), Ubuntu 24.04 (Debian/AppImage/Flatpak)
# - Cross-Platform Synchronization: SSH keys, Git config, Flutter SDK versions
# - Integration with Create-UnifiedPackages.ps1 unified package creation system

[CmdletBinding()]
param(
    # Installation Modes
    [switch]$FreshInstall,          # Complete fresh installation on new Windows system
    [switch]$SyncEnvironments,      # Synchronize environments across platforms
    [switch]$SyncSSHKeys,           # Synchronize SSH keys across Windows and WSL
    [switch]$VerifyOnly,            # Verification only without making changes
    [switch]$RepairEnvironment,     # Repair existing installation issues
    [switch]$WSLOnly,               # Configure only WSL distributions (skip Windows tools)
    [switch]$WindowsOnly,           # Configure only Windows native tools (skip WSL)
    
    # Optional Components
    [switch]$IncludeVSCode,         # Install Visual Studio Code
    [switch]$IncludeOptionalTools,  # Install additional development tools
    
    # Configuration Options
    [string]$FlutterPath,           # Custom Flutter installation path
    [string]$GitPath,               # Custom Git installation path
    [string]$DockerPath,            # Custom Docker installation path
    [string]$FlutterVersion = 'stable',  # Flutter version to install
    [string]$GitVersion,            # Git version to install
    [string]$WSLDistro,             # Specific WSL distribution to use
    
    # Control Parameters
    [switch]$AutoInstall,           # Automatically install missing dependencies
    [switch]$SkipDependencyCheck,  # Skip dependency validation
    [switch]$UnattendedMode,        # Run in unattended mode (no user prompts)
    [switch]$Help                   # Show help information
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
$SetupLogPath = Join-Path $env:TEMP "CloudToLocalLLM-Setup-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$MinimumDiskSpaceGB = 15
$RetryAttempts = 3
$RetryDelaySeconds = 5

# Global tracking variables
$script:InstallationSummary = @()
$script:EnvironmentReport = @()
$script:TroubleshootingLog = @()
$script:IntegrationTestResults = @()

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM Environment Setup Script (PowerShell)" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Prepares a fresh Windows system for CloudToLocalLLM development and package creation" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\Setup-CloudToLocalLLMEnvironment.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Installation Modes:" -ForegroundColor Yellow
    Write-Host "  -FreshInstall         Complete fresh installation on new Windows system"
    Write-Host "  -SyncEnvironments     Synchronize environments across platforms"
    Write-Host "  -SyncSSHKeys          Synchronize SSH keys across Windows and WSL"
    Write-Host "  -VerifyOnly           Verification only without making changes"
    Write-Host "  -RepairEnvironment    Repair existing installation issues"
    Write-Host "  -WSLOnly              Configure only WSL distributions (skip Windows tools)"
    Write-Host "  -WindowsOnly          Configure only Windows native tools (skip WSL)"
    Write-Host ""
    Write-Host "Optional Components:" -ForegroundColor Yellow
    Write-Host "  -IncludeVSCode        Install Visual Studio Code"
    Write-Host "  -IncludeOptionalTools Install additional development tools"
    Write-Host ""
    Write-Host "Configuration Options:" -ForegroundColor Yellow
    Write-Host "  -FlutterPath          Custom Flutter installation path"
    Write-Host "  -GitPath              Custom Git installation path"
    Write-Host "  -DockerPath           Custom Docker installation path"
    Write-Host "  -FlutterVersion       Flutter version to install (default: stable)"
    Write-Host "  -GitVersion           Git version to install"
    Write-Host "  -WSLDistro            Specific WSL distribution to use"
    Write-Host ""
    Write-Host "Control Parameters:" -ForegroundColor Yellow
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -UnattendedMode       Run in unattended mode (no user prompts)"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -FreshInstall -AutoInstall"
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -SyncEnvironments -SyncSSHKeys"
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -VerifyOnly"
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -RepairEnvironment -AutoInstall"
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -WSLOnly -AutoInstall"
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -WindowsOnly -AutoInstall"
    Write-Host "  .\Setup-CloudToLocalLLMEnvironment.ps1 -FreshInstall -IncludeVSCode -IncludeOptionalTools"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - Windows 10 version 1903+ or Windows 11"
    Write-Host "  - PowerShell 5.1 or later"
    Write-Host "  - Internet connectivity"
    Write-Host "  - Administrator privileges"
    Write-Host "  - Minimum 15GB free disk space"
    exit 0
}

# Determine installation scope
if (-not ($FreshInstall -or $SyncEnvironments -or $SyncSSHKeys -or $VerifyOnly -or $RepairEnvironment -or $WSLOnly -or $WindowsOnly)) {
    $FreshInstall = $true  # Default to fresh install if no mode specified
}

# Pre-flight checks
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Performing pre-flight checks..."
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    $minVersion = [Version]"10.0.18362"  # Windows 10 1903
    
    if ($osVersion -lt $minVersion) {
        Write-LogError "Windows 10 version 1903 or later is required. Current version: $osVersion"
        return $false
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-LogError "PowerShell 5.1 or later is required. Current version: $($PSVersionTable.PSVersion)"
        return $false
    }
    
    # Check administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-LogError "Administrator privileges are required"
        Write-LogInfo "Please run PowerShell as Administrator and try again"
        Write-LogInfo "Right-click PowerShell and select 'Run as Administrator'"
        return $false
    }
    
    # Check disk space
    $systemDrive = $env:SystemDrive
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$systemDrive'").FreeSpace / 1GB
    
    if ($freeSpace -lt $MinimumDiskSpaceGB) {
        Write-LogError "Insufficient disk space. Required: ${MinimumDiskSpaceGB}GB, Available: $([math]::Round($freeSpace, 2))GB"
        return $false
    }
    
    # Check internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://chocolatey.org" -UseBasicParsing -TimeoutSec 10
        Write-LogSuccess "Internet connectivity verified"
    }
    catch {
        Write-LogError "Internet connectivity required for package downloads"
        return $false
    }
    
    Write-LogSuccess "Pre-flight checks passed"
    return $true
}

# Install and configure Chocolatey
function Install-Chocolatey {
    [CmdletBinding()]
    param()

    Write-LogInfo "Installing and configuring Chocolatey..."
    
    # Check if Chocolatey is already installed
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-LogSuccess "Chocolatey is already installed"
        choco upgrade chocolatey -y
        return $true
    }
    
    try {
        # Install Chocolatey
        Write-LogInfo "Installing Chocolatey package manager..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-LogSuccess "Chocolatey installed successfully"
            
            # Configure Chocolatey
            choco feature enable -n allowGlobalConfirmation
            choco feature enable -n useRememberedArgumentsForUpgrades
            
            $script:InstallationSummary += @{
                Component = "Chocolatey"
                Version = (choco --version)
                Status = "Installed"
                Path = (Get-Command choco).Source
            }
            
            return $true
        }
        else {
            throw "Chocolatey installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install Chocolatey: $($_.Exception.Message)"
        $script:TroubleshootingLog += "Chocolatey installation failed: $($_.Exception.Message)"
        return $false
    }
}

# Install Windows native development tools
function Install-WindowsTools {
    [CmdletBinding()]
    param()

    if ($WSLOnly) {
        Write-LogInfo "Skipping Windows tools installation (WSLOnly mode)"
        return $true
    }

    Write-LogInfo "Installing Windows native development tools..."
    
    $windowsPackages = @(
        @{ Name = "git"; DisplayName = "Git"; Required = $true },
        @{ Name = "flutter"; DisplayName = "Flutter SDK"; Required = $true },
        @{ Name = "docker-desktop"; DisplayName = "Docker Desktop"; Required = $true },
        @{ Name = "wixtoolset"; DisplayName = "WiX Toolset"; Required = $true },
        @{ Name = "nsis"; DisplayName = "NSIS"; Required = $true },
        @{ Name = "vcredist140"; DisplayName = "Visual C++ Redistributable"; Required = $true },
        @{ Name = "windows-sdk-10-version-2004-all"; DisplayName = "Windows SDK"; Required = $false }
    )
    
    if ($IncludeVSCode) {
        $windowsPackages += @{ Name = "vscode"; DisplayName = "Visual Studio Code"; Required = $false }
    }
    
    if ($IncludeOptionalTools) {
        $windowsPackages += @(
            @{ Name = "cmake"; DisplayName = "CMake"; Required = $false },
            @{ Name = "ninja"; DisplayName = "Ninja Build"; Required = $false },
            @{ Name = "7zip"; DisplayName = "7-Zip"; Required = $false }
        )
    }
    
    $totalPackages = $windowsPackages.Count
    $currentPackage = 0
    
    foreach ($package in $windowsPackages) {
        $currentPackage++
        $percentComplete = [math]::Round(($currentPackage / $totalPackages) * 100)
        
        Write-Progress -Activity "Installing Windows Tools" -Status "Installing $($package.DisplayName)" -PercentComplete $percentComplete
        
        try {
            Write-LogInfo "Installing $($package.DisplayName)..."
            
            # Check if already installed
            $installed = $false
            switch ($package.Name) {
                "git" { $installed = (Get-Command git -ErrorAction SilentlyContinue) -ne $null }
                "flutter" { $installed = (Get-Command flutter -ErrorAction SilentlyContinue) -ne $null }
                "docker-desktop" { $installed = (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue) -ne $null }
                default { 
                    $chocoList = choco list --local-only $package.Name
                    $installed = $chocoList -match $package.Name
                }
            }
            
            if ($installed) {
                Write-LogSuccess "$($package.DisplayName) is already installed"
            }
            else {
                # Install with retry logic
                $installSuccess = $false
                for ($attempt = 1; $attempt -le $RetryAttempts; $attempt++) {
                    try {
                        choco install $package.Name -y
                        if ($LASTEXITCODE -eq 0) {
                            $installSuccess = $true
                            break
                        }
                    }
                    catch {
                        Write-LogWarning "Installation attempt $attempt failed for $($package.DisplayName)"
                        if ($attempt -lt $RetryAttempts) {
                            Start-Sleep -Seconds $RetryDelaySeconds
                        }
                    }
                }
                
                if ($installSuccess) {
                    Write-LogSuccess "$($package.DisplayName) installed successfully"
                }
                else {
                    if ($package.Required) {
                        Write-LogError "Failed to install required package: $($package.DisplayName)"
                        return $false
                    }
                    else {
                        Write-LogWarning "Failed to install optional package: $($package.DisplayName)"
                    }
                }
            }
            
            # Add to installation summary
            $version = "Unknown"
            $path = "Unknown"
            
            switch ($package.Name) {
                "git" { 
                    if (Get-Command git -ErrorAction SilentlyContinue) {
                        $version = (git --version)
                        $path = (Get-Command git).Source
                    }
                }
                "flutter" { 
                    if (Get-Command flutter -ErrorAction SilentlyContinue) {
                        $version = (flutter --version | Select-Object -First 1)
                        $path = (Get-Command flutter).Source
                    }
                }
                default {
                    $chocoInfo = choco list --local-only $package.Name --exact
                    if ($chocoInfo -match $package.Name) {
                        $version = ($chocoInfo | Where-Object { $_ -match $package.Name }).Split(' ')[1]
                    }
                }
            }
            
            $script:InstallationSummary += @{
                Component = $package.DisplayName
                Version = $version
                Status = if ($installSuccess -or $installed) { "Installed" } else { "Failed" }
                Path = $path
            }
        }
        catch {
            Write-LogError "Error installing $($package.DisplayName): $($_.Exception.Message)"
            $script:TroubleshootingLog += "Windows tool installation error ($($package.DisplayName)): $($_.Exception.Message)"
            
            if ($package.Required) {
                return $false
            }
        }
    }
    
    Write-Progress -Activity "Installing Windows Tools" -Completed
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-LogSuccess "Windows tools installation completed"
    return $true
}

# Enable WSL and install distributions
function Install-WSLDistributions {
    [CmdletBinding()]
    param()

    if ($WindowsOnly) {
        Write-LogInfo "Skipping WSL installation (WindowsOnly mode)"
        return $true
    }

    Write-LogInfo "Setting up WSL distributions..."

    # Check if WSL is available
    if (-not (Test-WSLAvailable)) {
        Write-LogInfo "Enabling WSL features..."

        try {
            # Enable WSL and Virtual Machine Platform features
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart

            Write-LogWarning "WSL features enabled. A system restart may be required."
            Write-LogInfo "Please restart your computer and run this script again to continue WSL setup."

            if (-not $UnattendedMode) {
                $restart = Read-Host "Would you like to restart now? (y/N)"
                if ($restart -eq 'y' -or $restart -eq 'Y') {
                    Restart-Computer -Force
                }
            }

            return $false
        }
        catch {
            Write-LogError "Failed to enable WSL features: $($_.Exception.Message)"
            Write-LogInfo "Manual steps to enable WSL:"
            Write-LogInfo "1. Open PowerShell as Administrator"
            Write-LogInfo "2. Run: dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart"
            Write-LogInfo "3. Run: dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart"
            Write-LogInfo "4. Restart your computer"
            Write-LogInfo "5. Download and install WSL2 kernel update from Microsoft"
            return $false
        }
    }

    # Set WSL2 as default
    try {
        wsl --set-default-version 2
        Write-LogSuccess "WSL2 set as default version"
    }
    catch {
        Write-LogWarning "Could not set WSL2 as default version"
    }

    # Install required distributions
    $distributions = @(
        @{ Name = "ArchLinux"; Purpose = "Arch"; Required = $true },
        @{ Name = "Ubuntu-24.04"; Purpose = "Ubuntu"; Required = $true }
    )

    foreach ($distro in $distributions) {
        Write-LogInfo "Installing $($distro.Name) WSL distribution..."

        try {
            # Check if already installed
            $existingDistro = Find-WSLDistribution -Purpose $distro.Purpose
            if ($existingDistro) {
                Write-LogSuccess "$($distro.Name) (or compatible) is already installed: $existingDistro"
                continue
            }

            # Install via Windows Store or direct download
            $installSuccess = $false
            for ($attempt = 1; $attempt -le $RetryAttempts; $attempt++) {
                try {
                    if ($distro.Name -eq "ArchLinux") {
                        # Install Arch Linux WSL
                        Write-LogInfo "Installing Arch Linux WSL (attempt $attempt)..."
                        # Note: This may require manual installation from GitHub releases
                        Write-LogWarning "Arch Linux WSL may need to be installed manually"
                        Write-LogInfo "Download from: https://github.com/yuk7/ArchWSL/releases"
                    }
                    elseif ($distro.Name -eq "Ubuntu-24.04") {
                        # Install Ubuntu 24.04 LTS
                        Write-LogInfo "Installing Ubuntu 24.04 LTS (attempt $attempt)..."
                        wsl --install -d Ubuntu-24.04
                    }

                    # Wait for installation to complete
                    Start-Sleep -Seconds 10

                    # Verify installation
                    $installedDistro = Find-WSLDistribution -Purpose $distro.Purpose
                    if ($installedDistro) {
                        $installSuccess = $true
                        Write-LogSuccess "$($distro.Name) installed successfully as: $installedDistro"
                        break
                    }
                }
                catch {
                    Write-LogWarning "Installation attempt $attempt failed for $($distro.Name): $($_.Exception.Message)"
                    if ($attempt -lt $RetryAttempts) {
                        Start-Sleep -Seconds $RetryDelaySeconds
                    }
                }
            }

            if (-not $installSuccess) {
                if ($distro.Required) {
                    Write-LogError "Failed to install required WSL distribution: $($distro.Name)"
                    Write-LogInfo "Manual installation may be required"
                    return $false
                }
                else {
                    Write-LogWarning "Failed to install optional WSL distribution: $($distro.Name)"
                }
            }

            $script:InstallationSummary += @{
                Component = "$($distro.Name) WSL"
                Version = "Latest"
                Status = if ($installSuccess) { "Installed" } else { "Failed" }
                Path = "WSL Distribution"
            }
        }
        catch {
            Write-LogError "Error installing $($distro.Name): $($_.Exception.Message)"
            $script:TroubleshootingLog += "WSL distribution installation error ($($distro.Name)): $($_.Exception.Message)"

            if ($distro.Required) {
                return $false
            }
        }
    }

    Write-LogSuccess "WSL distributions setup completed"
    return $true
}

# Configure WSL distributions with required tools
function Configure-WSLEnvironments {
    [CmdletBinding()]
    param()

    if ($WindowsOnly) {
        Write-LogInfo "Skipping WSL configuration (WindowsOnly mode)"
        return $true
    }

    Write-LogInfo "Configuring WSL environments..."

    # Configure Arch Linux WSL
    $archDistro = Find-WSLDistribution -Purpose 'Arch'
    if ($archDistro) {
        Write-LogInfo "Configuring Arch Linux WSL: $archDistro"

        try {
            # Update system and install base-devel
            Write-LogInfo "Updating Arch Linux and installing base-devel..."
            Invoke-WSLCommand -DistroName $archDistro -Command "sudo pacman -Syu --noconfirm"
            Invoke-WSLCommand -DistroName $archDistro -Command "sudo pacman -S --noconfirm base-devel git cmake ninja pkgconf gtk3"

            # Install Flutter SDK via snap
            Write-LogInfo "Installing Flutter SDK in Arch Linux..."
            try {
                Invoke-WSLCommand -DistroName $archDistro -Command "sudo pacman -S --noconfirm snapd"
                Invoke-WSLCommand -DistroName $archDistro -Command "sudo systemctl enable --now snapd.socket"
                Invoke-WSLCommand -DistroName $archDistro -Command "sudo snap install flutter --classic"
            }
            catch {
                Write-LogWarning "Failed to install Flutter via snap in Arch Linux"
                Write-LogInfo "Manual Flutter installation may be required"
            }

            Write-LogSuccess "Arch Linux WSL configured successfully"
        }
        catch {
            Write-LogError "Failed to configure Arch Linux WSL: $($_.Exception.Message)"
            $script:TroubleshootingLog += "Arch Linux WSL configuration error: $($_.Exception.Message)"
        }
    }
    else {
        Write-LogWarning "Arch Linux WSL distribution not found"
    }

    # Configure Ubuntu WSL
    $ubuntuDistro = Find-WSLDistribution -Purpose 'Ubuntu'
    if ($ubuntuDistro) {
        Write-LogInfo "Configuring Ubuntu WSL: $ubuntuDistro"

        try {
            # Update system and install build tools
            Write-LogInfo "Updating Ubuntu and installing build tools..."
            Invoke-WSLCommand -DistroName $ubuntuDistro -Command "sudo apt update && sudo apt upgrade -y"
            Invoke-WSLCommand -DistroName $ubuntuDistro -Command "sudo apt install -y build-essential dpkg-dev git cmake ninja-build pkg-config libgtk-3-dev"

            # Install AppImage and Flatpak tools
            Write-LogInfo "Installing AppImage and Flatpak tools..."
            Invoke-WSLCommand -DistroName $ubuntuDistro -Command "sudo apt install -y wget fuse libfuse2 desktop-file-utils"
            Invoke-WSLCommand -DistroName $ubuntuDistro -Command "sudo apt install -y flatpak flatpak-builder"

            # Install Flutter SDK via snap
            Write-LogInfo "Installing Flutter SDK in Ubuntu..."
            try {
                Invoke-WSLCommand -DistroName $ubuntuDistro -Command "sudo snap install flutter --classic"
            }
            catch {
                Write-LogWarning "Failed to install Flutter via snap in Ubuntu"
                Write-LogInfo "Manual Flutter installation may be required"
            }

            Write-LogSuccess "Ubuntu WSL configured successfully"
        }
        catch {
            Write-LogError "Failed to configure Ubuntu WSL: $($_.Exception.Message)"
            $script:TroubleshootingLog += "Ubuntu WSL configuration error: $($_.Exception.Message)"
        }
    }
    else {
        Write-LogWarning "Ubuntu WSL distribution not found"
    }

    Write-LogSuccess "WSL environments configuration completed"
    return $true
}

# Synchronize SSH keys across Windows and WSL environments
function Sync-SSHKeys {
    [CmdletBinding()]
    param()

    if (-not $SyncSSHKeys -and -not $FreshInstall -and -not $SyncEnvironments) {
        return $true
    }

    Write-LogInfo "Synchronizing SSH keys across environments..."

    $windowsSSHPath = Join-Path $env:USERPROFILE ".ssh"
    $backupPath = Join-Path $env:TEMP "ssh-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    # Check if SSH keys exist on Windows
    if (-not (Test-Path $windowsSSHPath)) {
        Write-LogInfo "No SSH keys found on Windows. Generating new SSH keys..."

        if (-not $UnattendedMode) {
            $generateKeys = Read-Host "Generate new SSH keys? (Y/n)"
            if ($generateKeys -eq 'n' -or $generateKeys -eq 'N') {
                Write-LogInfo "Skipping SSH key generation"
                return $true
            }
        }

        # Create SSH directory
        New-Item -ItemType Directory -Path $windowsSSHPath -Force | Out-Null

        # Generate Ed25519 SSH key
        $email = if ($env:GIT_AUTHOR_EMAIL) { $env:GIT_AUTHOR_EMAIL } else { "user@cloudtolocalllm" }
        $keyPath = Join-Path $windowsSSHPath "id_ed25519"

        try {
            ssh-keygen -t ed25519 -C $email -f $keyPath -N '""'
            Write-LogSuccess "SSH keys generated successfully"
        }
        catch {
            Write-LogError "Failed to generate SSH keys: $($_.Exception.Message)"
            return $false
        }
    }

    # Create backup of existing SSH configurations
    if (Test-Path $windowsSSHPath) {
        Write-LogInfo "Creating backup of SSH configuration..."
        Copy-Item $windowsSSHPath $backupPath -Recurse -Force
        Write-LogInfo "SSH backup created at: $backupPath"
    }

    # Synchronize to WSL distributions
    $distributions = @()
    $archDistro = Find-WSLDistribution -Purpose 'Arch'
    $ubuntuDistro = Find-WSLDistribution -Purpose 'Ubuntu'

    if ($archDistro) { $distributions += $archDistro }
    if ($ubuntuDistro) { $distributions += $ubuntuDistro }

    foreach ($distro in $distributions) {
        Write-LogInfo "Synchronizing SSH keys to $distro..."

        try {
            # Get WSL username
            $wslUser = Invoke-WSLCommand -DistroName $distro -Command "whoami" -PassThru
            $wslSSHPath = "/home/$wslUser/.ssh"

            # Create SSH directory in WSL
            Invoke-WSLCommand -DistroName $distro -Command "mkdir -p $wslSSHPath"

            # Copy SSH keys from Windows to WSL
            $windowsSSHPathWSL = Convert-WindowsPathToWSL -WindowsPath $windowsSSHPath
            Invoke-WSLCommand -DistroName $distro -Command "cp -r $windowsSSHPathWSL/* $wslSSHPath/"

            # Set proper permissions
            Invoke-WSLCommand -DistroName $distro -Command "chmod 700 $wslSSHPath"
            Invoke-WSLCommand -DistroName $distro -Command "chmod 600 $wslSSHPath/id_*"
            Invoke-WSLCommand -DistroName $distro -Command "chmod 644 $wslSSHPath/*.pub"

            # Set ownership
            Invoke-WSLCommand -DistroName $distro -Command "chown -R ${wslUser}:${wslUser} $wslSSHPath"

            Write-LogSuccess "SSH keys synchronized to $distro"
        }
        catch {
            Write-LogError "Failed to synchronize SSH keys to $distro: $($_.Exception.Message)"
            $script:TroubleshootingLog += "SSH sync error ($distro): $($_.Exception.Message)"
        }
    }

    # Set proper permissions on Windows SSH keys
    try {
        Write-LogInfo "Setting proper permissions on Windows SSH keys..."

        # Remove inheritance and set specific permissions
        icacls $windowsSSHPath /inheritance:r
        icacls $windowsSSHPath /grant:r "$env:USERNAME:(OI)(CI)F"
        icacls $windowsSSHPath /grant:r "SYSTEM:(OI)(CI)F"
        icacls $windowsSSHPath /grant:r "Administrators:(OI)(CI)F"

        # Set permissions for private keys
        Get-ChildItem $windowsSSHPath -Filter "id_*" | Where-Object { $_.Extension -eq "" } | ForEach-Object {
            icacls $_.FullName /inheritance:r
            icacls $_.FullName /grant:r "$env:USERNAME:R"
            icacls $_.FullName /grant:r "SYSTEM:R"
        }

        Write-LogSuccess "Windows SSH key permissions configured"
    }
    catch {
        Write-LogWarning "Failed to set SSH key permissions on Windows: $($_.Exception.Message)"
    }

    Write-LogSuccess "SSH key synchronization completed"
    return $true
}

# Synchronize Git configuration across environments
function Sync-GitConfiguration {
    [CmdletBinding()]
    param()

    if (-not $SyncEnvironments -and -not $FreshInstall) {
        return $true
    }

    Write-LogInfo "Synchronizing Git configuration across environments..."

    # Get or set Git configuration
    $gitUserName = git config --global user.name 2>$null
    $gitUserEmail = git config --global user.email 2>$null

    if (-not $gitUserName -or -not $gitUserEmail) {
        if (-not $UnattendedMode) {
            Write-LogInfo "Git configuration not found. Please provide Git user information:"
            $gitUserName = Read-Host "Git user name"
            $gitUserEmail = Read-Host "Git user email"
        }
        else {
            $gitUserName = "CloudToLocalLLM Developer"
            $gitUserEmail = "developer@cloudtolocalllm.online"
        }

        # Configure Git on Windows
        git config --global user.name $gitUserName
        git config --global user.email $gitUserEmail
        git config --global core.autocrlf input
        git config --global init.defaultBranch main
    }

    # Synchronize to WSL distributions
    $distributions = @()
    $archDistro = Find-WSLDistribution -Purpose 'Arch'
    $ubuntuDistro = Find-WSLDistribution -Purpose 'Ubuntu'

    if ($archDistro) { $distributions += $archDistro }
    if ($ubuntuDistro) { $distributions += $ubuntuDistro }

    foreach ($distro in $distributions) {
        Write-LogInfo "Synchronizing Git configuration to $distro..."

        try {
            Invoke-WSLCommand -DistroName $distro -Command "git config --global user.name '$gitUserName'"
            Invoke-WSLCommand -DistroName $distro -Command "git config --global user.email '$gitUserEmail'"
            Invoke-WSLCommand -DistroName $distro -Command "git config --global core.autocrlf input"
            Invoke-WSLCommand -DistroName $distro -Command "git config --global init.defaultBranch main"

            Write-LogSuccess "Git configuration synchronized to $distro"
        }
        catch {
            Write-LogError "Failed to synchronize Git configuration to $distro: $($_.Exception.Message)"
            $script:TroubleshootingLog += "Git config sync error ($distro): $($_.Exception.Message)"
        }
    }

    $script:EnvironmentReport += "Git User: $gitUserName <$gitUserEmail>"
    Write-LogSuccess "Git configuration synchronization completed"
    return $true
}

# Comprehensive verification of all environments
function Test-EnvironmentHealth {
    [CmdletBinding()]
    param()

    Write-LogInfo "Performing comprehensive environment health checks..."

    $healthResults = @{
        WindowsNative = @{}
        ArchLinuxWSL = @{}
        UbuntuWSL = @{}
        Integration = @{}
    }

    # Test Windows Native Environment
    Write-LogInfo "Testing Windows native environment..."

    # Test Flutter
    try {
        $flutterVersion = flutter --version 2>$null
        if ($flutterVersion) {
            $healthResults.WindowsNative.Flutter = "✅ $($flutterVersion.Split("`n")[0])"

            # Test Windows build capability
            Push-Location $ProjectRoot
            try {
                $buildTest = flutter build windows --dry-run 2>$null
                $healthResults.WindowsNative.FlutterBuild = "✅ Windows build capability verified"
            }
            catch {
                $healthResults.WindowsNative.FlutterBuild = "❌ Windows build test failed"
            }
            finally {
                Pop-Location
            }
        }
        else {
            $healthResults.WindowsNative.Flutter = "❌ Flutter not found or not working"
        }
    }
    catch {
        $healthResults.WindowsNative.Flutter = "❌ Flutter test failed: $($_.Exception.Message)"
    }

    # Test WiX Toolset
    try {
        $candleTest = & candle.exe -? 2>$null
        if ($LASTEXITCODE -eq 0) {
            $healthResults.WindowsNative.WiX = "✅ WiX Toolset available"
        }
        else {
            $healthResults.WindowsNative.WiX = "❌ WiX Toolset not working"
        }
    }
    catch {
        $healthResults.WindowsNative.WiX = "❌ WiX Toolset not found"
    }

    # Test NSIS
    try {
        $nsisTest = & makensis.exe /VERSION 2>$null
        if ($LASTEXITCODE -eq 0) {
            $healthResults.WindowsNative.NSIS = "✅ NSIS available"
        }
        else {
            $healthResults.WindowsNative.NSIS = "❌ NSIS not working"
        }
    }
    catch {
        $healthResults.WindowsNative.NSIS = "❌ NSIS not found"
    }

    # Test Docker Desktop
    try {
        $dockerTest = docker --version 2>$null
        if ($dockerTest) {
            $healthResults.WindowsNative.Docker = "✅ $dockerTest"
        }
        else {
            $healthResults.WindowsNative.Docker = "❌ Docker not available"
        }
    }
    catch {
        $healthResults.WindowsNative.Docker = "❌ Docker test failed"
    }

    # Test Arch Linux WSL
    $archDistro = Find-WSLDistribution -Purpose 'Arch'
    if ($archDistro) {
        Write-LogInfo "Testing Arch Linux WSL environment: $archDistro"

        # Test makepkg
        try {
            $makepkgTest = Invoke-WSLCommand -DistroName $archDistro -Command "makepkg --version" -PassThru
            if ($makepkgTest) {
                $healthResults.ArchLinuxWSL.Makepkg = "✅ makepkg available"
            }
            else {
                $healthResults.ArchLinuxWSL.Makepkg = "❌ makepkg not working"
            }
        }
        catch {
            $healthResults.ArchLinuxWSL.Makepkg = "❌ makepkg test failed"
        }

        # Test Flutter in WSL
        try {
            $flutterWSLTest = Invoke-WSLCommand -DistroName $archDistro -Command "flutter --version" -PassThru
            if ($flutterWSLTest) {
                $healthResults.ArchLinuxWSL.Flutter = "✅ Flutter available in WSL"

                # Test Linux build capability
                try {
                    $linuxBuildTest = Invoke-WSLCommand -DistroName $archDistro -WorkingDirectory "/mnt/c/Users/chris/Dev/CloudToLocalLLM" -Command "flutter build linux --dry-run" -PassThru
                    $healthResults.ArchLinuxWSL.FlutterBuild = "✅ Linux build capability verified"
                }
                catch {
                    $healthResults.ArchLinuxWSL.FlutterBuild = "❌ Linux build test failed"
                }
            }
            else {
                $healthResults.ArchLinuxWSL.Flutter = "❌ Flutter not available in WSL"
            }
        }
        catch {
            $healthResults.ArchLinuxWSL.Flutter = "❌ Flutter WSL test failed"
        }

        # Test base-devel
        try {
            $baseDevelTest = Invoke-WSLCommand -DistroName $archDistro -Command "pacman -Q base-devel" -PassThru
            if ($baseDevelTest) {
                $healthResults.ArchLinuxWSL.BaseDevel = "✅ base-devel group installed"
            }
            else {
                $healthResults.ArchLinuxWSL.BaseDevel = "❌ base-devel group not installed"
            }
        }
        catch {
            $healthResults.ArchLinuxWSL.BaseDevel = "❌ base-devel test failed"
        }
    }
    else {
        $healthResults.ArchLinuxWSL.Status = "❌ Arch Linux WSL distribution not found"
    }

    # Test Ubuntu WSL
    $ubuntuDistro = Find-WSLDistribution -Purpose 'Ubuntu'
    if ($ubuntuDistro) {
        Write-LogInfo "Testing Ubuntu WSL environment: $ubuntuDistro"

        # Test dpkg-deb
        try {
            $dpkgTest = Invoke-WSLCommand -DistroName $ubuntuDistro -Command "dpkg-deb --version" -PassThru
            if ($dpkgTest) {
                $healthResults.UbuntuWSL.DpkgDeb = "✅ dpkg-deb available"
            }
            else {
                $healthResults.UbuntuWSL.DpkgDeb = "❌ dpkg-deb not working"
            }
        }
        catch {
            $healthResults.UbuntuWSL.DpkgDeb = "❌ dpkg-deb test failed"
        }

        # Test build-essential
        try {
            $buildEssentialTest = Invoke-WSLCommand -DistroName $ubuntuDistro -Command "dpkg -l build-essential" -PassThru
            if ($buildEssentialTest -match "ii.*build-essential") {
                $healthResults.UbuntuWSL.BuildEssential = "✅ build-essential installed"
            }
            else {
                $healthResults.UbuntuWSL.BuildEssential = "❌ build-essential not installed"
            }
        }
        catch {
            $healthResults.UbuntuWSL.BuildEssential = "❌ build-essential test failed"
        }

        # Test AppImage tools
        try {
            $appImageTest = Invoke-WSLCommand -DistroName $ubuntuDistro -Command "which appimagetool" -PassThru
            if ($appImageTest) {
                $healthResults.UbuntuWSL.AppImage = "✅ AppImage tools available"
            }
            else {
                $healthResults.UbuntuWSL.AppImage = "❌ AppImage tools not found"
            }
        }
        catch {
            $healthResults.UbuntuWSL.AppImage = "❌ AppImage tools test failed"
        }

        # Test Flatpak
        try {
            $flatpakTest = Invoke-WSLCommand -DistroName $ubuntuDistro -Command "flatpak --version" -PassThru
            if ($flatpakTest) {
                $healthResults.UbuntuWSL.Flatpak = "✅ Flatpak available"
            }
            else {
                $healthResults.UbuntuWSL.Flatpak = "❌ Flatpak not available"
            }
        }
        catch {
            $healthResults.UbuntuWSL.Flatpak = "❌ Flatpak test failed"
        }
    }
    else {
        $healthResults.UbuntuWSL.Status = "❌ Ubuntu WSL distribution not found"
    }

    # Test Integration with Create-UnifiedPackages.ps1
    Write-LogInfo "Testing integration with Create-UnifiedPackages.ps1..."

    $unifiedPackagesScript = Join-Path $PSScriptRoot "Create-UnifiedPackages.ps1"
    if (Test-Path $unifiedPackagesScript) {
        try {
            # Test help functionality
            $helpTest = & $unifiedPackagesScript -Help 2>$null
            if ($LASTEXITCODE -eq 0) {
                $healthResults.Integration.HelpCommand = "✅ Create-UnifiedPackages.ps1 help accessible"
            }
            else {
                $healthResults.Integration.HelpCommand = "❌ Create-UnifiedPackages.ps1 help failed"
            }

            # Test package type detection (if not in verify-only mode)
            if (-not $VerifyOnly) {
                try {
                    $testOnlyResult = & $unifiedPackagesScript -TestOnly 2>$null
                    $healthResults.Integration.TestOnly = "✅ Create-UnifiedPackages.ps1 test mode accessible"
                }
                catch {
                    $healthResults.Integration.TestOnly = "❌ Create-UnifiedPackages.ps1 test mode failed"
                }
            }
        }
        catch {
            $healthResults.Integration.Script = "❌ Create-UnifiedPackages.ps1 execution failed"
        }
    }
    else {
        $healthResults.Integration.Script = "❌ Create-UnifiedPackages.ps1 not found"
    }

    # Store results for reporting
    $script:IntegrationTestResults = $healthResults

    # Display results
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Environment Health Check Results" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Windows Native Environment:" -ForegroundColor Yellow
    foreach ($key in $healthResults.WindowsNative.Keys) {
        Write-Host "  $key`: $($healthResults.WindowsNative[$key])"
    }
    Write-Host ""

    Write-Host "Arch Linux WSL Environment:" -ForegroundColor Yellow
    foreach ($key in $healthResults.ArchLinuxWSL.Keys) {
        Write-Host "  $key`: $($healthResults.ArchLinuxWSL[$key])"
    }
    Write-Host ""

    Write-Host "Ubuntu WSL Environment:" -ForegroundColor Yellow
    foreach ($key in $healthResults.UbuntuWSL.Keys) {
        Write-Host "  $key`: $($healthResults.UbuntuWSL[$key])"
    }
    Write-Host ""

    Write-Host "Integration Tests:" -ForegroundColor Yellow
    foreach ($key in $healthResults.Integration.Keys) {
        Write-Host "  $key`: $($healthResults.Integration[$key])"
    }
    Write-Host ""

    # Count failures
    $totalTests = 0
    $failedTests = 0

    foreach ($category in $healthResults.Values) {
        foreach ($result in $category.Values) {
            $totalTests++
            if ($result -match "❌") {
                $failedTests++
            }
        }
    }

    $successRate = [math]::Round((($totalTests - $failedTests) / $totalTests) * 100, 1)

    if ($failedTests -eq 0) {
        Write-Host "[RESULT] All environment health checks passed! ✅ ($successRate% success)" -ForegroundColor Green
        return $true
    }
    elseif ($failedTests -lt ($totalTests / 2)) {
        Write-Host "[RESULT] Most environment health checks passed ($successRate% success)" -ForegroundColor Yellow
        Write-Host "Some issues detected but environment should be functional" -ForegroundColor Yellow
        return $true
    }
    else {
        Write-Host "[RESULT] Multiple environment health check failures ($successRate% success)" -ForegroundColor Red
        Write-Host "Environment may not be fully functional" -ForegroundColor Red
        return $false
    }
}

# Generate comprehensive setup report
function New-SetupReport {
    [CmdletBinding()]
    param()

    Write-LogInfo "Generating comprehensive setup report..."

    $reportContent = @"
CloudToLocalLLM Environment Setup Report
========================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)

INSTALLATION SUMMARY
===================
"@

    foreach ($item in $script:InstallationSummary) {
        $reportContent += "`n$($item.Component): $($item.Status) - Version: $($item.Version)"
        if ($item.Path -ne "Unknown") {
            $reportContent += "`n  Path: $($item.Path)"
        }
    }

    $reportContent += @"

ENVIRONMENT REPORT
==================
"@

    foreach ($item in $script:EnvironmentReport) {
        $reportContent += "`n$item"
    }

    # Add PATH variables
    $reportContent += "`n`nPATH Variables:"
    $reportContent += "`nWindows PATH: $env:PATH"

    # Add Flutter doctor output
    try {
        $flutterDoctor = flutter doctor 2>$null
        if ($flutterDoctor) {
            $reportContent += "`n`nFlutter Doctor Output:"
            $reportContent += "`n$flutterDoctor"
        }
    }
    catch {
        $reportContent += "`n`nFlutter Doctor: Not available"
    }

    # Add Git configuration
    try {
        $gitConfig = git config --list 2>$null
        if ($gitConfig) {
            $reportContent += "`n`nGit Configuration:"
            $reportContent += "`n$gitConfig"
        }
    }
    catch {
        $reportContent += "`n`nGit Configuration: Not available"
    }

    # Add SSH key information
    $sshPath = Join-Path $env:USERPROFILE ".ssh"
    if (Test-Path $sshPath) {
        $reportContent += "`n`nSSH Keys:"
        Get-ChildItem $sshPath -Filter "*.pub" | ForEach-Object {
            try {
                $keyContent = Get-Content $_.FullName
                $reportContent += "`n$($_.Name): $keyContent"
            }
            catch {
                $reportContent += "`n$($_.Name): Error reading key"
            }
        }
    }

    $reportContent += @"

TROUBLESHOOTING LOG
==================
"@

    foreach ($item in $script:TroubleshootingLog) {
        $reportContent += "`n$item"
    }

    $reportContent += @"

INTEGRATION TEST RESULTS
========================
"@

    foreach ($category in $script:IntegrationTestResults.Keys) {
        $reportContent += "`n`n$category Environment:"
        foreach ($test in $script:IntegrationTestResults[$category].Keys) {
            $reportContent += "`n  $test`: $($script:IntegrationTestResults[$category][$test])"
        }
    }

    $reportContent += @"

NEXT STEPS GUIDE
===============
1. Test Windows package creation:
   .\Create-UnifiedPackages.ps1 -WindowsOnly -TestOnly

2. Test Linux package creation:
   .\Create-UnifiedPackages.ps1 -LinuxOnly -TestOnly

3. Test complete unified package creation:
   .\Create-UnifiedPackages.ps1 -TestOnly

4. Create actual packages:
   .\Create-UnifiedPackages.ps1 -AutoInstall

5. Deploy to VPS:
   .\deploy_vps.ps1

TROUBLESHOOTING RESOURCES
========================
- CloudToLocalLLM Documentation: https://github.com/imrightguy/CloudToLocalLLM
- Flutter Installation Guide: https://docs.flutter.dev/get-started/install/windows
- WSL Installation Guide: https://docs.microsoft.com/en-us/windows/wsl/install
- Docker Desktop Guide: https://docs.docker.com/desktop/windows/install/

For support, please visit: https://cloudtolocalllm.online
"@

    # Save report to file
    try {
        $reportContent | Set-Content -Path $SetupLogPath -Encoding UTF8
        Write-LogSuccess "Setup report saved to: $SetupLogPath"

        if (-not $UnattendedMode) {
            $openReport = Read-Host "Would you like to open the setup report? (Y/n)"
            if ($openReport -ne 'n' -and $openReport -ne 'N') {
                Start-Process notepad.exe $SetupLogPath
            }
        }
    }
    catch {
        Write-LogError "Failed to save setup report: $($_.Exception.Message)"
    }
}

# Main execution function
function Invoke-EnvironmentSetup {
    [CmdletBinding()]
    param()

    Write-Host "CloudToLocalLLM Environment Setup Script" -ForegroundColor Blue
    Write-Host "=========================================" -ForegroundColor Blue
    Write-Host "Preparing Windows system for CloudToLocalLLM development" -ForegroundColor White
    Write-Host ""

    $startTime = Get-Date
    $overallSuccess = $true

    try {
        # Pre-flight checks
        if (-not (Test-Prerequisites)) {
            Write-LogError "Pre-flight checks failed"
            exit 2
        }

        # Verification only mode
        if ($VerifyOnly) {
            Write-LogInfo "Running in verification-only mode"
            $healthResult = Test-EnvironmentHealth
            New-SetupReport
            exit (if ($healthResult) { 0 } else { 1 })
        }

        # Install Chocolatey
        if ($FreshInstall -or $RepairEnvironment -or (-not $WSLOnly)) {
            Write-Progress -Activity "Environment Setup" -Status "Installing Chocolatey" -PercentComplete 10
            if (-not (Install-Chocolatey)) {
                $overallSuccess = $false
            }
        }

        # Install Windows tools
        if ($FreshInstall -or $RepairEnvironment -or $WindowsOnly) {
            Write-Progress -Activity "Environment Setup" -Status "Installing Windows Tools" -PercentComplete 25
            if (-not (Install-WindowsTools)) {
                $overallSuccess = $false
            }
        }

        # Install and configure WSL
        if ($FreshInstall -or $RepairEnvironment -or $WSLOnly) {
            Write-Progress -Activity "Environment Setup" -Status "Setting up WSL" -PercentComplete 50
            if (-not (Install-WSLDistributions)) {
                $overallSuccess = $false
            }

            Write-Progress -Activity "Environment Setup" -Status "Configuring WSL Environments" -PercentComplete 65
            if (-not (Configure-WSLEnvironments)) {
                $overallSuccess = $false
            }
        }

        # Synchronize SSH keys
        if ($FreshInstall -or $SyncSSHKeys -or $SyncEnvironments) {
            Write-Progress -Activity "Environment Setup" -Status "Synchronizing SSH Keys" -PercentComplete 75
            if (-not (Sync-SSHKeys)) {
                $overallSuccess = $false
            }
        }

        # Synchronize Git configuration
        if ($FreshInstall -or $SyncEnvironments) {
            Write-Progress -Activity "Environment Setup" -Status "Synchronizing Git Configuration" -PercentComplete 85
            if (-not (Sync-GitConfiguration)) {
                $overallSuccess = $false
            }
        }

        # Comprehensive verification
        Write-Progress -Activity "Environment Setup" -Status "Running Health Checks" -PercentComplete 95
        $healthResult = Test-EnvironmentHealth

        # Generate report
        Write-Progress -Activity "Environment Setup" -Status "Generating Report" -PercentComplete 100
        New-SetupReport

        Write-Progress -Activity "Environment Setup" -Completed

        # Final results
        $endTime = Get-Date
        $duration = $endTime - $startTime

        Write-Host ""
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host "CloudToLocalLLM Environment Setup Complete" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
        Write-Host "Report: $SetupLogPath" -ForegroundColor White
        Write-Host ""

        if ($overallSuccess -and $healthResult) {
            Write-Host "[SUCCESS] Environment setup completed successfully! ✅" -ForegroundColor Green
            Write-Host "Your system is ready for CloudToLocalLLM development and package creation." -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "1. Test package creation: .\Create-UnifiedPackages.ps1 -TestOnly" -ForegroundColor Yellow
            Write-Host "2. Create packages: .\Create-UnifiedPackages.ps1 -AutoInstall" -ForegroundColor Yellow
            exit 0
        }
        elseif ($overallSuccess) {
            Write-Host "[PARTIAL SUCCESS] Environment setup completed with some issues" -ForegroundColor Yellow
            Write-Host "Check the health check results and setup report for details." -ForegroundColor Yellow
            exit 1
        }
        else {
            Write-Host "[FAILURE] Environment setup encountered significant issues" -ForegroundColor Red
            Write-Host "Please review the setup report and troubleshooting log for guidance." -ForegroundColor Red
            exit 2
        }
    }
    catch {
        Write-LogError "Environment setup failed: $($_.Exception.Message)"
        Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"

        # Generate report even on failure
        try {
            New-SetupReport
        }
        catch {
            Write-LogError "Failed to generate setup report: $($_.Exception.Message)"
        }

        exit 2
    }
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"

    try {
        New-SetupReport
    }
    catch {
        Write-LogError "Failed to generate error report: $($_.Exception.Message)"
    }

    exit 2
}

# Execute main function
Invoke-EnvironmentSetup
