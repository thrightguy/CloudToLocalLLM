#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for WSL Flutter integration

.DESCRIPTION
    This script tests the WSL Flutter integration functionality including:
    - WSL Flutter installation verification
    - Flutter version command execution
    - Flutter doctor command execution

.EXAMPLE
    .\Test-WSLFlutter.ps1
    
    Runs all WSL Flutter integration tests

.NOTES
    This script requires Ubuntu WSL with Flutter installed at /opt/flutter/bin
#>

# Import the utilities
. "$PSScriptRoot/BuildEnvironmentUtilities.ps1"

Write-Host "Testing WSL Flutter Integration" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# Test WSL Flutter installation
Write-Host "`nTesting WSL Flutter installation..." -ForegroundColor Cyan
if (Test-WSLFlutterInstallation) {
    Write-Host "✅ WSL Flutter installation test passed" -ForegroundColor Green
} else {
    Write-Host "❌ WSL Flutter installation test failed" -ForegroundColor Red
    exit 1
}

# Test Flutter version command
Write-Host "`nTesting Flutter version command..." -ForegroundColor Cyan
try {
    $version = Invoke-WSLFlutterCommand -FlutterArgs "--version" -PassThru
    Write-Host "✅ Flutter version: $($version.Split("`n")[0])" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter version command failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test Flutter doctor
Write-Host "`nTesting Flutter doctor..." -ForegroundColor Cyan
try {
    $doctor = Invoke-WSLFlutterCommand -FlutterArgs "doctor" -PassThru
    Write-Host "✅ Flutter doctor completed" -ForegroundColor Green
    Write-Host "Doctor output (first 5 lines):" -ForegroundColor Yellow
    $doctor.Split("`n")[0..4] | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} catch {
    Write-Host "❌ Flutter doctor failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 All WSL Flutter tests passed!" -ForegroundColor Green
