# CloudToLocalLLM Logging Module
# This module provides centralized logging functionality for all scripts

$script:LogFile = Join-Path $PSScriptRoot "..\logs\cloudtolocalllm.log"
$script:LogLevel = "INFO" # Can be DEBUG, INFO, WARN, ERROR
$script:MaxLogSize = 10MB # Maximum log file size before rotation
$script:MaxLogFiles = 5 # Number of log files to keep

# Create logs directory if it doesn't exist
$logsDir = Split-Path $script:LogFile -Parent
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

function Write-LogMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory=$false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    
    # Check if we should log based on log level
    $LogLevels = @{
        "DEBUG" = 0
        "INFO" = 1
        "WARN" = 2
        "ERROR" = 3
    }
    
    if ($LogLevels[$Level] -ge $LogLevels[$script:LogLevel]) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        
        # Write to console with color
        Write-Host $logMessage -ForegroundColor $ForegroundColor
        
        # Write to log file
        try {
            # Check log file size and rotate if necessary
            if ((Test-Path $script:LogFile) -and 
                ((Get-Item $script:LogFile).Length -gt $script:MaxLogSize)) {
                Rotate-LogFile
            }
            
            Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to write to log file: $_" -ForegroundColor Red
        }
    }
}

function Rotate-LogFile {
    # Rotate existing log files
    for ($i = $script:MaxLogFiles - 1; $i -ge 0; $i--) {
        $currentFile = if ($i -eq 0) { $script:LogFile } else { "$script:LogFile.$i" }
        $nextFile = "$script:LogFile.$($i + 1)"
        
        if (Test-Path $currentFile) {
            if ($i -eq ($script:MaxLogFiles - 1)) {
                Remove-Item $currentFile -Force
            } else {
                Move-Item $currentFile $nextFile -Force
            }
        }
    }
}

function Write-Debug {
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "DEBUG" -ForegroundColor Gray
}

function Write-Info {
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "INFO" -ForegroundColor White
}

function Write-Warning {
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "WARN" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "ERROR" -ForegroundColor Red
}

function Get-LogFile {
    return $script:LogFile
}

function Set-LogLevel {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level
    )
    $script:LogLevel = $Level
} 