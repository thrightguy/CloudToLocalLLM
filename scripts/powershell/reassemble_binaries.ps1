# CloudToLocalLLM Binary Reassembly Script (PowerShell)
# Reassembles split binary files that were compressed to stay under GitHub's 100MB limit

[CmdletBinding()]
param(
    [string]$DistPath,
    [switch]$UseWSL,
    [string]$WSLDistro,
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
    Write-Host "CloudToLocalLLM Binary Reassembly Script (PowerShell)" -ForegroundColor Blue
    Write-Host "====================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Reassembles split binary files that were compressed to stay under GitHub's 100MB limit" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\reassemble_binaries.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -DistPath             Custom dist directory path"
    Write-Host "  -UseWSL               Use WSL for Linux operations"
    Write-Host "  -WSLDistro            Specific WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\reassemble_binaries.ps1"
    Write-Host "  .\reassemble_binaries.ps1 -UseWSL -WSLDistro Ubuntu"
    Write-Host "  .\reassemble_binaries.ps1 -DistPath 'C:\MyProject\dist'"
    exit 0
}

# Configuration
$ProjectRoot = Get-ProjectRoot
if (-not $DistPath) {
    $DistPath = Join-Path $ProjectRoot "dist"
}

Write-Host "CloudToLocalLLM Binary Reassembly Script (PowerShell)" -ForegroundColor Blue
Write-Host "====================================================" -ForegroundColor Blue
Write-Host ""

# Check prerequisites
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites..."

    # Check if dist directory exists
    if (-not (Test-Path $DistPath)) {
        Write-LogError "Dist directory not found: $DistPath"
        exit 1
    }

    # If using WSL, verify it's available
    if ($UseWSL) {
        if (-not $WSLDistro) {
            $WSLDistro = Find-WSLDistribution -Purpose 'Any'
            if (-not $WSLDistro) {
                Write-LogError "No WSL distribution found. Install WSL: wsl --install"
                exit 1
            }
        }
    }

    Write-LogSuccess "Prerequisites check passed"
}

# Function to reassemble a split file
function Invoke-FileReassembly {
    [CmdletBinding()]
    param(
        [string]$BaseName,
        [string]$OutputFile,
        [string]$PartsPattern
    )

    $outputPath = Join-Path $DistPath $OutputFile

    if (Test-Path $outputPath) {
        Write-LogWarning "File $OutputFile already exists, skipping reassembly"
        return $true
    }

    # Find parts files
    $partsFiles = Get-ChildItem -Path $DistPath -Filter $PartsPattern | Sort-Object Name

    if ($partsFiles.Count -eq 0) {
        Write-LogError "No parts found for pattern: $PartsPattern"
        return $false
    }

    Write-LogInfo "Reassembling $BaseName..."

    try {
        # Reassemble using PowerShell
        $outputStream = [System.IO.File]::Create($outputPath)
        
        foreach ($partFile in $partsFiles) {
            Write-LogInfo "Processing part: $($partFile.Name)"
            $partBytes = [System.IO.File]::ReadAllBytes($partFile.FullName)
            $outputStream.Write($partBytes, 0, $partBytes.Length)
        }
        
        $outputStream.Close()
        $outputStream.Dispose()

        if (Test-Path $outputPath) {
            $fileSize = [math]::Round((Get-Item $outputPath).Length / 1MB, 2)
            Write-LogSuccess "Successfully reassembled: $OutputFile"
            Write-LogInfo "File size: $fileSize MB"
            return $true
        }
        else {
            Write-LogError "Failed to reassemble $BaseName"
            return $false
        }
    }
    catch {
        Write-LogError "Error reassembling $BaseName`: $($_.Exception.Message)"
        if ($outputStream) {
            $outputStream.Close()
            $outputStream.Dispose()
        }
        return $false
    }
}

# Function to make file executable (WSL only)
function Set-ExecutablePermission {
    [CmdletBinding()]
    param([string]$FilePath)

    if ($UseWSL) {
        $wslPath = Convert-WindowsPathToWSL -WindowsPath (Join-Path $DistPath $FilePath)
        $chmodCommand = "chmod +x `"$wslPath`""
        
        try {
            Invoke-WSLCommand -DistroName $WSLDistro -Command $chmodCommand
            Write-LogInfo "Made $FilePath executable"
        }
        catch {
            Write-LogWarning "Could not set executable permission for $FilePath"
        }
    }
    else {
        Write-LogInfo "Skipping executable permission setting on Windows for $FilePath"
    }
}

# Function to decompress gzip file
function Expand-GzipFile {
    [CmdletBinding()]
    param(
        [string]$GzipFile,
        [string]$OutputFile
    )

    $gzipPath = Join-Path $DistPath $GzipFile
    $outputPath = Join-Path $DistPath $OutputFile

    if (-not (Test-Path $gzipPath)) {
        Write-LogError "Gzip file not found: $GzipFile"
        return $false
    }

    Write-LogInfo "Decompressing $GzipFile..."

    try {
        if ($UseWSL) {
            # Use WSL gunzip
            $wslGzipPath = Convert-WindowsPathToWSL -WindowsPath $gzipPath
            $gunzipCommand = "gunzip `"$wslGzipPath`""
            Invoke-WSLCommand -DistroName $WSLDistro -Command $gunzipCommand
        }
        else {
            # Use .NET compression
            $gzipStream = New-Object System.IO.FileStream($gzipPath, [System.IO.FileMode]::Open)
            $decompressStream = New-Object System.IO.Compression.GzipStream($gzipStream, [System.IO.Compression.CompressionMode]::Decompress)
            $outputStream = New-Object System.IO.FileStream($outputPath, [System.IO.FileMode]::Create)
            
            $decompressStream.CopyTo($outputStream)
            
            $outputStream.Close()
            $decompressStream.Close()
            $gzipStream.Close()
            
            # Remove the .gz file
            Remove-Item $gzipPath -Force
        }

        if (Test-Path $outputPath) {
            Write-LogSuccess "Successfully decompressed: $OutputFile"
            return $true
        }
        else {
            Write-LogError "Failed to decompress $GzipFile"
            return $false
        }
    }
    catch {
        Write-LogError "Error decompressing $GzipFile`: $($_.Exception.Message)"
        return $false
    }
}

