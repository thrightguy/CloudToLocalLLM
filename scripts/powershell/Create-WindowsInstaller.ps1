# CloudToLocalLLM Windows Installer Creator (PowerShell)
# Creates Windows setup executable using Inno Setup with elevated privileges

[CmdletBinding()]
param(
    [string]$Version,
    [switch]$InstallInnoSetup,
    [switch]$Force,
    [switch]$Help,
    [string]$ElevationMarker
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
$InstallerScriptPath = Join-Path $ProjectRoot "installers\windows\Basic.iss"
$OutputDir = Join-Path $ProjectRoot "dist\windows"

# Show help information
function Show-Help {
    Write-Host "CloudToLocalLLM Windows Installer Creator" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\Create-WindowsInstaller.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Version <version>       Specify version (auto-detected if not provided)"
    Write-Host "  -InstallInnoSetup        Install Inno Setup if not found"
    Write-Host "  -Force                   Force reinstall Inno Setup"
    Write-Host "  -Help                    Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\Create-WindowsInstaller.ps1"
    Write-Host "  .\Create-WindowsInstaller.ps1 -InstallInnoSetup"
    Write-Host "  .\Create-WindowsInstaller.ps1 -Version 3.7.2 -Force"
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Restart script with elevated privileges
function Start-ElevatedScript {
    param([string[]]$Arguments)

    Write-LogInfo "Restarting script with administrator privileges..."

    $scriptPath = $MyInvocation.MyCommand.Path
    $argumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"") + $Arguments

    try {
        # Create a temporary marker file to track elevation
        $elevationMarker = Join-Path $env:TEMP "CloudToLocalLLM-Elevation-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        $argumentList += @("-ElevationMarker", "`"$elevationMarker`"")

        Write-LogInfo "Starting elevated process..."
        $process = Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList -Verb RunAs -PassThru

        if ($process) {
            Write-LogInfo "Waiting for elevated process to complete..."
            $process.WaitForExit()
            $exitCode = $process.ExitCode

            # Check if elevation marker exists (indicates successful elevation)
            if (Test-Path $elevationMarker) {
                Remove-Item $elevationMarker -Force -ErrorAction SilentlyContinue
                Write-LogSuccess "Elevated process completed successfully"
            }
            else {
                Write-LogWarning "Elevation marker not found - process may have failed"
            }

            exit $exitCode
        }
        else {
            Write-LogError "Failed to start elevated process"
            exit 1
        }
    }
    catch {
        Write-LogError "Failed to restart with elevated privileges: $($_.Exception.Message)"
        Write-LogError "Please run PowerShell as Administrator and try again"
        exit 1
    }
}

