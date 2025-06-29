#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick development push - commit and push all changes when documentation is complete.

.DESCRIPTION
    Simple shortcut script for CloudToLocalLLM developers to quickly commit and push
    all uncommitted changes when development work and documentation are complete.

.PARAMETER m
    Commit message (optional, auto-generated if not provided)

.PARAMETER f
    Force push (skip validation checks)

.PARAMETER dry
    Dry run (show what would be committed)

.EXAMPLE
    .\push-dev.ps1
    # Auto-commit and push with generated message

.EXAMPLE
    .\push-dev.ps1 -m "Complete zrok implementation"
    # Custom commit message

.EXAMPLE
    .\push-dev.ps1 -dry
    # Preview changes without committing
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Alias("m")]
    [string]$Message = "",
    
    [Parameter(Mandatory = $false)]
    [Alias("f")]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [Alias("dry")]
    [switch]$DryRun
)

# Simply call the Auto-CommitAndPush script with the provided parameters
$scriptPath = "scripts/powershell/Auto-CommitAndPush.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ Auto-CommitAndPush script not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

$params = @{}
if ($Message) { $params.Message = $Message }
if ($Force) { $params.Force = $true }
if ($DryRun) { $params.DryRun = $true }

& $scriptPath @params
