# CloudToLocalLLM Build Script Launcher
# Helps users choose between bash and PowerShell scripts

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('version', 'build', 'aur', 'deb', 'deploy', 'test', 'help')]
    [string]$Action = 'help',

    [switch]$ForceBash,
    [switch]$ForcePowerShell,
    [switch]$ShowEnvironment,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck
)

# Colors for output
$Colors = @{
    Blue   = 'Blue'
    Green  = 'Green'
    Yellow = 'Yellow'
    Red    = 'Red'
    Cyan   = 'Cyan'
}

function Write-ColorText {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Colors[$Color]
}

function Test-WSLAvailable {
    try {
        $null = wsl --list --quiet 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Test-BashAvailable {
    return $null -ne (Get-Command bash -ErrorAction SilentlyContinue)
}

function Show-Environment {
    Write-ColorText "CloudToLocalLLM Build Environment" "Cyan"
    Write-ColorText "=================================" "Cyan"
    Write-Host ""
    
    # PowerShell version
    Write-Host "PowerShell Version: " -NoNewline
    Write-ColorText $PSVersionTable.PSVersion "Green"
    
    # Windows version
    $osVersion = [System.Environment]::OSVersion.VersionString
    Write-Host "Windows Version: " -NoNewline
    Write-ColorText $osVersion "Green"
    
    # WSL availability
    Write-Host "WSL Available: " -NoNewline
    if (Test-WSLAvailable) {
        Write-ColorText "Yes" "Green"
        
        # WSL distributions
        try {
            $distributions = wsl --list --verbose 2>$null
            Write-Host "WSL Distributions:"
            foreach ($line in $distributions) {
                if ($line -match '^\s*\*?\s*([^\s]+)\s+(\w+)\s+(\d+)') {
                    $name = $matches[1]
                    $state = $matches[2]
                    $version = $matches[3]
                    $status = if ($state -eq "Running") { "Green" } else { "Yellow" }
                    Write-Host "  - $name (WSL $version): " -NoNewline
                    Write-ColorText $state $status
                }
            }
        }
        catch {
            Write-ColorText "  Could not list distributions" "Yellow"
        }
    }
    else {
        Write-ColorText "No" "Red"
    }
    
    # Bash availability
    Write-Host "Bash Available: " -NoNewline
    if (Test-BashAvailable) {
        Write-ColorText "Yes" "Green"
    }
    else {
        Write-ColorText "No" "Red"
    }
    
    # Docker availability
    Write-Host "Docker Available: " -NoNewline
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        try {
            docker info | Out-Null
            Write-ColorText "Yes (Running)" "Green"
        }
        catch {
            Write-ColorText "Yes (Not Running)" "Yellow"
        }
    }
    else {
        Write-ColorText "No" "Red"
    }
    
    # Flutter availability
    Write-Host "Flutter Available: " -NoNewline
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Write-ColorText "Yes" "Green"
    }
    else {
        Write-ColorText "No" "Red"
    }
    
    # Git availability
    Write-Host "Git Available: " -NoNewline
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-ColorText "Yes" "Green"
    }
    else {
        Write-ColorText "No" "Red"
    }
    
    Write-Host ""
}

function Show-Help {
    Write-ColorText "CloudToLocalLLM Build Script Launcher" "Cyan"
    Write-ColorText "=====================================" "Cyan"
    Write-Host ""
    Write-Host "This launcher helps you choose between bash and PowerShell build scripts."
    Write-Host ""
    Write-ColorText "Usage:" "Yellow"
    Write-Host "  .\launcher.ps1 <action> [options]"
    Write-Host ""
    Write-ColorText "Actions:" "Yellow"
    Write-Host "  version    - Version management operations"
    Write-Host "  build      - Build unified package"
    Write-Host "  aur        - Create AUR package (requires WSL Arch Linux)"
    Write-Host "  deb        - Create Debian package (requires WSL Ubuntu/Debian or Docker)"
    Write-Host "  deploy     - Deploy to VPS (bash only - use WSL)"
    Write-Host "  test       - Test environment and dependencies"
    Write-Host "  help       - Show this help message"
    Write-Host ""
    Write-ColorText "Options:" "Yellow"
    Write-Host "  -ForceBash        Force use of bash scripts"
    Write-Host "  -ForcePowerShell  Force use of PowerShell scripts"
    Write-Host "  -ShowEnvironment  Show environment information"
    Write-Host ""
    Write-ColorText "Examples:" "Yellow"
    Write-Host "  .\launcher.ps1 version"
    Write-Host "  .\launcher.ps1 build -ForcePowerShell"
    Write-Host "  .\launcher.ps1 -ShowEnvironment"
    Write-Host ""
    Write-ColorText "Script Selection Logic:" "Yellow"
    Write-Host "  1. If -ForceBash: Use bash scripts (requires WSL or Git Bash)"
    Write-Host "  2. If -ForcePowerShell: Use PowerShell scripts"
    Write-Host "  3. Auto-detect: Prefer PowerShell on Windows, bash on Linux"
    Write-Host ""
}