# Install Inno Setup using Chocolatey with enhanced error handling
function Install-InnoSetup {
    Write-LogInfo "Installing Inno Setup using Chocolatey..."

    if (-not (Test-Administrator)) {
        Write-LogError "Administrator privileges required to install Inno Setup"
        return $false
    }

    try {
        # Check if Chocolatey is installed
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoPath) {
            Write-LogWarning "Chocolatey is not installed. Installing Chocolatey first..."
            if (-not (Install-Chocolatey)) {
                Write-LogError "Failed to install Chocolatey"
                return $false
            }
        }

        # Clean up any previous failed installations
        $lockFiles = @(
            "C:\ProgramData\chocolatey\lib\fbbc2631123b2794515853c3079979fe2254cc76",
            "C:\ProgramData\chocolatey\lib\.chocolateyPending"
        )

        foreach ($lockFile in $lockFiles) {
            if (Test-Path $lockFile) {
                Write-LogInfo "Removing lock file: $lockFile"
                Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
            }
        }

        # Clean up any bad lib directories
        $badLibDir = "C:\ProgramData\chocolatey\lib-bad"
        if (Test-Path $badLibDir) {
            Write-LogInfo "Removing bad lib directory..."
            Remove-Item $badLibDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Remove any existing InnoSetup package to ensure clean install
        Write-LogInfo "Cleaning up any existing InnoSetup installation..."
        Start-Process -FilePath "choco" -ArgumentList @("uninstall", "innosetup", "-y") -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue | Out-Null

        # Wait a moment for cleanup
        Start-Sleep -Seconds 2

        # Install Inno Setup with enhanced parameters
        Write-LogInfo "Installing Inno Setup via Chocolatey..."
        $chocoArgs = @(
            "install",
            "innosetup",
            "-y",
            "--force",
            "--allow-downgrade",
            "--ignore-checksums",
            "--no-progress",
            "--timeout", "300"
        )

        Write-LogInfo "Executing: choco $($chocoArgs -join ' ')"

        # Capture both stdout and stderr
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "choco"
        $processInfo.Arguments = $chocoArgs -join ' '
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        $output = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-LogSuccess "Inno Setup installed successfully via Chocolatey"
            if ($output -and $output.Trim()) {
                Write-LogInfo "Installation output: $($output.Trim())"
            }

            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            # Wait for installation to complete
            Start-Sleep -Seconds 3

            # Verify installation
            $compilerPath = Find-InnoSetupCompiler
            if ($compilerPath) {
                Write-LogSuccess "Inno Setup compiler verified at: $compilerPath"
                return $true
            }
            else {
                Write-LogWarning "Inno Setup installed but compiler not found in expected locations"
                Write-LogInfo "Attempting direct installation method..."
                return Install-InnoSetupDirect
            }
        }
        else {
            Write-LogWarning "Chocolatey installation failed (Exit code: $exitCode)"
            if ($stderr) {
                Write-LogInfo "Error details: $stderr"
            }

            # Try alternative installation method
            Write-LogInfo "Attempting direct installation method..."
            return Install-InnoSetupDirect
        }
    }
    catch {
        Write-LogError "Error installing Inno Setup: $($_.Exception.Message)"
        Write-LogInfo "Attempting alternative installation method..."
        return Install-InnoSetupDirect
    }
}

# Install Chocolatey if not present
function Install-Chocolatey {
    Write-LogInfo "Installing Chocolatey..."

    try {
        # Download and install Chocolatey
        $installScript = Invoke-WebRequest -Uri "https://chocolatey.org/install.ps1" -UseBasicParsing
        Invoke-Expression $installScript.Content

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # Verify installation
        $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoPath) {
            Write-LogSuccess "Chocolatey installed successfully"
            return $true
        }
        else {
            Write-LogError "Chocolatey installation failed"
            return $false
        }
    }
    catch {
        Write-LogError "Error installing Chocolatey: $($_.Exception.Message)"
        return $false
    }
}

# Direct download and install Inno Setup
function Install-InnoSetupDirect {
    Write-LogInfo "Installing Inno Setup via direct download..."

    try {
        $downloadUrl = "https://jrsoftware.org/download.php/is.exe"
        $tempPath = Join-Path $env:TEMP "innosetup-installer.exe"

        Write-LogInfo "Downloading Inno Setup from: $downloadUrl"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing

        if (Test-Path $tempPath) {
            Write-LogInfo "Running Inno Setup installer silently..."
            $installArgs = @("/SILENT", "/NORESTART", "/SUPPRESSMSGBOXES")
            $result = Start-Process -FilePath $tempPath -ArgumentList $installArgs -Wait -PassThru

            # Clean up installer
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue

            if ($result.ExitCode -eq 0) {
                Write-LogSuccess "Inno Setup installed successfully via direct download"

                # Refresh environment variables
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                # Verify installation
                Start-Sleep -Seconds 2
                $compilerPath = Find-InnoSetupCompiler
                if ($compilerPath) {
                    Write-LogSuccess "Inno Setup compiler verified at: $compilerPath"
                    return $true
                }
                else {
                    Write-LogError "Inno Setup installed but compiler not found"
                    return $false
                }
            }
            else {
                Write-LogError "Inno Setup installation failed (Exit code: $($result.ExitCode))"
                return $false
            }
        }
        else {
            Write-LogError "Failed to download Inno Setup installer"
            return $false
        }
    }
    catch {
        Write-LogError "Error with direct Inno Setup installation: $($_.Exception.Message)"
        return $false
    }
}

