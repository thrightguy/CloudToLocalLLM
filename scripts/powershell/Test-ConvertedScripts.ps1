# CloudToLocalLLM Converted Scripts Test Suite (PowerShell)
# Validates all converted PowerShell scripts for functionality and consistency

[CmdletBinding()]
param(
    [switch]$QuickTest,
    [switch]$FullTest,
    [switch]$HelpOnly,
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
    Write-Host "CloudToLocalLLM Converted Scripts Test Suite (PowerShell)" -ForegroundColor Blue
    Write-Host "=========================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Validates all converted PowerShell scripts for functionality and consistency" -ForegroundColor White
    Write-Host ""
    Write-Host "Usage: .\Test-ConvertedScripts.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -QuickTest            Run quick validation tests only"
    Write-Host "  -FullTest             Run comprehensive tests (requires WSL)"
    Write-Host "  -HelpOnly             Test only help systems of all scripts"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\Test-ConvertedScripts.ps1 -HelpOnly"
    Write-Host "  .\Test-ConvertedScripts.ps1 -QuickTest"
    Write-Host "  .\Test-ConvertedScripts.ps1 -FullTest -AutoInstall"
    exit 0
}

# Configuration
$ProjectRoot = Get-ProjectRoot
$TestResults = @()

Write-Host "CloudToLocalLLM Converted Scripts Test Suite (PowerShell)" -ForegroundColor Blue
Write-Host "=========================================================" -ForegroundColor Blue
Write-Host ""

# Test result tracking
function Add-TestResult {
    param(
        [string]$ScriptName,
        [string]$TestType,
        [bool]$Passed,
        [string]$Details = "",
        [string]$ErrorMessage = ""
    )
    
    $script:TestResults += @{
        ScriptName = $ScriptName
        TestType = $TestType
        Passed = $Passed
        Details = $Details
        ErrorMessage = $ErrorMessage
    }
    
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "[$status] $ScriptName - $TestType" -ForegroundColor $color
    if ($Details) {
        Write-Host "       $Details" -ForegroundColor Gray
    }
    if ($ErrorMessage -and -not $Passed) {
        Write-Host "       Error: $ErrorMessage" -ForegroundColor Red
    }
}

# Test script help system
function Test-ScriptHelp {
    param([string]$ScriptPath, [string]$ScriptName)
    
    try {
        $result = & powershell -ExecutionPolicy Bypass -File $ScriptPath -Help 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0 -and $result -match "Usage:") {
            Add-TestResult -ScriptName $ScriptName -TestType "Help System" -Passed $true -Details "Help system working correctly"
            return $true
        }
        else {
            Add-TestResult -ScriptName $ScriptName -TestType "Help System" -Passed $false -ErrorMessage "Help system failed or incomplete"
            return $false
        }
    }
    catch {
        Add-TestResult -ScriptName $ScriptName -TestType "Help System" -Passed $false -ErrorMessage $_.Exception.Message
        return $false
    }
}

# Test script syntax
function Test-ScriptSyntax {
    param([string]$ScriptPath, [string]$ScriptName)
    
    try {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ScriptPath -Raw), [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Add-TestResult -ScriptName $ScriptName -TestType "Syntax Check" -Passed $true -Details "No syntax errors found"
            return $true
        }
        else {
            $errorDetails = ($errors | ForEach-Object { $_.Message }) -join "; "
            Add-TestResult -ScriptName $ScriptName -TestType "Syntax Check" -Passed $false -ErrorMessage $errorDetails
            return $false
        }
    }
    catch {
        Add-TestResult -ScriptName $ScriptName -TestType "Syntax Check" -Passed $false -ErrorMessage $_.Exception.Message
        return $false
    }
}

# Test script patterns compliance
function Test-ScriptPatterns {
    param([string]$ScriptPath, [string]$ScriptName)
    
    $content = Get-Content $ScriptPath -Raw
    $passed = $true
    $issues = @()
    
    # Check for BuildEnvironmentUtilities import
    if ($content -notmatch 'BuildEnvironmentUtilities\.ps1') {
        $issues += "Missing BuildEnvironmentUtilities import"
        $passed = $false
    }
    
    # Check for logging functions usage
    if ($content -notmatch 'Write-Log(Info|Success|Warning|Error)') {
        $issues += "Not using standard logging functions"
        $passed = $false
    }
    
    # Check for error handling
    if ($content -notmatch 'trap\s*\{') {
        $issues += "Missing error handling trap block"
        $passed = $false
    }
    
    # Check for help system
    if ($content -notmatch '\$Help.*Show.*help') {
        $issues += "Missing help system"
        $passed = $false
    }
    
    # Check for parameter validation
    if ($content -notmatch '\[CmdletBinding\(\)\]') {
        $issues += "Missing CmdletBinding attribute"
        $passed = $false
    }
    
    $details = if ($passed) { "All patterns compliant" } else { $issues -join "; " }
    Add-TestResult -ScriptName $ScriptName -TestType "Pattern Compliance" -Passed $passed -Details $details
    
    return $passed
}