function Get-ScriptChoice {
    param([string]$ActionType)
    
    if ($ForceBash) {
        if (Test-WSLAvailable -or Test-BashAvailable) {
            return "bash"
        }
        else {
            Write-ColorText "Error: Bash forced but not available" "Red"
            Write-Host "Install WSL or Git Bash to use bash scripts"
            exit 1
        }
    }
    
    if ($ForcePowerShell) {
        return "powershell"
    }
    
    # Auto-detection logic
    switch ($ActionType) {
        "deploy" {
            # VPS deployment requires bash scripts via WSL
            if (Test-WSLAvailable) {
                Write-ColorText "VPS deployment requires bash scripts via WSL" "Yellow"
                return "bash"
            }
            else {
                Write-ColorText "Error: VPS deployment requires WSL for bash scripts" "Red"
                Write-Host "Install WSL to use VPS deployment functionality"
                exit 1
            }
        }
        "aur" {
            # AUR requires WSL Arch Linux, prefer bash if available
            if (Test-WSLAvailable) {
                return "powershell"  # PowerShell script has better WSL integration
            }
            else {
                Write-ColorText "Warning: AUR packaging requires WSL with Arch Linux" "Yellow"
                return "powershell"
            }
        }
        "deb" {
            # Debian packaging can use Docker or WSL
            return "powershell"  # PowerShell script supports both Docker and WSL
        }
        default {
            # For other actions, prefer PowerShell on Windows
            return "powershell"
        }
    }
}

function Invoke-Script {
    param([string]$Action, [string]$ScriptType)
    
    $scriptDir = Split-Path -Parent $PSScriptRoot
    
    switch ($ScriptType) {
        "bash" {
            $scriptMap = @{
                "version" = "version_manager.sh"
                "build"   = "build_unified_package.sh"
                "aur"     = "create_unified_aur_package.sh"
                "deb"     = "packaging/build_deb.sh"
                "deploy"  = "deploy/update_and_deploy.sh"
            }
            
            $scriptPath = Join-Path $scriptDir $scriptMap[$Action]
            
            if (Test-Path $scriptPath) {
                Write-ColorText "Executing bash script: $scriptPath" "Blue"
                
                if (Test-WSLAvailable) {
                    # Use WSL to run bash script
                    wsl bash $scriptPath
                }
                elseif (Test-BashAvailable) {
                    # Use Git Bash or other bash
                    bash $scriptPath
                }
                else {
                    Write-ColorText "Error: No bash environment available" "Red"
                    exit 1
                }
            }
            else {
                Write-ColorText "Error: Bash script not found: $scriptPath" "Red"
                exit 1
            }
        }
        "powershell" {
            $scriptMap = @{
                "version" = "version_manager.ps1"
                "build"   = "build_unified_package.ps1"
                "aur"     = "create_unified_aur_package.ps1"
                "deb"     = "build_deb.ps1"
                "test"    = "Test-Environment.ps1"
            }
            
            # Check if action is supported in PowerShell
            if ($Action -eq "deploy") {
                Write-ColorText "Error: VPS deployment is not supported via PowerShell scripts" "Red"
                Write-Host "Use bash scripts via WSL for VPS deployment:"
                Write-Host "  wsl -d archlinux"
                Write-Host "  cd /opt/cloudtolocalllm"
                Write-Host "  bash scripts/deploy/update_and_deploy.sh --force"
                exit 1
            }

            $scriptPath = Join-Path $PSScriptRoot $scriptMap[$Action]

            if (Test-Path $scriptPath) {
                Write-ColorText "Executing PowerShell script: $scriptPath" "Blue"

                # Pass through common parameters
                $scriptArgs = @()
                if ($AutoInstall) { $scriptArgs += '-AutoInstall' }
                if ($SkipDependencyCheck) { $scriptArgs += '-SkipDependencyCheck' }

                & $scriptPath @scriptArgs
            }
            else {
                Write-ColorText "Error: PowerShell script not found: $scriptPath" "Red"
                exit 1
            }
        }
    }
}

# Main execution
if ($ShowEnvironment) {
    Show-Environment
    exit 0
}

if ($Action -eq "help") {
    Show-Help
    exit 0
}

$scriptChoice = Get-ScriptChoice -ActionType $Action
Write-ColorText "Selected script type: $scriptChoice" "Green"
Write-Host ""

Invoke-Script -Action $Action -ScriptType $scriptChoice
