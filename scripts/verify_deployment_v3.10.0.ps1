# CloudToLocalLLM v3.10.0 Deployment Verification Script
# Verifies that the login loop race condition fix is working correctly

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$Auth0Domain = "",
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 30,
    
    [switch]$Verbose
)

# Import utilities if available
$utilsPath = Join-Path $PSScriptRoot "BuildEnvironmentUtilities.ps1"
if (Test-Path $utilsPath) {
    . $utilsPath
} else {
    # Define basic logging functions if utilities not available
    function Write-LogInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
    function Write-LogSuccess { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
    function Write-LogWarning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
    function Write-LogError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
}

Write-Host "CloudToLocalLLM v3.10.0 Deployment Verification" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Normalize URL
if (-not $DeploymentUrl.StartsWith("http")) {
    $DeploymentUrl = "https://$DeploymentUrl"
}

Write-LogInfo "Testing deployment at: $DeploymentUrl"
Write-LogInfo "Timeout: $TimeoutSeconds seconds"
Write-Host ""

# Test results
$TestResults = @{
    "Basic Connectivity" = $false
    "Version Check" = $false
    "Authentication Pages" = $false
    "Security Headers" = $false
    "Static Assets" = $false
    "Service Worker" = $false
}

# Test 1: Basic Connectivity
Write-LogInfo "Test 1: Basic Connectivity"
try {
    $response = Invoke-WebRequest -Uri $DeploymentUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-LogSuccess "✅ Site is accessible (HTTP $($response.StatusCode))"
        $TestResults["Basic Connectivity"] = $true
    } else {
        Write-LogWarning "⚠️ Unexpected status code: $($response.StatusCode)"
    }
} catch {
    Write-LogError "❌ Failed to connect: $($_.Exception.Message)"
}

# Test 2: Version Check
Write-LogInfo "Test 2: Version Check"
try {
    $versionUrl = "$DeploymentUrl/version.json"
    $versionResponse = Invoke-WebRequest -Uri $versionUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
    $versionData = $versionResponse.Content | ConvertFrom-Json
    
    if ($versionData.version -eq "3.10.0") {
        Write-LogSuccess "✅ Correct version deployed: $($versionData.version)"
        Write-LogInfo "   Build number: $($versionData.build_number)"
        $TestResults["Version Check"] = $true
    } else {
        Write-LogWarning "⚠️ Unexpected version: $($versionData.version)"
    }
} catch {
    Write-LogError "❌ Failed to check version: $($_.Exception.Message)"
}

# Test 3: Authentication Pages
Write-LogInfo "Test 3: Authentication Pages"
$authPages = @("/login", "/callback", "/loading")
$authPagesWorking = 0

foreach ($page in $authPages) {
    try {
        $pageUrl = "$DeploymentUrl$page"
        $pageResponse = Invoke-WebRequest -Uri $pageUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
        if ($pageResponse.StatusCode -eq 200) {
            Write-LogSuccess "✅ $page accessible"
            $authPagesWorking++
        } else {
            Write-LogWarning "⚠️ $page returned status: $($pageResponse.StatusCode)"
        }
    } catch {
        Write-LogError "❌ $page failed: $($_.Exception.Message)"
    }
}

if ($authPagesWorking -eq $authPages.Count) {
    $TestResults["Authentication Pages"] = $true
}

# Test 4: Security Headers
Write-LogInfo "Test 4: Security Headers"
try {
    $response = Invoke-WebRequest -Uri $DeploymentUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
    $headers = $response.Headers
    
    $securityHeaders = @{
        "X-Content-Type-Options" = "nosniff"
        "X-Frame-Options" = "DENY"
        "X-XSS-Protection" = "1; mode=block"
    }
    
    $securityHeadersPresent = 0
    foreach ($header in $securityHeaders.GetEnumerator()) {
        if ($headers.ContainsKey($header.Key)) {
            Write-LogSuccess "✅ $($header.Key): $($headers[$header.Key])"
            $securityHeadersPresent++
        } else {
            Write-LogWarning "⚠️ Missing security header: $($header.Key)"
        }
    }
    
    if ($securityHeadersPresent -gt 0) {
        $TestResults["Security Headers"] = $true
    }
} catch {
    Write-LogError "❌ Failed to check security headers: $($_.Exception.Message)"
}