# Function to create symbolic link (WSL only)
function New-SymbolicLink {
    [CmdletBinding()]
    param(
        [string]$Target,
        [string]$LinkName,
        [string]$Directory = ""
    )

    if ($UseWSL) {
        $workingDir = if ($Directory) { Join-Path $DistPath $Directory } else { $DistPath }
        $wslWorkingDir = Convert-WindowsPathToWSL -WindowsPath $workingDir
        
        $linkCommand = "cd `"$wslWorkingDir`" && ln -sf `"$Target`" `"$LinkName`""
        
        try {
            Invoke-WSLCommand -DistroName $WSLDistro -Command $linkCommand
            Write-LogInfo "Created symlink: $LinkName -> $Target"
        }
        catch {
            Write-LogWarning "Could not create symlink: $LinkName -> $Target"
        }
    }
    else {
        Write-LogInfo "Skipping symlink creation on Windows: $LinkName -> $Target"
    }
}

# Reassemble AppImage
function Invoke-AppImageReassembly {
    [CmdletBinding()]
    param()

    $appImagePattern = "CloudToLocalLLM-*-x86_64.AppImage.part*"
    $appImageParts = Get-ChildItem -Path $DistPath -Filter $appImagePattern

    if ($appImageParts.Count -gt 0) {
        # Determine the base name from the first part
        $firstPart = $appImageParts[0].Name
        $baseName = $firstPart -replace '\.part.*$', ''
        
        if (Invoke-FileReassembly -BaseName "AppImage" -OutputFile $baseName -PartsPattern $appImagePattern) {
            Set-ExecutablePermission -FilePath $baseName
        }
    }
    else {
        Write-LogWarning "No AppImage parts found"
    }
}

# Reassemble AUR binary package
function Invoke-AURPackageReassembly {
    [CmdletBinding()]
    param()

    $aurPattern = "cloudtolocalllm-*-x86_64.tar.gz.part*"
    $aurParts = Get-ChildItem -Path $DistPath -Filter $aurPattern

    if ($aurParts.Count -gt 0) {
        # Determine the base name from the first part
        $firstPart = $aurParts[0].Name
        $baseName = $firstPart -replace '\.part.*$', ''
        
        Invoke-FileReassembly -BaseName "AUR binary package" -OutputFile $baseName -PartsPattern $aurPattern
    }
    else {
        Write-LogWarning "No AUR binary package parts found"
    }
}

# Reassemble tray daemon
function Invoke-TrayDaemonReassembly {
    [CmdletBinding()]
    param()

    $trayDir = Join-Path $DistPath "tray_daemon\linux-x64"
    $trayPattern = "cloudtolocalllm-enhanced-tray.gz.part*"

    if (Test-Path $trayDir) {
        $trayParts = Get-ChildItem -Path $trayDir -Filter $trayPattern

        if ($trayParts.Count -gt 0) {
            # Change to tray directory for operations
            $originalLocation = Get-Location
            Set-Location $trayDir

            try {
                if (Invoke-FileReassembly -BaseName "tray daemon (compressed)" -OutputFile "cloudtolocalllm-enhanced-tray.gz" -PartsPattern $trayPattern) {
                    if (Expand-GzipFile -GzipFile "cloudtolocalllm-enhanced-tray.gz" -OutputFile "cloudtolocalllm-enhanced-tray") {
                        Set-ExecutablePermission -FilePath "cloudtolocalllm-enhanced-tray"
                        
                        # Create symlink for AUR package compatibility
                        $symlinkPath = Join-Path $trayDir "cloudtolocalllm-tray"
                        if (-not (Test-Path $symlinkPath)) {
                            New-SymbolicLink -Target "cloudtolocalllm-enhanced-tray" -LinkName "cloudtolocalllm-tray" -Directory "tray_daemon\linux-x64"
                            Write-LogInfo "Created symlink for AUR package compatibility"
                        }
                    }
                }
            }
            finally {
                Set-Location $originalLocation
            }
        }
        else {
            Write-LogWarning "No tray daemon parts found"
        }
    }
    else {
        Write-LogWarning "Tray daemon directory not found: $trayDir"
    }
}

# Main execution function
function Invoke-Main {
    [CmdletBinding()]
    param()

    Test-Prerequisites

    Write-LogInfo "Reassembling binary files in: $DistPath"
    Write-Host ""

    # Change to dist directory
    Set-Location $DistPath

    # Reassemble all binary types
    Invoke-AppImageReassembly
    Invoke-AURPackageReassembly
    Invoke-TrayDaemonReassembly

    Write-Host ""
    Write-LogSuccess "Binary reassembly completed!"
    Write-LogInfo "Files are ready for deployment and AUR package creation"
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
