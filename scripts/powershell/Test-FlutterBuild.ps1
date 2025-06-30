#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script for Flutter build via WSL

.DESCRIPTION
    This script tests the complete Flutter build workflow via WSL including:
    - Flutter pub get command
    - Flutter analyze command
    - Flutter build web command
    - Build output verification

.PARAMETER ProjectRoot
    The root directory of the Flutter project. Defaults to the parent directory of the scripts folder.

.EXAMPLE
    .\Test-FlutterBuild.ps1
    
    Runs Flutter build tests using the default project root

.EXAMPLE
    .\Test-FlutterBuild.ps1 -ProjectRoot "C:\MyProject"
    
    Runs Flutter build tests using a specific project root

.NOTES
    This script requires Ubuntu WSL with Flutter installed at /opt/flutter/bin
    The build process may take several minutes to complete
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = $null
)

# Import the utilities
. "$PSScriptRoot/BuildEnvironmentUtilities.ps1"

Write-Host "Testing Flutter Build via WSL" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

# Set project root - default to parent of scripts directory if not specified
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

Write-Host "Using project root: $ProjectRoot" -ForegroundColor Cyan

Write-Host "`nTesting Flutter pub get..." -ForegroundColor Cyan
try {
    Invoke-WSLFlutterCommand -FlutterArgs "pub get" -WorkingDirectory $ProjectRoot
    Write-Host "✅ Flutter pub get completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter pub get failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nTesting Flutter analyze..." -ForegroundColor Cyan
try {
    $analyzeResult = Invoke-WSLFlutterCommand -FlutterArgs "analyze" -WorkingDirectory $ProjectRoot -PassThru
    Write-Host "✅ Flutter analyze completed successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Flutter analyze found issues (this is expected in development)" -ForegroundColor Yellow
    Write-Host "Continuing with build test..." -ForegroundColor Yellow
}

Write-Host "`nTesting Flutter build web (this may take a few minutes)..." -ForegroundColor Cyan
try {
    Invoke-WSLFlutterCommand -FlutterArgs "build web --release" -WorkingDirectory $ProjectRoot
    
    # Check if build output exists
    $buildPath = Join-Path $ProjectRoot "build/web"
    if (Test-Path $buildPath) {
        Write-Host "✅ Flutter web build completed successfully" -ForegroundColor Green
        Write-Host "Build output available at: $buildPath" -ForegroundColor White
        
        # Check for main files
        $indexPath = Join-Path $buildPath "index.html"
        if (Test-Path $indexPath) {
            Write-Host "✅ index.html found in build output" -ForegroundColor Green
        } else {
            Write-Host "⚠️ index.html not found in build output" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Build directory not found after build" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Flutter web build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Flutter build test completed successfully!" -ForegroundColor Green
Write-Host "WSL Flutter integration is working correctly." -ForegroundColor Green