# Test script dependencies
function Test-ScriptDependencies {
    param([string]$ScriptPath, [string]$ScriptName)
    
    try {
        # Test if script can load without errors (dry run)
        $result = & powershell -ExecutionPolicy Bypass -Command "
            try {
                . '$ScriptPath'
                Write-Output 'SUCCESS'
            }
            catch {
                Write-Output 'ERROR: ' + `$_.Exception.Message
            }
        " 2>&1
        
        if ($result -match "SUCCESS") {
            Add-TestResult -ScriptName $ScriptName -TestType "Dependencies" -Passed $true -Details "All dependencies available"
            return $true
        }
        else {
            $errorMsg = ($result | Where-Object { $_ -match "ERROR:" }) -join "; "
            Add-TestResult -ScriptName $ScriptName -TestType "Dependencies" -Passed $false -ErrorMessage $errorMsg
            return $false
        }
    }
    catch {
        Add-TestResult -ScriptName $ScriptName -TestType "Dependencies" -Passed $false -ErrorMessage $_.Exception.Message
        return $false
    }
}

# Get list of converted PowerShell scripts
function Get-ConvertedScripts {
    $scriptDir = Join-Path $ProjectRoot "scripts\powershell"
    
    $convertedScripts = @(
        @{ Name = "version_manager.ps1"; Path = Join-Path $scriptDir "version_manager.ps1" },
        @{ Name = "build_unified_package.ps1"; Path = Join-Path $scriptDir "build_unified_package.ps1" },
        @{ Name = "deploy_vps.ps1"; Path = Join-Path $scriptDir "deploy_vps.ps1" },
        @{ Name = "simple_timestamp_injector.ps1"; Path = Join-Path $scriptDir "simple_timestamp_injector.ps1" },
        @{ Name = "build_deb.ps1"; Path = Join-Path $scriptDir "build_deb.ps1" },
        @{ Name = "create_unified_aur_package.ps1"; Path = Join-Path $scriptDir "create_unified_aur_package.ps1" },
        @{ Name = "build_time_version_injector.ps1"; Path = Join-Path $scriptDir "build_time_version_injector.ps1" },
        @{ Name = "verify_local_resources.ps1"; Path = Join-Path $scriptDir "verify_local_resources.ps1" },
        @{ Name = "reassemble_binaries.ps1"; Path = Join-Path $scriptDir "reassemble_binaries.ps1" },
        @{ Name = "build_all_packages.ps1"; Path = Join-Path $scriptDir "build_all_packages.ps1" }
    )
    
    # Filter to only existing scripts
    return $convertedScripts | Where-Object { Test-Path $_.Path }
}

# Run tests on all converted scripts
function Invoke-ScriptTests {
    $scripts = Get-ConvertedScripts
    
    Write-LogInfo "Found $($scripts.Count) converted PowerShell scripts to test"
    Write-Host ""
    
    foreach ($script in $scripts) {
        Write-Host "Testing: $($script.Name)" -ForegroundColor Cyan
        Write-Host "Path: $($script.Path)" -ForegroundColor Gray
        
        # Always test syntax
        Test-ScriptSyntax -ScriptPath $script.Path -ScriptName $script.Name
        
        # Always test help system
        Test-ScriptHelp -ScriptPath $script.Path -ScriptName $script.Name
        
        if (-not $HelpOnly) {
            # Test patterns compliance
            Test-ScriptPatterns -ScriptPath $script.Path -ScriptName $script.Name
            
            if ($FullTest) {
                # Test dependencies (more comprehensive)
                Test-ScriptDependencies -ScriptPath $script.Path -ScriptName $script.Name
            }
        }
        
        Write-Host ""
    }
}

# Generate test summary
function Show-TestSummary {
    Write-Host ""
    Write-Host "=== Test Summary ===" -ForegroundColor Cyan
    Write-Host ""
    
    $totalTests = $script:TestResults.Count
    $passedTests = ($script:TestResults | Where-Object { $_.Passed }).Count
    $failedTests = $totalTests - $passedTests
    
    Write-Host "Total Tests: $totalTests"
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $failedTests" -ForegroundColor $(if($failedTests -eq 0){'Green'}else{'Red'})
    
    if ($failedTests -gt 0) {
        Write-Host ""
        Write-Host "Failed Tests:" -ForegroundColor Red
        $script:TestResults | Where-Object { -not $_.Passed } | ForEach-Object {
            Write-Host "  • $($_.ScriptName) - $($_.TestType): $($_.ErrorMessage)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    if ($failedTests -eq 0) {
        Write-Host "🎉 All tests passed! Converted scripts are ready for use." -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Some tests failed. Review the issues above." -ForegroundColor Yellow
    }
}

# Main execution function
function Invoke-Main {
    Write-LogInfo "Starting converted scripts test suite..."
    
    if ($HelpOnly) {
        Write-LogInfo "Running help system tests only"
    }
    elseif ($QuickTest) {
        Write-LogInfo "Running quick validation tests"
    }
    elseif ($FullTest) {
        Write-LogInfo "Running comprehensive tests"
    }
    else {
        Write-LogInfo "Running standard tests (use -QuickTest, -FullTest, or -HelpOnly for specific test modes)"
    }
    
    Invoke-ScriptTests
    Show-TestSummary
}

# Error handling
trap {
    Write-LogError "Test suite failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