# Test 5: Static Assets
Write-LogInfo "Test 5: Static Assets"
$assets = @("/main.dart.js", "/flutter.js", "/manifest.json", "/favicon.png")
$assetsWorking = 0

foreach ($asset in $assets) {
    try {
        $assetUrl = "$DeploymentUrl$asset"
        $assetResponse = Invoke-WebRequest -Uri $assetUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing -Method Head
        if ($assetResponse.StatusCode -eq 200) {
            Write-LogSuccess "✅ $asset available"
            $assetsWorking++
        } else {
            Write-LogWarning "⚠️ $asset returned status: $($assetResponse.StatusCode)"
        }
    } catch {
        Write-LogError "❌ $asset failed: $($_.Exception.Message)"
    }
}

if ($assetsWorking -eq $assets.Count) {
    $TestResults["Static Assets"] = $true
}

# Test 6: Service Worker
Write-LogInfo "Test 6: Service Worker"
try {
    $swUrl = "$DeploymentUrl/flutter_service_worker.js"
    $swResponse = Invoke-WebRequest -Uri $swUrl -TimeoutSec $TimeoutSeconds -UseBasicParsing
    if ($swResponse.StatusCode -eq 200) {
        Write-LogSuccess "✅ Service worker available"
        $TestResults["Service Worker"] = $true
    } else {
        Write-LogWarning "⚠️ Service worker returned status: $($swResponse.StatusCode)"
    }
} catch {
    Write-LogError "❌ Service worker failed: $($_.Exception.Message)"
}

# Summary
Write-Host ""
Write-Host "Deployment Verification Summary" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

$passedTests = 0
$totalTests = $TestResults.Count

foreach ($test in $TestResults.GetEnumerator()) {
    if ($test.Value) {
        Write-Host "✅ $($test.Key)" -ForegroundColor Green
        $passedTests++
    } else {
        Write-Host "❌ $($test.Key)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Results: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-LogSuccess "🎉 All tests passed! Deployment is ready for production."
} elseif ($passedTests -ge ($totalTests * 0.8)) {
    Write-LogWarning "⚠️ Most tests passed, but some issues detected. Review and fix before production use."
} else {
    Write-LogError "❌ Multiple tests failed. Deployment needs attention before production use."
}

# Login Loop Fix Verification Instructions
Write-Host ""
Write-Host "Manual Login Loop Fix Verification" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "To verify the login loop race condition fix:"
Write-Host "1. Open $DeploymentUrl in a browser"
Write-Host "2. Click 'Sign In with Auth0'"
Write-Host "3. Complete authentication"
Write-Host "4. Verify you're redirected to home page (not back to login)"
Write-Host "5. Check browser console for debug messages:"
Write-Host "   - '🔐 [Callback] Authentication successful, redirecting to home'"
Write-Host "   - '🔄 [Router] Allowing access to protected route'"
Write-Host ""

if ($Auth0Domain) {
    Write-Host "Auth0 Configuration Check" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "Ensure these URLs are configured in Auth0:"
    Write-Host "Callback URLs: $DeploymentUrl/callback"
    Write-Host "Logout URLs: $DeploymentUrl/"
    Write-Host "Web Origins: $DeploymentUrl"
    Write-Host "CORS Origins: $DeploymentUrl"
}

Write-Host ""
Write-Host "Deployment verification completed." -ForegroundColor Blue

# Exit with appropriate code
exit $(if ($passedTests -eq $totalTests) { 0 } else { 1 })
