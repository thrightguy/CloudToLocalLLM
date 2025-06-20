# CloudToLocalLLM Environment Testing Script
# Validates the entire build environment and dependencies

[CmdletBinding()]
param(
    [switch]$AutoInstall,
    [switch]$Detailed,
    [switch]$FixIssues,
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
    Write-Host "CloudToLocalLLM Environment Testing Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\Test-Environment.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -AutoInstall  Automatically install missing dependencies"
    Write-Host "  -Detailed     Show detailed information about each component"
    Write-Host "  -FixIssues    Attempt to fix detected issues"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    Write-Host "This script validates:" -ForegroundColor Yellow
    Write-Host "  • PowerShell version and capabilities"
    Write-Host "  • Windows version and features"
    Write-Host "  • WSL availability and distributions"
    Write-Host "  • Build dependencies (Flutter, Git, Docker, etc.)"
    Write-Host "  • SSH configuration and connectivity"
    Write-Host "  • Project structure and files"
    exit 0
}

# Test results tracking
$script:TestResults = @()
$script:IssuesFound = @()
$script:FixesApplied = @()

function Add-TestResult {
    param(
        [string]$Component,
        [string]$Test,
        [bool]$Passed,
        [string]$Details = "",
        [string]$Recommendation = ""
    )
    
    $script:TestResults += @{
        Component = $Component
        Test = $Test
        Passed = $Passed
        Details = $Details
        Recommendation = $Recommendation
    }
    
    if (-not $Passed) {
        $script:IssuesFound += "$Component - ${Test}: $Details"
    }
}

function Test-PowerShellEnvironment {
    Write-LogInfo "Testing PowerShell environment..."
    
    # PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    $versionOk = $psVersion.Major -ge 5
    Add-TestResult -Component "PowerShell" -Test "Version" -Passed $versionOk -Details "Version $psVersion" -Recommendation "PowerShell 5.1+ required"
    
    # Execution policy
    $executionPolicy = Get-ExecutionPolicy
    $policyOk = $executionPolicy -notin @('Restricted', 'AllSigned')
    Add-TestResult -Component "PowerShell" -Test "Execution Policy" -Passed $policyOk -Details $executionPolicy -Recommendation "Set-ExecutionPolicy RemoteSigned"
    
    # Administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Add-TestResult -Component "PowerShell" -Test "Admin Privileges" -Passed $isAdmin -Details "Running as $(if($isAdmin){'Administrator'}else{'User'})" -Recommendation "Some operations require administrator privileges"
    
    if ($Detailed) {
        Write-Host "  PowerShell Version: $psVersion" -ForegroundColor $(if($versionOk){'Green'}else{'Red'})
        Write-Host "  Execution Policy: $executionPolicy" -ForegroundColor $(if($policyOk){'Green'}else{'Red'})
        Write-Host "  Administrator: $(if($isAdmin){'Yes'}else{'No'})" -ForegroundColor $(if($isAdmin){'Green'}else{'Yellow'})
    }
}

function Test-WindowsEnvironment {
    Write-LogInfo "Testing Windows environment..."
    
    # Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    $versionOk = $osVersion.Major -ge 10
    Add-TestResult -Component "Windows" -Test "Version" -Passed $versionOk -Details "Version $($osVersion.Major).$($osVersion.Minor)" -Recommendation "Windows 10+ required for WSL 2"
    
    # WSL feature
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
    $wslEnabled = $wslFeature -and $wslFeature.State -eq 'Enabled'
    Add-TestResult -Component "Windows" -Test "WSL Feature" -Passed $wslEnabled -Details "WSL $(if($wslEnabled){'Enabled'}else{'Disabled'})" -Recommendation "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"
    
    # Hyper-V (for WSL 2)
    $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    $hyperVEnabled = $hyperVFeature -and $hyperVFeature.State -eq 'Enabled'
    Add-TestResult -Component "Windows" -Test "Hyper-V" -Passed $hyperVEnabled -Details "Hyper-V $(if($hyperVEnabled){'Enabled'}else{'Disabled'})" -Recommendation "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All"
    
    if ($Detailed) {
        Write-Host "  Windows Version: $($osVersion.Major).$($osVersion.Minor)" -ForegroundColor $(if($versionOk){'Green'}else{'Red'})
        Write-Host "  WSL Feature: $(if($wslEnabled){'Enabled'}else{'Disabled'})" -ForegroundColor $(if($wslEnabled){'Green'}else{'Red'})
        Write-Host "  Hyper-V: $(if($hyperVEnabled){'Enabled'}else{'Disabled'})" -ForegroundColor $(if($hyperVEnabled){'Green'}else{'Yellow'})
    }
}

