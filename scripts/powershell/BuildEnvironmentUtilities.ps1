# CloudToLocalLLM PowerShell Utilities
# Common functions for WSL integration, logging, and cross-platform operations

[CmdletBinding()]
param()

# Color constants for console output
$Script:Colors = @{
    Red    = 'Red'
    Green  = 'Green'
    Yellow = 'Yellow'
    Blue   = 'Blue'
    Cyan   = 'Cyan'
    White  = 'White'
}

# Logging functions with colored output
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Script:Colors.Blue
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Script:Colors.Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Script:Colors.Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Script:Colors.Red
}

# Test if WSL is available on the system
function Test-WSLAvailable {
    [CmdletBinding()]
    param()
    
    try {
        $null = wsl --list --quiet 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# Get list of installed WSL distributions
function Get-WSLDistributions {
    [CmdletBinding()]
    param()
    
    if (-not (Test-WSLAvailable)) {
        return @()
    }
    
    try {
        $output = wsl --list --verbose 2>$null
        $distributions = @()
        
        foreach ($line in $output) {
            if ($line -match '^\s*\*?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                $distributions += @{
                    Name = $matches[1]
                    State = $matches[2]
                    Version = $matches[3]
                    IsDefault = $line.StartsWith('*')
                }
            }
        }
        
        return $distributions
    }
    catch {
        Write-LogError "Failed to get WSL distributions: $($_.Exception.Message)"
        return @()
    }
}

# Test if a specific WSL distribution is available and running
function Test-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName
    )
    
    $distributions = Get-WSLDistributions
    $distro = $distributions | Where-Object { $_.Name -eq $DistroName }
    
    return ($null -ne $distro -and $distro.State -eq 'Running')
}

# Find the best WSL distribution for a specific purpose
function Find-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Arch', 'Ubuntu', 'Debian', 'Any')]
        [string]$Purpose
    )
    
    $distributions = Get-WSLDistributions
    
    switch ($Purpose) {
        'Arch' {
            $candidates = @('Arch', 'ArchLinux', 'Manjaro', 'EndeavourOS')
        }
        'Ubuntu' {
            $candidates = @('Ubuntu', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-24.04')
        }
        'Debian' {
            $candidates = @('Debian', 'Ubuntu', 'Ubuntu-20.04', 'Ubuntu-22.04', 'Ubuntu-24.04')
        }
        'Any' {
            $candidates = $distributions | ForEach-Object { $_.Name }
        }
    }
    
    foreach ($candidate in $candidates) {
        $distro = $distributions | Where-Object { $_.Name -like "*$candidate*" -and $_.State -eq 'Running' }
        if ($distro) {
            return $distro.Name
        }
    }
    
    return $null
}

# Convert Windows path to WSL path format
function Convert-WindowsPathToWSL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )
    
    # Convert C:\Users\... to /mnt/c/Users/...
    $wslPath = $WindowsPath -replace '^([A-Za-z]):', '/mnt/$1'
    $wslPath = $wslPath -replace '\\', '/'
    $wslPath = $wslPath.ToLower()
    
    return $wslPath
}

# Convert WSL path to Windows path format
function Convert-WSLPathToWindows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WSLPath
    )
    
    # Convert /mnt/c/Users/... to C:\Users\...
    if ($WSLPath -match '^/mnt/([a-z])/(.*)') {
        $drive = $matches[1].ToUpper()
        $path = $matches[2] -replace '/', '\'
        return "${drive}:\$path"
    }
    
    return $WSLPath
}

# Execute a command in WSL
function Invoke-WSLCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,
        
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [string]$WorkingDirectory = $null,
        
        [switch]$PassThru
    )
    
    if (-not (Test-WSLDistribution -DistroName $DistroName)) {
        throw "WSL distribution '$DistroName' is not available or not running"
    }
    
    $wslCommand = "wsl -d $DistroName"
    
    if ($WorkingDirectory) {
        $wslPath = Convert-WindowsPathToWSL -WindowsPath $WorkingDirectory
        $wslCommand += " --cd `"$wslPath`""
    }
    
    $wslCommand += " -- $Command"
    
    if ($PassThru) {
        return Invoke-Expression $wslCommand
    }
    else {
        Invoke-Expression $wslCommand
    }
}

# Test if a command is available in the current environment
function Test-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )
    
    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

# Test if a command is available in WSL
function Test-WSLCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,

        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    try {
        # Use a more reliable approach to test command availability
        $result = wsl -d $DistroName -- bash -c "command -v $CommandName >/dev/null 2>&1; echo `$?"
        return $result.Trim() -eq "0"
    }
    catch {
        return $false
    }
}

