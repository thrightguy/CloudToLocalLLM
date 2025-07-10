# CloudToLocalLLM Tunnel Verification Test Runner
# Runs Playwright tests to verify tunnel usage and prevent localhost calls

param(
    [string]$DeploymentUrl = "https://app.cloudtolocalllm.online",
    [switch]$Headless = $false,
    [switch]$Debug = $false,
    [string]$Browser = "chromium"
)

Write-Host "🧪 CloudToLocalLLM Tunnel Verification Test" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Set environment variables
$env:DEPLOYMENT_URL = $DeploymentUrl
$env:PWDEBUG = if ($Debug) { "1" } else { "0" }

Write-Host "🌐 Testing deployment: $DeploymentUrl" -ForegroundColor Green
Write-Host "🖥️  Browser: $Browser" -ForegroundColor Green
Write-Host "👁️  Headless: $Headless" -ForegroundColor Green
Write-Host "🐛 Debug mode: $Debug" -ForegroundColor Green

# Check if Playwright is installed
if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: npx not found. Please install Node.js" -ForegroundColor Red
    exit 1
}

# Install Playwright if needed
Write-Host "📦 Checking Playwright installation..." -ForegroundColor Yellow
try {
    npx playwright --version | Out-Null
} catch {
    Write-Host "📦 Installing Playwright..." -ForegroundColor Yellow
    npx playwright install
}

# Create test results directory
$testResultsDir = "test-results/tunnel-verification"
if (-not (Test-Path $testResultsDir)) {
    New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
}

# Build the command
$playwrightArgs = @(
    "playwright", "test",
    "tests/e2e/tunnel-verification.spec.js",
    "--project=$Browser-auth-analysis",
    "--reporter=list,html,json"
)

if ($Headless) {
    $playwrightArgs += "--headed=false"
} else {
    $playwrightArgs += "--headed=true"
}

if ($Debug) {
    $playwrightArgs += "--debug"
}

Write-Host "🚀 Starting tunnel verification tests..." -ForegroundColor Green
Write-Host "Command: npx $($playwrightArgs -join ' ')" -ForegroundColor Gray

# Run the test
try {
    $result = & npx @playwrightArgs
    $exitCode = $LASTEXITCODE
    
    Write-Host "`n📊 Test Results:" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    
    if ($exitCode -eq 0) {
        Write-Host "✅ All tunnel verification tests passed!" -ForegroundColor Green
        Write-Host "🛡️  No localhost calls detected" -ForegroundColor Green
        Write-Host "🌐 Cloud proxy tunnel working correctly" -ForegroundColor Green
    } else {
        Write-Host "❌ Some tests failed!" -ForegroundColor Red
        Write-Host "🚨 Check the output above for localhost calls" -ForegroundColor Red
        Write-Host "🔍 Review the HTML report for detailed analysis" -ForegroundColor Yellow
    }
    
    # Show report locations
    Write-Host "`n📋 Test Reports:" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    Write-Host "📄 HTML Report: test-results/html-report/index.html" -ForegroundColor Gray
    Write-Host "📊 JSON Report: test-results/test-results.json" -ForegroundColor Gray
    Write-Host "🌐 Network HAR: test-results/network.har" -ForegroundColor Gray
    
    if (Test-Path "test-results/html-report/index.html") {
        Write-Host "`n🌐 Opening HTML report..." -ForegroundColor Green
        Start-Process "test-results/html-report/index.html"
    }
    
    exit $exitCode
    
} catch {
    Write-Host "❌ Error running tests: $_" -ForegroundColor Red
    exit 1
}
