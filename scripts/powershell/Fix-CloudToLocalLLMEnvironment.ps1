#!/usr/bin/env pwsh
# CloudToLocalLLM Environment Fix Script
# Implements critical fixes identified in testing analysis

param(
    [switch]$SkipDocker,
    [switch]$SkipOllama,
    [switch]$SkipWSL,
    [switch]$SkipTests,
    [switch]$SkipSSH,
    [switch]$Force,
    [switch]$Help
)

# Import utilities
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    Write-Error "BuildEnvironmentUtilities module not found at $utilsPath"
    exit 1
}

function Show-Help {
    Write-Host "CloudToLocalLLM Environment Fix Script" -ForegroundColor Blue
    Write-Host "=====================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "This script implements critical fixes identified in testing analysis:"
    Write-Host "1. Install Docker Desktop (with UAC elevation)"
    Write-Host "2. Install Ollama models (llama3.2:1b)"
    Write-Host "3. Enable Windows WSL features (with UAC elevation)"
    Write-Host "4. Fix test environment configuration"
    Write-Host "5. Create SSH configuration"
    Write-Host ""
    Write-Host "Usage: .\Fix-CloudToLocalLLMEnvironment.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -SkipDocker    Skip Docker Desktop installation"
    Write-Host "  -SkipOllama    Skip Ollama model installation"
    Write-Host "  -SkipWSL       Skip WSL feature enablement"
    Write-Host "  -SkipTests     Skip test environment fixes"
    Write-Host "  -SkipSSH       Skip SSH configuration"
    Write-Host "  -Force         Force reinstallation of existing components"
    Write-Host "  -Help          Show this help message"
    Write-Host ""
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    param([string]$Reason)
    
    Write-LogWarning "Administrator privileges required for: $Reason"
    Write-Host "Requesting UAC elevation..." -ForegroundColor Yellow
    
    $scriptPath = $MyInvocation.ScriptName
    $arguments = $MyInvocation.BoundParameters.Keys | ForEach-Object { "-$_" }
    $argumentString = $arguments -join " "
    
    try {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`" $argumentString" -Verb RunAs -Wait
        return $true
    } catch {
        Write-LogError "Failed to elevate privileges: $($_.Exception.Message)"
        return $false
    }
}

function Install-DockerDesktop {
    Write-LogInfo "Installing Docker Desktop..."
    
    # Check if Docker is already installed
    $dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerInstalled -and -not $Force) {
        Write-LogSuccess "Docker is already installed at: $($dockerInstalled.Source)"
        return $true
    }
    
    # Try winget first
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetAvailable) {
        Write-LogInfo "Installing Docker Desktop via winget..."
        try {
            $result = winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Docker Desktop installed successfully via winget"
                return $true
            }
        } catch {
            Write-LogWarning "Winget installation failed: $($_.Exception.Message)"
        }
    }
    
    # Fallback to Chocolatey
    $chocoAvailable = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoAvailable) {
        Write-LogInfo "Installing Docker Desktop via Chocolatey..."
        try {
            choco install docker-desktop -y
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Docker Desktop installed successfully via Chocolatey"
                return $true
            }
        } catch {
            Write-LogWarning "Chocolatey installation failed: $($_.Exception.Message)"
        }
    }
    
    # Manual download as last resort
    Write-LogWarning "Automated installation failed. Please install Docker Desktop manually from:"
    Write-Host "https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
    return $false
}

function Install-OllamaModels {
    Write-LogInfo "Installing Ollama models..."
    
    # Check if Ollama is available
    $ollamaAvailable = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollamaAvailable) {
        Write-LogError "Ollama is not installed or not in PATH"
        return $false
    }
    
    # Check current models
    $currentModels = ollama list 2>$null
    if ($currentModels -match "llama3.2:1b" -and -not $Force) {
        Write-LogSuccess "llama3.2:1b model is already installed"
        return $true
    }
    
    Write-LogInfo "Downloading llama3.2:1b model (this may take several minutes)..."
    try {
        ollama pull llama3.2:1b
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "llama3.2:1b model installed successfully"
            return $true
        } else {
            Write-LogError "Failed to install llama3.2:1b model"
            return $false
        }
    } catch {
        Write-LogError "Error installing Ollama model: $($_.Exception.Message)"
        return $false
    }
}

function Enable-WSLFeatures {
    Write-LogInfo "Enabling Windows WSL features..."

    if (-not (Test-AdminPrivileges)) {
        if (Request-AdminElevation "Enable WSL features") {
            return $true
        } else {
            Write-LogError "Cannot enable WSL features without administrator privileges"
            return $false
        }
    }

    try {
        Write-LogInfo "Enabling Microsoft-Windows-Subsystem-Linux..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart

        Write-LogInfo "Enabling VirtualMachinePlatform..."
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

        Write-LogSuccess "WSL features enabled successfully"
        Write-LogWarning "A system restart may be required for changes to take effect"
        return $true
    } catch {
        Write-LogError "Failed to enable WSL features: $($_.Exception.Message)"
        return $false
    }
}

function Create-SSHConfiguration {
    Write-LogInfo "Creating SSH configuration..."

    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $sshConfig = Join-Path $sshDir "config"

    try {
        # Create .ssh directory if it doesn't exist
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
            Write-LogInfo "Created SSH directory: $sshDir"
        }

        # Create basic SSH config if it doesn't exist
        if (-not (Test-Path $sshConfig) -or $Force) {
            $configContent = @"
# CloudToLocalLLM SSH Configuration
# Basic configuration for development and deployment

# Default settings
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking ask
    UserKnownHostsFile ~/.ssh/known_hosts

# Add your custom host configurations below
# Example:
# Host myserver
#     HostName example.com
#     User myuser
#     Port 22
#     IdentityFile ~/.ssh/id_ed25519
"@
            Set-Content -Path $sshConfig -Value $configContent -Encoding UTF8
            Write-LogSuccess "Created SSH config file: $sshConfig"
        } else {
            Write-LogSuccess "SSH config file already exists: $sshConfig"
        }

        return $true
    } catch {
        Write-LogError "Failed to create SSH configuration: $($_.Exception.Message)"
        return $false
    }
}

function Fix-TestEnvironment {
    Write-LogInfo "Fixing test environment configuration..."

    $projectRoot = Get-ProjectRoot
    $testDir = Join-Path $projectRoot "test"
    $mockDir = Join-Path $testDir "mocks"

    try {
        # Create mocks directory if it doesn't exist
        if (-not (Test-Path $mockDir)) {
            New-Item -ItemType Directory -Path $mockDir -Force | Out-Null
            Write-LogInfo "Created test mocks directory: $mockDir"
        }

        # Create mock implementations for problematic plugins
        $mockFiles = @{
            "mock_window_manager.dart" = @"
// Mock implementation for window_manager plugin
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockWindowManager extends Mock {
  Future<void> ensureInitialized() async {
    // Mock implementation - do nothing
  }

  Future<void> show() async {
    // Mock implementation - do nothing
  }

  Future<void> hide() async {
    // Mock implementation - do nothing
  }
}
"@
            "mock_tray_manager.dart" = @"
// Mock implementation for tray_manager plugin
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockTrayManager extends Mock {
  Future<void> setIcon(String iconPath) async {
    // Mock implementation - do nothing
  }

  Future<void> setContextMenu(dynamic menu) async {
    // Mock implementation - do nothing
  }
}
"@
            "mock_package_info.dart" = @"
// Mock implementation for package_info_plus plugin
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockPackageInfo extends Mock {
  String get appName => 'CloudToLocalLLM';
  String get packageName => 'com.cloudtolocalllm.app';
  String get version => '3.6.1';
  String get buildNumber => '202506192205';
}
"@
        }

        foreach ($fileName in $mockFiles.Keys) {
            $filePath = Join-Path $mockDir $fileName
            if (-not (Test-Path $filePath) -or $Force) {
                Set-Content -Path $filePath -Value $mockFiles[$fileName] -Encoding UTF8
                Write-LogInfo "Created mock file: $fileName"
            }
        }

        Write-LogSuccess "Test environment configuration fixed"
        return $true
    } catch {
        Write-LogError "Failed to fix test environment: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

Write-Host "CloudToLocalLLM Environment Fix Script" -ForegroundColor Blue
Write-Host "=====================================" -ForegroundColor Blue
Write-Host ""

$success = $true

# Step 1: Install Docker Desktop
if (-not $SkipDocker) {
    if (-not (Install-DockerDesktop)) {
        $success = $false
    }
}

# Step 2: Install Ollama Models
if (-not $SkipOllama) {
    if (-not (Install-OllamaModels)) {
        $success = $false
    }
}

# Step 3: Enable WSL Features
if (-not $SkipWSL) {
    if (-not (Enable-WSLFeatures)) {
        $success = $false
    }
}

# Step 4: Create SSH Configuration
if (-not $SkipSSH) {
    if (-not (Create-SSHConfiguration)) {
        $success = $false
    }
}

# Step 5: Fix Test Environment
if (-not $SkipTests) {
    if (-not (Fix-TestEnvironment)) {
        $success = $false
    }
}

Write-Host ""
if ($success) {
    Write-LogSuccess "Environment fix script completed successfully!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Green
    Write-Host "1. Restart your system if WSL features were enabled" -ForegroundColor Yellow
    Write-Host "2. Start Docker Desktop and complete setup" -ForegroundColor Yellow
    Write-Host "3. Run 'flutter test' to verify test fixes" -ForegroundColor Yellow
    Write-Host "4. Test Ollama connection with 'ollama list'" -ForegroundColor Yellow
} else {
    Write-LogWarning "Environment fix script completed with some issues. Check the log above for details."
}