# Get the project root directory
function Get-ProjectRoot {
    [CmdletBinding()]
    param()
    
    $scriptDir = Split-Path -Parent $PSScriptRoot
    return Split-Path -Parent $scriptDir
}

# Ensure directory exists (using approved verb)
function New-DirectoryIfNotExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-LogInfo "Created directory: $Path"
    }
}

# Get file hash (SHA256)
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

# Install Chocolatey package manager
function Install-Chocolatey {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    # Check if Chocolatey is already installed
    if ((Test-Command "choco") -and -not $Force) {
        Write-LogInfo "Chocolatey is already installed"
        return $true
    }

    Write-LogInfo "Installing Chocolatey package manager..."

    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

        if (-not $isAdmin) {
            Write-LogWarning "Chocolatey installation requires administrator privileges"
            Write-LogInfo "Please run PowerShell as Administrator or install Chocolatey manually"
            return $false
        }

        # Set execution policy for this process
        Set-ExecutionPolicy Bypass -Scope Process -Force

        # Set security protocol
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        # Download and execute Chocolatey installation script
        $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
        Invoke-Expression $installScript

        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        # Verify installation
        if (Test-Command "choco") {
            Write-LogSuccess "Chocolatey installed successfully"

            # Show version
            $chocoVersion = choco --version
            Write-LogInfo "Chocolatey version: $chocoVersion"

            return $true
        }
        else {
            throw "Chocolatey installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install Chocolatey: $($_.Exception.Message)"
        Write-LogInfo "Manual installation: https://chocolatey.org/install"
        return $false
    }
}

# Install package using Chocolatey with user consent
function Install-ChocolateyPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [string]$VerifyCommand,

        [string]$EstimatedTime = "2-5 minutes",

        [string]$DiskSpace = "100-500 MB",

        [switch]$AutoInstall,

        [switch]$RequiresRestart
    )

    Write-LogInfo "Checking for $DisplayName..."

    # Check if package is already installed via Chocolatey
    try {
        $chocoList = choco list --local-only $PackageName --exact --limit-output
        if ($chocoList -and $chocoList -notlike "*0 packages installed*") {
            Write-LogSuccess "$DisplayName is already installed via Chocolatey"
            return $true
        }
    }
    catch {
        # Chocolatey might not be available, continue with verification command
    }

    # Check if software is available via verification command
    if ($VerifyCommand) {
        try {
            Invoke-Expression $VerifyCommand | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "$DisplayName is already available"
                return $true
            }
        }
        catch {
            # Software not available, proceed with installation
        }
    }

    # Prompt user for installation consent
    if (-not $AutoInstall) {
        Write-Host ""
        Write-Host "[PACKAGE] Package Installation Required" -ForegroundColor Yellow
        Write-Host "================================" -ForegroundColor Yellow
        Write-Host "Package: $DisplayName"
        Write-Host "Estimated Time: $EstimatedTime"
        Write-Host "Disk Space: $DiskSpace"
        if ($RequiresRestart) {
            Write-Host "[WARNING] May require system restart" -ForegroundColor Yellow
        }
        Write-Host ""

        Write-LogWarning "Automated mode: Use -AutoInstall parameter to install dependencies automatically"
        Write-LogWarning "Skipping installation of $DisplayName"
        Write-LogInfo "Manual installation required. Please install $DisplayName and run the script again."
        return $false
    }

    # Ensure Chocolatey is installed
    if (-not (Install-Chocolatey)) {
        Write-LogError "Cannot install $DisplayName without Chocolatey"
        return $false
    }

    Write-LogInfo "Installing $DisplayName via Chocolatey..."
    Write-LogInfo "This may take $EstimatedTime and use approximately $DiskSpace of disk space"

    # Install with retry logic
    $maxRetries = 3
    $retryCount = 0

    while ($retryCount -lt $maxRetries) {
        try {
            $retryCount++
            Write-LogInfo "Installation attempt $retryCount of $maxRetries..."

            # Execute Chocolatey installation
            choco install $PackageName --yes --no-progress

            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "$DisplayName installed successfully"

                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

                # Verify installation
                if ($VerifyCommand) {
                    Start-Sleep -Seconds 2  # Allow time for installation to complete
                    try {
                        Invoke-Expression $VerifyCommand | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogSuccess "$DisplayName verification passed"
                            return $true
                        }
                        else {
                            throw "Verification command failed"
                        }
                    }
                    catch {
                        Write-LogWarning "$DisplayName installed but verification failed: $($_.Exception.Message)"
                        Write-LogInfo "The software may still be functional. Continuing..."
                        return $true
                    }
                }

                return $true
            }
            else {
                throw "Chocolatey installation failed with exit code $LASTEXITCODE"
            }
        }
        catch {
            Write-LogWarning "Installation attempt $retryCount failed: $($_.Exception.Message)"

            if ($retryCount -lt $maxRetries) {
                Write-LogInfo "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
            else {
                Write-LogError "Failed to install $DisplayName after $maxRetries attempts"
                Write-LogInfo "Please install $DisplayName manually and run the script again"
                return $false
            }
        }
    }

    return $false
}

