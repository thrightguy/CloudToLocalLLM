# CloudToLocalLLM PowerShell Wrapper
# Launches the CloudToLocalLLM application

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExePath = Join-Path $ScriptDir "cloudtolocalllm.exe"

if (Test-Path $ExePath) {
    & $ExePath $args
}
else {
    Write-Error "CloudToLocalLLM executable not found at $ExePath"
    exit 1
}