function Test-WSLEnvironment {
    Write-LogInfo "Testing WSL environment..."
    
    # WSL availability
    $wslAvailable = Test-WSLAvailable
    Add-TestResult -Component "WSL" -Test "Availability" -Passed $wslAvailable -Details "WSL $(if($wslAvailable){'Available'}else{'Not Available'})" -Recommendation "Install WSL: wsl --install"
    
    if ($wslAvailable) {
        # WSL distributions
        $distributions = Get-WSLDistributions
        $hasDistros = $distributions.Count -gt 0
        Add-TestResult -Component "WSL" -Test "Distributions" -Passed $hasDistros -Details "$($distributions.Count) distributions found" -Recommendation "Install distributions: wsl --install -d Ubuntu"
        
        # Check for Arch Linux (for AUR)
        $archDistro = Find-WSLDistribution -Purpose 'Arch'
        $hasArch = $null -ne $archDistro
        Add-TestResult -Component "WSL" -Test "Arch Linux" -Passed $hasArch -Details "Arch Linux $(if($hasArch){'Available'}else{'Not Found'})" -Recommendation "Install Arch Linux for AUR package creation"
        
        # Check for Ubuntu/Debian (for DEB)
        $debianDistro = Find-WSLDistribution -Purpose 'Debian'
        $hasDebian = $null -ne $debianDistro
        Add-TestResult -Component "WSL" -Test "Ubuntu/Debian" -Passed $hasDebian -Details "Ubuntu/Debian $(if($hasDebian){'Available'}else{'Not Found'})" -Recommendation "Install Ubuntu for Debian package creation"
        
        if ($Detailed) {
            Write-Host "  WSL Distributions:" -ForegroundColor Green
            foreach ($distro in $distributions) {
                $status = if ($distro.State -eq "Running") { "Green" } else { "Yellow" }
                Write-Host "    - $($distro.Name) ($($distro.State))" -ForegroundColor $status
            }
        }
    }
}

function Test-BuildDependencies {
    Write-LogInfo "Testing build dependencies..."
    
    # Define dependencies to test
    $dependencies = @{
        'Flutter' = @{ Command = 'flutter'; Package = 'flutter'; Required = $true }
        'Git' = @{ Command = 'git'; Package = 'git'; Required = $true }
        'Docker' = @{ Command = 'docker'; Package = 'docker-desktop'; Required = $false }
        'SSH' = @{ Command = 'ssh'; Package = 'openssh'; Required = $true }
        '7-Zip' = @{ Command = '7z'; Package = '7zip'; Required = $false }
    }
    
    foreach ($dep in $dependencies.GetEnumerator()) {
        $name = $dep.Key
        $config = $dep.Value
        
        $available = Test-Command $config.Command
        Add-TestResult -Component "Dependencies" -Test $name -Passed $available -Details "$name $(if($available){'Available'}else{'Not Found'})" -Recommendation "Install via Chocolatey: choco install $($config.Package)"
        
        if ($Detailed) {
            $color = if ($available) { 'Green' } elseif ($config.Required) { 'Red' } else { 'Yellow' }
            Write-Host "  $name`: $(if($available){'[OK] Available'}else{'[MISSING] Missing'})" -ForegroundColor $color
        }
        
        # Auto-install if requested and missing
        if (-not $available -and $AutoInstall -and $config.Required) {
            Write-LogInfo "Auto-installing $name..."
            if (Install-BuildDependencies -RequiredPackages @($config.Package) -AutoInstall) {
                $script:FixesApplied += "Installed $name"
            }
        }
    }
}

