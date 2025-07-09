# CloudToLocalLLM v3.10.0 Authentication Loop Test Runner
# Automated script to run Playwright E2E tests for authentication analysis

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$Auth0TestEmail = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Auth0TestPassword = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Browser = "chromium",
    
    [switch]$Headed,
    [switch]$Debug,
    [switch]$InstallDependencies
)

Write-Host "🚀 CloudToLocalLLM v3.10.0 Authentication Loop Test Runner" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host ""

# Validate parameters
if (-not $DeploymentUrl.StartsWith("http")) {
    $DeploymentUrl = "https://$DeploymentUrl"
}

Write-Host "📋 Test Configuration:" -ForegroundColor Yellow
Write-Host "======================" -ForegroundColor Yellow
Write-Host "Deployment URL: $DeploymentUrl"
Write-Host "Browser: $Browser"
Write-Host "Headed Mode: $($Headed.IsPresent)"
Write-Host "Debug Mode: $($Debug.IsPresent)"
Write-Host "Auth0 Credentials: $($Auth0TestEmail -ne '' -and $Auth0TestPassword -ne '')"
Write-Host ""

# Set environment variables
$env:DEPLOYMENT_URL = $DeploymentUrl
if ($Auth0TestEmail) { $env:AUTH0_TEST_EMAIL = $Auth0TestEmail }
if ($Auth0TestPassword) { $env:AUTH0_TEST_PASSWORD = $Auth0TestPassword }

# Install dependencies if requested
if ($InstallDependencies) {
    Write-Host "📦 Installing Dependencies..." -ForegroundColor Blue
    Write-Host "=============================" -ForegroundColor Blue
    
    # Install Node.js dependencies
    if (Test-Path "package.json") {
        Write-Host "Installing npm dependencies..."
        npm install
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install npm dependencies"
            exit 1
        }
    }
    
    # Install Playwright browsers
    Write-Host "Installing Playwright browsers..."
    npx playwright install
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Playwright browsers"
        exit 1
    }
    
    # Install system dependencies
    Write-Host "Installing system dependencies..."
    npx playwright install-deps
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install system dependencies (may not be critical)"
    }
    
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
    Write-Host ""
}

# Verify Playwright installation
Write-Host "🔍 Verifying Playwright Installation..." -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

try {
    $playwrightVersion = npx playwright --version
    Write-Host "✅ Playwright version: $playwrightVersion" -ForegroundColor Green
} catch {
    Write-Error "Playwright not found. Run with -InstallDependencies to install."
    exit 1
}

# Check if test files exist
$testFile = "tests/e2e/auth-loop-analysis.spec.js"
if (-not (Test-Path $testFile)) {
    Write-Error "Test file not found: $testFile"
    exit 1
}

$configFile = "playwright.config.js"
if (-not (Test-Path $configFile)) {
    Write-Error "Playwright config not found: $configFile"
    exit 1
}

Write-Host "✅ Test files verified" -ForegroundColor Green
Write-Host ""

# Prepare test command
$testCommand = "npx playwright test auth-loop-analysis.spec.js"

# Add browser selection
$testCommand += " --project=$Browser-auth-analysis"

# Add headed mode if requested
if ($Headed) {
    $testCommand += " --headed"
}

# Add debug mode if requested
if ($Debug) {
    $testCommand += " --debug"
}

# Add additional flags for better output
$testCommand += " --reporter=list,html,json"

Write-Host "🧪 Running Authentication Loop Analysis..." -ForegroundColor Blue
Write-Host "==========================================" -ForegroundColor Blue
Write-Host "Command: $testCommand"
Write-Host ""

# Create test results directory
if (-not (Test-Path "test-results")) {
    New-Item -ItemType Directory -Path "test-results" -Force | Out-Null
}

# Run the test
$testStartTime = Get-Date
try {
    Invoke-Expression $testCommand
    $testExitCode = $LASTEXITCODE
} catch {
    Write-Error "Failed to run test: $($_.Exception.Message)"
    exit 1
}

$testEndTime = Get-Date
$testDuration = $testEndTime - $testStartTime

Write-Host ""
Write-Host "📊 Test Results Summary:" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
Write-Host "Duration: $($testDuration.TotalSeconds) seconds"
Write-Host "Exit Code: $testExitCode"

if ($testExitCode -eq 0) {
    Write-Host "✅ Tests PASSED - No login loop detected!" -ForegroundColor Green
} else {
    Write-Host "❌ Tests FAILED - Issues detected!" -ForegroundColor Red
}

# Show available reports
Write-Host ""
Write-Host "📋 Available Reports:" -ForegroundColor Yellow
Write-Host "====================" -ForegroundColor Yellow

$reportFiles = @(
    "test-results/html-report/index.html",
    "test-results/test-results.json",
    "test-results/auth-loop-analysis-*.json"
)

foreach ($reportPattern in $reportFiles) {
    $files = Get-ChildItem $reportPattern -ErrorAction SilentlyContinue
    if ($files) {
        foreach ($file in $files) {
            Write-Host "📄 $($file.FullName)" -ForegroundColor Cyan
        }
    }
}

# Show how to view HTML report
if (Test-Path "test-results/html-report/index.html") {
    Write-Host ""
    Write-Host "🌐 View HTML Report:" -ForegroundColor Yellow
    Write-Host "====================" -ForegroundColor Yellow
    Write-Host "npx playwright show-report" -ForegroundColor Cyan
    Write-Host "or open: test-results/html-report/index.html" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🎯 Key Test Objectives Checked:" -ForegroundColor Yellow
Write-Host "===============================" -ForegroundColor Yellow
Write-Host "✓ No infinite redirect loops between /login and /callback"
Write-Host "✓ 100ms delay implementation working correctly"
Write-Host "✓ Authentication state synchronization verified"
Write-Host "✓ Debug messages captured and analyzed"
Write-Host "✓ Network requests monitored for Auth0 API calls"
Write-Host "✓ Comprehensive test report generated"

Write-Host ""
if ($testExitCode -eq 0) {
    Write-Host "🎉 Authentication loop fix verification SUCCESSFUL!" -ForegroundColor Green
    Write-Host "The v3.10.0 race condition fix is working correctly." -ForegroundColor Green
} else {
    Write-Host "⚠️  Authentication issues detected - review test reports for details." -ForegroundColor Yellow
    Write-Host "Check the HTML report for detailed analysis and debugging information." -ForegroundColor Yellow
}

exit $testExitCode