# Install Windows built-in OpenSSH client
function Install-OpenSSHClient {
    [CmdletBinding()]
    param(
        [switch]$AutoInstall
    )

    Write-LogInfo "Checking for OpenSSH Client..."

    # Check if OpenSSH client is already available
    if (Test-Command "ssh") {
        Write-LogSuccess "OpenSSH Client is already available"
        return $true
    }

    # Check if running on Windows 10/11
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-LogError "OpenSSH Client requires Windows 10 or later"
        return $false
    }

    # Prompt user for installation consent
    if (-not $AutoInstall) {
        Write-Host ""
        Write-Host "[OPENSSH] OpenSSH Client Installation" -ForegroundColor Yellow
        Write-Host "==============================" -ForegroundColor Yellow
        Write-Host "OpenSSH Client is required for VPS deployment operations."
        Write-Host "This will install the Windows built-in OpenSSH client feature."
        Write-Host ""

        Write-LogWarning "Automated mode: Use -AutoInstall parameter to install OpenSSH Client automatically"
        Write-LogWarning "Skipping OpenSSH Client installation"
        return $false
    }

    Write-LogInfo "Installing OpenSSH Client..."

    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

        if (-not $isAdmin) {
            Write-LogWarning "OpenSSH Client installation requires administrator privileges"
            Write-LogInfo "Please run PowerShell as Administrator"
            return $false
        }

        # Install OpenSSH Client capability
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

        # Verify installation
        if (Test-Command "ssh") {
            Write-LogSuccess "OpenSSH Client installed successfully"
            return $true
        }
        else {
            throw "OpenSSH Client installation verification failed"
        }
    }
    catch {
        Write-LogError "Failed to install OpenSSH Client: $($_.Exception.Message)"
        Write-LogInfo "Try installing via Settings > Apps > Optional Features > OpenSSH Client"
        return $false
    }
}

