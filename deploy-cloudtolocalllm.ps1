# PowerShell script to automate CloudToLocalLLM deployment on Render with Auth0 setup guidance
# Prerequisites: Render CLI installed, GitHub CLI installed, logged into both

# Configuration
$REPO_NAME = "CloudToLocalLLM"
$RENDER_SERVICE_NAME = "cloudtolocalllm-cloud"
$BRANCH = "main"
$ROOT_DIR = "webapp"

# Step 1: Guide user through Auth0 setup
Write-Host "=== Auth0 Setup ==="
Write-Host "Let's set up your Auth0 account for authentication."
Write-Host "If you don't have an Auth0 account, please sign up at https://auth0.com/signup"
$hasAuth0 = Read-Host "Do you have an Auth0 account? (yes/no)"
if ($hasAuth0 -eq "no") {
    Write-Host "Please visit https://auth0.com/signup to create a free Auth0 account."
    Write-Host "After creating your account, come back and run this script again."
    exit 0
}

Write-Host "Please log in to your Auth0 dashboard at https://manage.auth0.com/"
Write-Host "Follow these steps to create a new Auth0 Application:"
Write-Host "1. Go to 'Applications' > 'Create Application'"
Write-Host "2. Name it 'CloudToLocalLLM'"
Write-Host "3. Select 'Regular Web Applications'"
Write-Host "4. Click 'Create'"
Write-Host "Press Enter when you have created the application..."
Read-Host

# Prompt for Auth0 credentials
Write-Host "Now, please provide your Auth0 application details."
$AUTH0_DOMAIN = Read-Host "Enter your Auth0 Domain (e.g., your-tenant.auth0.com)"
$AUTH0_CLIENT_ID = Read-Host "Enter your Auth0 Client ID"
$AUTH0_CLIENT_SECRET = Read-Host "Enter your Auth0 Client Secret" -AsSecureString
$AUTH0_CLIENT_SECRET = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AUTH0_CLIENT_SECRET))

# Generate secrets
$SESSION_SECRET = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))
$JWT_SECRET = [Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))

# Step 2: Verify prerequisites
Write-Host "Verifying prerequisites..."
if (-not (Get-Command render -ErrorAction SilentlyContinue)) {
    Write-Error "Render CLI not found. Please install it from https://render.com/docs/cli"
    exit 1
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI not found. Please install it from https://cli.github.com/"
    exit 1
}

# Step 3: Clone or verify repository
Write-Host "Setting up repository..."
if (-not (Test-Path "./$REPO_NAME")) {
    gh repo clone $REPO_NAME
    Set-Location $REPO_NAME
} else {
    Set-Location $REPO_NAME
}

# Step 4: Create render.yaml if it doesn't exist
Write-Host "Creating render.yaml..."
$renderYaml = @"
services:
- type: web
  name: $RENDER_SERVICE_NAME
  env: node
  branch: $BRANCH
  rootDir: $ROOT_DIR
  buildCommand: npm install
  startCommand: npm start
  envVars:
  - key: NODE_ENV
    value: production
  - key: SESSION_SECRET
    value: $SESSION_SECRET
  - key: JWT_SECRET
    value: $JWT_SECRET
  - key: AUTH0_DOMAIN
    value: $AUTH0_DOMAIN
  - key: AUTH0_CLIENT_ID
    value: $AUTH0_CLIENT_ID
  - key: AUTH0_CLIENT_SECRET
    value: $AUTH0_CLIENT_SECRET
  - key: AUTH0_CALLBACK_URL
    sync: false # Will be set after service creation
"@

Set-Content -Path "render.yaml" -Value $renderYaml

# Step 5: Commit render.yaml
Write-Host "Committing render.yaml..."
git add render.yaml
git commit -m "Add Render configuration"
git push origin $BRANCH

# Step 6: Deploy to Render
Write-Host "Deploying to Render..."
render blueprint apply

# Step 7: Get service URL and configure Auth0 callback
Write-Host "Configuring Auth0 callback URL..."
$service = render service list | Where-Object { $_ -match $RENDER_SERVICE_NAME }
if ($service -match "https://(.+).onrender.com") {
    $serviceUrl = $Matches[0]
    $callbackUrl = "$serviceUrl/callback"
    
    # Update environment variable
    render service env set --service $RENDER_SERVICE_NAME --key AUTH0_CALLBACK_URL --value $callbackUrl
    
    Write-Host "Deployment completed!"
    Write-Host "Service URL: $serviceUrl"
    Write-Host "Please go back to your Auth0 dashboard and update your Application's settings:"
    Write-Host "1. Go to 'Applications' > 'CloudToLocalLLM'"
    Write-Host "2. Find 'Allowed Callback URLs'"
    Write-Host "3. Add: $callbackUrl"
    Write-Host "4. Save changes"
    Write-Host "Press Enter after updating the callback URL in Auth0..."
    Read-Host
} else {
    Write-Error "Could not determine service URL. Please check Render dashboard."
    exit 1
}

# Step 8: Verify deployment
Write-Host "Verifying deployment..."
Start-Sleep -Seconds 30 # Wait for deployment to stabilize
$status = (Invoke-WebRequest -Uri $serviceUrl -UseBasicParsing -Method Head).StatusCode
if ($status -eq 200) {
    Write-Host "Deployment verified successfully!"
    Write-Host "Your CloudToLocalLLM cloud component is now running at $serviceUrl"
} else {
    Write-Warning "Deployment may have issues. Status code: $status"
    Write-Host "Check Render dashboard logs for details."
}