# Find Inno Setup compiler with comprehensive search
function Find-InnoSetupCompiler {
    Write-LogInfo "Searching for Inno Setup compiler..."

    # Common installation paths (ordered by likelihood)
    $possiblePaths = @(
        "C:\Program Files (x86)\Inno Setup 6\iscc.exe",
        "C:\Program Files\Inno Setup 6\iscc.exe",
        "C:\Program Files (x86)\Inno Setup 5\iscc.exe",
        "C:\Program Files\Inno Setup 5\iscc.exe",
        "C:\Program Files (x86)\Inno Setup\iscc.exe",
        "C:\Program Files\Inno Setup\iscc.exe"
    )

    # Check standard installation paths
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-LogSuccess "Found Inno Setup compiler at: $path"
            return $path
        }
    }

    # Try to find in PATH environment variable
    $isccPath = Get-Command iscc -ErrorAction SilentlyContinue
    if ($isccPath) {
        Write-LogSuccess "Found Inno Setup compiler in PATH: $($isccPath.Source)"
        return $isccPath.Source
    }

    # Search in registry for Inno Setup installation
    try {
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup*"
        )

        foreach ($regPath in $registryPaths) {
            $innoSetupKeys = Get-ChildItem $regPath -ErrorAction SilentlyContinue
            foreach ($key in $innoSetupKeys) {
                $installLocation = (Get-ItemProperty $key.PSPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                if ($installLocation) {
                    $compilerPath = Join-Path $installLocation "iscc.exe"
                    if (Test-Path $compilerPath) {
                        Write-LogSuccess "Found Inno Setup compiler via registry: $compilerPath"
                        return $compilerPath
                    }
                }
            }
        }
    }
    catch {
        Write-LogInfo "Registry search failed: $($_.Exception.Message)"
    }

    Write-LogWarning "Inno Setup compiler not found in any standard location"
    return $null
}

# Get version from version manager
function Get-ProjectVersion {
    if ($Version) {
        return $Version
    }
    
    $versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"
    if (Test-Path $versionManagerPath) {
        $currentVersion = & $versionManagerPath get-semantic
        Write-LogInfo "Auto-detected version: $currentVersion"
        return $currentVersion
    }
    
    Write-LogError "Could not determine project version"
    return $null
}

# Update Inno Setup script with current version
function Update-InnoSetupScript {
    param([string]$ProjectVersion)
    
    Write-LogInfo "Updating Inno Setup script with version $ProjectVersion..."
    
    if (-not (Test-Path $InstallerScriptPath)) {
        Write-LogError "Inno Setup script not found: $InstallerScriptPath"
        return $false
    }
    
    try {
        $content = Get-Content $InstallerScriptPath -Raw
        
        # Update version
        $content = $content -replace '#define MyAppVersion ".*"', "#define MyAppVersion `"$ProjectVersion`""
        
        # Ensure correct executable name
        $content = $content -replace '#define MyAppExeName ".*"', '#define MyAppExeName "cloudtolocalllm.exe"'
        
        Set-Content -Path $InstallerScriptPath -Value $content -Encoding UTF8
        Write-LogSuccess "Updated Inno Setup script"
        return $true
    }
    catch {
        Write-LogError "Failed to update Inno Setup script: $($_.Exception.Message)"
        return $false
    }
}

# Compile installer using Inno Setup
function Build-WindowsInstaller {
    param([string]$CompilerPath, [string]$ProjectVersion)
    
    Write-LogInfo "Compiling Windows installer..."
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    # Set output directory for the installer
    $outputPath = Join-Path $OutputDir "CloudToLocalLLM-Windows-$ProjectVersion-Setup.exe"
    
    try {
        # Compile the installer
        $arguments = @(
            "`"$InstallerScriptPath`"",
            "/O`"$OutputDir`""
        )
        
        Write-LogInfo "Running: `"$CompilerPath`" $($arguments -join ' ')"
        $result = Start-Process -FilePath $CompilerPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($result.ExitCode -eq 0) {
            # Check if installer was created
            if (Test-Path $outputPath) {
                Write-LogSuccess "Windows installer created successfully: $outputPath"
                
                # Generate checksum
                $checksum = Get-FileHash -Path $outputPath -Algorithm SHA256
                $checksumFile = "$outputPath.sha256"
                "$($checksum.Hash.ToLower())  $(Split-Path $outputPath -Leaf)" | Set-Content -Path $checksumFile -Encoding UTF8
                
                Write-LogInfo "Checksum file created: $checksumFile"
                return $true
            }
            else {
                Write-LogError "Installer compilation succeeded but output file not found"
                return $false
            }
        }
        else {
            Write-LogError "Installer compilation failed (Exit code: $($result.ExitCode))"
            return $false
        }
    }
    catch {
        Write-LogError "Error compiling installer: $($_.Exception.Message)"
        return $false
    }
}