# Synchronize SSH keys from WSL to Windows
function Sync-SSHKeys {
    [CmdletBinding()]
    param(
        [string]$SourceDistro,
        [switch]$Force,
        [switch]$AutoSync
    )

    Write-LogInfo "Starting SSH key synchronization..."

    # Define key types to look for
    $keyTypes = @(
        @{ Name = "RSA"; PrivateKey = "id_rsa"; PublicKey = "id_rsa.pub" },
        @{ Name = "ED25519"; PrivateKey = "id_ed25519"; PublicKey = "id_ed25519.pub" },
        @{ Name = "ECDSA"; PrivateKey = "id_ecdsa"; PublicKey = "id_ecdsa.pub" }
    )

    # Windows SSH directory
    $windowsSSHDir = Join-Path $env:USERPROFILE ".ssh"
    $backupDir = Join-Path $windowsSSHDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

    # Find WSL distribution with SSH keys
    $sourceDistribution = $SourceDistro
    if (-not $sourceDistribution) {
        Write-LogInfo "Scanning WSL distributions for SSH keys..."

        $distributions = Get-WSLDistributions
        $foundKeys = @()

        foreach ($distro in $distributions) {
            if ($distro.State -eq "Running") {
                try {
                    $hasKeys = Invoke-WSLCommand -DistroName $distro.Name -Command "test -d ~/.ssh && ls ~/.ssh/id_* 2>/dev/null | wc -l" -PassThru
                    if ([int]$hasKeys.Trim() -gt 0) {
                        $foundKeys += @{ Distro = $distro.Name; KeyCount = [int]$hasKeys.Trim() }
                    }
                }
                catch {
                    # Continue checking other distributions
                }
            }
        }

        if ($foundKeys.Count -eq 0) {
            Write-LogWarning "No SSH keys found in any WSL distribution"
            return $false
        }

        # Prioritize Arch Linux, then by key count
        $sourceDistribution = ($foundKeys | Sort-Object @{Expression={if($_.Distro -like "*Arch*") {0} else {1}}}, @{Expression={$_.KeyCount}; Descending=$true} | Select-Object -First 1).Distro
        Write-LogInfo "Selected WSL distribution: $sourceDistribution"
    }

    # Verify source distribution has SSH keys
    try {
        $keyList = Invoke-WSLCommand -DistroName $sourceDistribution -Command "ls ~/.ssh/id_* 2>/dev/null || echo 'NO_KEYS'" -PassThru
        if ($keyList -eq "NO_KEYS" -or -not $keyList) {
            Write-LogError "No SSH keys found in WSL distribution: $sourceDistribution"
            return $false
        }
    }
    catch {
        Write-LogError "Failed to access SSH keys in WSL distribution: $sourceDistribution"
        return $false
    }

    # Create Windows SSH directory
    New-DirectoryIfNotExists -Path $windowsSSHDir

    # Check for existing keys and create backup if needed
    $existingKeys = Get-ChildItem -Path $windowsSSHDir -Filter "id_*" -ErrorAction SilentlyContinue
    if ($existingKeys -and -not $Force) {
        if (-not $AutoSync) {
            Write-Host ""
            Write-Host "[SSH] SSH Key Synchronization" -ForegroundColor Yellow
            Write-Host "==========================" -ForegroundColor Yellow
            Write-Host "Existing SSH keys found in Windows SSH directory:"
            $existingKeys | ForEach-Object { Write-Host "  - $($_.Name)" }
            Write-Host ""
            Write-Host "A backup will be created before synchronization."
            Write-Host ""

            Write-LogWarning "Automated mode: Use -AutoSync parameter to synchronize SSH keys automatically"
            Write-LogWarning "Skipping SSH key synchronization"
            return $false
        }

        # Create backup
        Write-LogInfo "Creating backup of existing SSH keys..."
        New-DirectoryIfNotExists -Path $backupDir
        $existingKeys | ForEach-Object {
            Copy-Item $_.FullName $backupDir -Force
        }
        Write-LogSuccess "Backup created: $backupDir"
    }

    # Synchronize each key type
    $syncedKeys = @()
    foreach ($keyType in $keyTypes) {
        try {
            # Check if key exists in WSL
            $privateKeyExists = Invoke-WSLCommand -DistroName $sourceDistribution -Command "test -f ~/.ssh/$($keyType.PrivateKey) && echo 'EXISTS'" -PassThru
            $publicKeyExists = Invoke-WSLCommand -DistroName $sourceDistribution -Command "test -f ~/.ssh/$($keyType.PublicKey) && echo 'EXISTS'" -PassThru

            if ($privateKeyExists -eq "EXISTS" -and $publicKeyExists -eq "EXISTS") {
                Write-LogInfo "Synchronizing $($keyType.Name) key pair..."

                # Copy private key
                $privateKeyPath = Join-Path $windowsSSHDir $keyType.PrivateKey
                $wslPrivateKeyPath = "~/.ssh/$($keyType.PrivateKey)"
                Invoke-WSLCommand -DistroName $sourceDistribution -Command "cat $wslPrivateKeyPath" -PassThru | Set-Content -Path $privateKeyPath -Encoding UTF8

                # Copy public key
                $publicKeyPath = Join-Path $windowsSSHDir $keyType.PublicKey
                $wslPublicKeyPath = "~/.ssh/$($keyType.PublicKey)"
                Invoke-WSLCommand -DistroName $sourceDistribution -Command "cat $wslPublicKeyPath" -PassThru | Set-Content -Path $publicKeyPath -Encoding UTF8

                # Set Windows file permissions
                Set-SSHKeyPermissions -KeyPath $privateKeyPath

                $syncedKeys += $keyType.Name
                Write-LogSuccess "$($keyType.Name) key pair synchronized"
            }
        }
        catch {
            Write-LogWarning "Failed to synchronize $($keyType.Name) key: $($_.Exception.Message)"
        }
    }

    if ($syncedKeys.Count -gt 0) {
        Write-LogSuccess "SSH key synchronization completed"
        Write-LogInfo "Synchronized key types: $($syncedKeys -join ', ')"

        # Update SSH config if needed
        Update-SSHConfig

        return $true
    }
    else {
        Write-LogError "No SSH keys were synchronized"
        return $false
    }
}