function Test-SSHConfiguration {
    Write-LogInfo "Testing SSH configuration..."
    
    # SSH directory
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $sshDirExists = Test-Path $sshDir
    Add-TestResult -Component "SSH" -Test "SSH Directory" -Passed $sshDirExists -Details "SSH directory $(if($sshDirExists){'exists'}else{'missing'})" -Recommendation "Create SSH directory and generate keys"
    
    if ($sshDirExists) {
        # SSH keys
        $keyTypes = @('id_rsa', 'id_ed25519', 'id_ecdsa')
        $foundKeys = @()
        
        foreach ($keyType in $keyTypes) {
            $privateKey = Join-Path $sshDir $keyType
            $publicKey = Join-Path $sshDir "$keyType.pub"
            
            if ((Test-Path $privateKey) -and (Test-Path $publicKey)) {
                $foundKeys += $keyType
            }
        }
        
        $hasKeys = $foundKeys.Count -gt 0
        Add-TestResult -Component "SSH" -Test "SSH Keys" -Passed $hasKeys -Details "Found keys: $($foundKeys -join ', ')" -Recommendation "Generate SSH keys: ssh-keygen -t ed25519"
        
        # SSH config
        $sshConfig = Join-Path $sshDir "config"
        $hasConfig = Test-Path $sshConfig
        Add-TestResult -Component "SSH" -Test "SSH Config" -Passed $hasConfig -Details "SSH config $(if($hasConfig){'exists'}else{'missing'})" -Recommendation "Create SSH config for VPS hosts"
        
        if ($Detailed) {
            Write-Host "  SSH Keys: $($foundKeys -join ', ')" -ForegroundColor $(if($hasKeys){'Green'}else{'Red'})
            Write-Host "  SSH Config: $(if($hasConfig){'Present'}else{'Missing'})" -ForegroundColor $(if($hasConfig){'Green'}else{'Yellow'})
        }
    }
}

function Test-ProjectStructure {
    Write-LogInfo "Testing project structure..."
    
    $projectRoot = Get-ProjectRoot
    
    # Essential files
    $essentialFiles = @(
        'pubspec.yaml',
        'lib/main.dart',
        'lib/config/app_config.dart'
    )
    
    foreach ($file in $essentialFiles) {
        $filePath = Join-Path $projectRoot $file
        $exists = Test-Path $filePath
        Add-TestResult -Component "Project" -Test "File: $file" -Passed $exists -Details "$(if($exists){'Present'}else{'Missing'})" -Recommendation "Ensure Flutter project structure is complete"
        
        if ($Detailed) {
            Write-Host "  $file`: $(if($exists){'[OK] Present'}else{'[MISSING] Missing'})" -ForegroundColor $(if($exists){'Green'}else{'Red'})
        }
    }
    
    # Build scripts
    $scriptDir = Join-Path $projectRoot "scripts\powershell"
    $scriptExists = Test-Path $scriptDir
    Add-TestResult -Component "Project" -Test "PowerShell Scripts" -Passed $scriptExists -Details "PowerShell scripts $(if($scriptExists){'present'}else{'missing'})" -Recommendation "Ensure PowerShell build scripts are available"
}

function Show-TestSummary {
    Write-Host ""
    Write-Host "[SUMMARY] Environment Test Summary" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    
    $totalTests = $script:TestResults.Count
    $passedTests = ($script:TestResults | Where-Object { $_.Passed }).Count
    $failedTests = $totalTests - $passedTests
    
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $failedTests" -ForegroundColor $(if($failedTests -eq 0){'Green'}else{'Red'})
    
    if ($script:IssuesFound.Count -gt 0) {
        Write-Host ""
        Write-Host "[ISSUES] Issues Found:" -ForegroundColor Red
        foreach ($issue in $script:IssuesFound) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    if ($script:FixesApplied.Count -gt 0) {
        Write-Host ""
        Write-Host "[FIXES] Fixes Applied:" -ForegroundColor Green
        foreach ($fix in $script:FixesApplied) {
            Write-Host "  • $fix" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    if ($failedTests -eq 0) {
        Write-Host "[SUCCESS] Environment is ready for CloudToLocalLLM development!" -ForegroundColor Green
    }
    else {
        Write-Host "[WARNING] Environment has issues that should be addressed." -ForegroundColor Yellow
        Write-Host "Run with -AutoInstall to automatically fix dependency issues." -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "CloudToLocalLLM Environment Testing Script" -ForegroundColor Blue
Write-Host "===========================================" -ForegroundColor Blue
Write-Host ""

Test-PowerShellEnvironment
Test-WindowsEnvironment
Test-WSLEnvironment
Test-BuildDependencies
Test-SSHConfiguration
Test-ProjectStructure

Show-TestSummary