# Main execution function
function Invoke-Main {
    Write-LogInfo "CloudToLocalLLM Windows Installer Creator"
    Write-LogInfo "========================================"

    # Create elevation marker if provided (indicates we're running elevated)
    if ($ElevationMarker) {
        try {
            New-Item -Path $ElevationMarker -ItemType File -Force | Out-Null
            Write-LogInfo "Elevation marker created: $ElevationMarker"
        }
        catch {
            Write-LogWarning "Failed to create elevation marker: $($_.Exception.Message)"
        }
    }

    # Show help if requested
    if ($Help) {
        Show-Help
        return
    }

    # Get project version
    $projectVersion = Get-ProjectVersion
    if (-not $projectVersion) {
        exit 1
    }

    Write-LogInfo "Building Windows installer for version: $projectVersion"
    
    # Check for Inno Setup compiler
    $compilerPath = Find-InnoSetupCompiler

    if (-not $compilerPath) {
        Write-LogWarning "Inno Setup compiler not found on system"
        Write-LogInfo "Inno Setup is required to create Windows setup executable"

        # Automatically attempt installation
        Write-LogInfo "Attempting automatic Inno Setup installation..."

        # Check if we need administrator privileges
        if (-not (Test-Administrator)) {
            Write-LogWarning "Administrator privileges required for Inno Setup installation"
            Write-LogInfo "Requesting elevated privileges..."

            # Prepare arguments for elevated execution
            $arguments = @()
            if ($Version) { $arguments += @("-Version", $Version) }
            $arguments += "-InstallInnoSetup"
            if ($Force) { $arguments += "-Force" }

            # Restart with elevation
            Start-ElevatedScript -Arguments $arguments
            return
        }

        # We have admin privileges, proceed with installation
        Write-LogInfo "Running with administrator privileges - proceeding with Inno Setup installation"

        if (-not (Install-InnoSetup)) {
            Write-LogError "Failed to install Inno Setup automatically"
            Write-LogError "Manual installation required from: https://jrsoftware.org/isinfo.php"
            Write-LogInfo "After manual installation, run this script again"
            exit 1
        }

        # Verify installation was successful
        Write-LogInfo "Verifying Inno Setup installation..."
        $compilerPath = Find-InnoSetupCompiler

        if (-not $compilerPath) {
            Write-LogError "Inno Setup installation completed but compiler not found"
            Write-LogError "Please verify installation and ensure iscc.exe is accessible"
            Write-LogInfo "Expected locations:"
            Write-LogInfo "  - C:\Program Files (x86)\Inno Setup 6\iscc.exe"
            Write-LogInfo "  - C:\Program Files\Inno Setup 6\iscc.exe"
            exit 1
        }

        Write-LogSuccess "Inno Setup installation completed successfully!"
        Write-LogSuccess "Compiler found at: $compilerPath"
    }
    else {
        Write-LogSuccess "Inno Setup compiler found at: $compilerPath"
    }
    
    # Update Inno Setup script
    if (-not (Update-InnoSetupScript -ProjectVersion $projectVersion)) {
        exit 1
    }
    
    # Build installer
    if (-not (Build-WindowsInstaller -CompilerPath $compilerPath -ProjectVersion $projectVersion)) {
        exit 1
    }
    
    Write-LogSuccess "Windows installer creation completed successfully!"
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