# Set proper Windows file permissions for SSH private keys
function Set-SSHKeyPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyPath
    )

    if (-not (Test-Path $KeyPath)) {
        Write-LogError "SSH key not found: $KeyPath"
        return $false
    }

    try {
        Write-LogInfo "Setting secure permissions for SSH key: $(Split-Path -Leaf $KeyPath)"

        # Remove inheritance and explicit permissions
        icacls $KeyPath /inheritance:r /grant:r "$($env:USERNAME):F" /remove "Everyone" /remove "Users" /remove "Authenticated Users" 2>$null | Out-Null

        # Verify permissions were set correctly
        $acl = Get-Acl $KeyPath
        $accessRules = $acl.Access | Where-Object { $_.IdentityReference -like "*$env:USERNAME*" -and $_.FileSystemRights -like "*FullControl*" }

        if ($accessRules) {
            Write-LogSuccess "SSH key permissions set successfully"
            return $true
        }
        else {
            throw "Permission verification failed"
        }
    }
    catch {
        Write-LogError "Failed to set SSH key permissions: $($_.Exception.Message)"
        return $false
    }
}

# Update SSH config file with VPS host configurations
function Update-SSHConfig {
    [CmdletBinding()]
    param(
        [string]$VPSHost = "cloudtolocalllm.online",
        [string]$VPSUser = "cloudllm"
    )

    $sshConfigPath = Join-Path $env:USERPROFILE ".ssh\config"
    $configEntry = @"

# CloudToLocalLLM VPS Configuration (Auto-generated)
Host cloudtolocalllm
    HostName $VPSHost
    User $VPSUser
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa
    IdentityFile ~/.ssh/id_ecdsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host $VPSHost
    User $VPSUser
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa
    IdentityFile ~/.ssh/id_ecdsa
    ServerAliveInterval 60
    ServerAliveCountMax 3

"@

    try {
        # Check if config already contains CloudToLocalLLM entries
        if (Test-Path $sshConfigPath) {
            $existingConfig = Get-Content $sshConfigPath -Raw
            if ($existingConfig -like "*CloudToLocalLLM VPS Configuration*") {
                Write-LogInfo "SSH config already contains CloudToLocalLLM VPS configuration"
                return $true
            }
        }

        # Append configuration
        Add-Content -Path $sshConfigPath -Value $configEntry -Encoding UTF8
        Write-LogSuccess "SSH config updated with VPS configuration"
        return $true
    }
    catch {
        Write-LogError "Failed to update SSH config: $($_.Exception.Message)"
        return $false
    }
}

# Test SSH connectivity to VPS
function Test-SSHConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VPSHost,

        [Parameter(Mandatory = $true)]
        [string]$VPSUser,

        [int]$TimeoutSeconds = 10
    )

    Write-LogInfo "Testing SSH connectivity to $VPSUser@$VPSHost..."

    try {
        # Test SSH connection with timeout
        $testCommand = "ssh -o ConnectTimeout=$TimeoutSeconds -o BatchMode=yes -o StrictHostKeyChecking=no $VPSUser@$VPSHost 'echo SSH_TEST_SUCCESS'"
        $result = Invoke-Expression $testCommand 2>$null

        if ($result -like "*SSH_TEST_SUCCESS*") {
            Write-LogSuccess "SSH connectivity test passed"
            return $true
        }
        else {
            throw "SSH test command did not return expected result"
        }
    }
    catch {
        Write-LogError "SSH connectivity test failed: $($_.Exception.Message)"
        Write-LogInfo "Ensure SSH keys are properly configured and the VPS is accessible"
        return $false
    }
}

# Comprehensive dependency installation function
function Install-BuildDependencies {
    [CmdletBinding()]
    param(
        [switch]$AutoInstall,
        [switch]$SkipDependencyCheck,
        [string[]]$RequiredPackages = @('flutter', 'git', 'openssh')
    )

    if ($SkipDependencyCheck) {
        Write-LogWarning "Skipping dependency check as requested"
        return $true
    }

    Write-LogInfo "Checking build dependencies..."

    $installationResults = @()
    $allSuccessful = $true

    # Install Chocolatey first if needed
    if ($RequiredPackages -contains 'flutter' -or $RequiredPackages -contains 'git' -or $RequiredPackages -contains 'docker' -or $RequiredPackages -contains '7zip' -or $RequiredPackages -contains 'visualstudio') {
        if (-not (Install-Chocolatey)) {
            Write-LogError "Cannot proceed with dependency installation without Chocolatey"
            return $false
        }
    }

    # Define package configurations
    $packageConfigs = @{
        'flutter' = @{
            PackageName = 'flutter'
            DisplayName = 'Flutter SDK'
            VerifyCommand = 'flutter --version'
            EstimatedTime = '5-10 minutes'
            DiskSpace = '1-2 GB'
        }
        'git' = @{
            PackageName = 'git'
            DisplayName = 'Git for Windows'
            VerifyCommand = 'git --version'
            EstimatedTime = '2-3 minutes'
            DiskSpace = '100-200 MB'
        }
        'docker' = @{
            PackageName = 'docker-desktop'
            DisplayName = 'Docker Desktop'
            VerifyCommand = 'docker --version'
            EstimatedTime = '10-15 minutes'
            DiskSpace = '2-3 GB'
            RequiresRestart = $true
        }
        '7zip' = @{
            PackageName = '7zip'
            DisplayName = '7-Zip'
            VerifyCommand = '7z'
            EstimatedTime = '1-2 minutes'
            DiskSpace = '50-100 MB'
        }
        'visualstudio' = @{
            PackageName = 'visualstudio2022buildtools'
            DisplayName = 'Visual Studio Build Tools'
            VerifyCommand = 'where cl'
            EstimatedTime = '15-30 minutes'
            DiskSpace = '3-5 GB'
        }
    }

    # Install each required package
    foreach ($package in $RequiredPackages) {
        if ($package -eq 'openssh') {
            # Handle OpenSSH separately as it's a Windows feature
            $result = Install-OpenSSHClient -AutoInstall:$AutoInstall
            $installationResults += @{ Package = 'OpenSSH Client'; Success = $result }
            if (-not $result) { $allSuccessful = $false }
        }
        elseif ($packageConfigs.ContainsKey($package)) {
            $config = $packageConfigs[$package]
            $installParams = @{
                PackageName = $config.PackageName
                DisplayName = $config.DisplayName
                VerifyCommand = $config.VerifyCommand
                AutoInstall = $AutoInstall
            }
            if ($config.EstimatedTime) { $installParams.EstimatedTime = $config.EstimatedTime }
            if ($config.DiskSpace) { $installParams.DiskSpace = $config.DiskSpace }
            if ($config.RequiresRestart) { $installParams.RequiresRestart = $config.RequiresRestart }

            $result = Install-ChocolateyPackage @installParams
            $installationResults += @{ Package = $config.DisplayName; Success = $result }
            if (-not $result) { $allSuccessful = $false }
        }
        else {
            Write-LogWarning "Unknown package: $package"
        }
    }

    # Show installation summary
    Write-Host ""
    Write-Host "[SUMMARY] Dependency Installation Summary" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    foreach ($result in $installationResults) {
        $status = if ($result.Success) { "[OK] Installed" } else { "[FAIL] Failed" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        Write-Host "$status $($result.Package)" -ForegroundColor $color
    }
    Write-Host ""

    if ($allSuccessful) {
        Write-LogSuccess "All dependencies installed successfully"

        # Check if restart is recommended
        $restartPackages = $installationResults | Where-Object { $_.Package -like "*Docker*" -and $_.Success }
        if ($restartPackages) {
            Write-LogWarning "System restart recommended for Docker Desktop to function properly"
        }
    }
    else {
        Write-LogError "Some dependencies failed to install"
        Write-LogInfo "Please install missing dependencies manually and run the script again"
    }

    return $allSuccessful
}

# Export all functions (only when loaded as a module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # Script is being dot-sourced, functions are automatically available
} else {
    Export-ModuleMember -Function *
}
