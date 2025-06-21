# CloudToLocalLLM VPS Deployment Script (PowerShell)
# Deploy the latest changes to the VPS with updated packages

[CmdletBinding()]
param(
    [string]$VPSHost = "cloudtolocalllm.online",
    [string]$VPSUser = "cloudllm",
    [string]$ProjectDir = "/opt/cloudtolocalllm",
    [string]$ComposeFile = "docker-compose.multi.yml",
    [switch]$SkipBackup,
    [switch]$UseWSL,
    [string]$WSLDistro,
    [switch]$AutoInstall,
    [switch]$SkipDependencyCheck,
    [switch]$SyncSSHKeys,
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

# Configuration
$BackupDir = "$ProjectDir/backups"

# Show help
if ($Help) {
    Write-Host "CloudToLocalLLM VPS Deployment Script (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\deploy_vps.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -VPSHost              VPS hostname or IP (default: cloudtolocalllm.online)"
    Write-Host "  -VPSUser              VPS username (default: cloudllm)"
    Write-Host "  -ProjectDir           Project directory on VPS (default: /opt/cloudtolocalllm)"
    Write-Host "  -ComposeFile          Docker compose file (default: docker-compose.multi.yml)"
    Write-Host "  -SkipBackup           Skip creating backup before deployment"
    Write-Host "  -UseWSL               Use WSL for SSH operations"
    Write-Host "  -WSLDistro            Specify WSL distribution to use"
    Write-Host "  -AutoInstall          Automatically install missing dependencies"
    Write-Host "  -SkipDependencyCheck  Skip dependency validation"
    Write-Host "  -SyncSSHKeys          Synchronize SSH keys from WSL to Windows"
    Write-Host "  -Help                 Show this help message"
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Yellow
    Write-Host "  - SSH access to VPS (key-based authentication recommended)"
    Write-Host "  - Docker and docker-compose on VPS"
    Write-Host "  - Git repository access on VPS"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\deploy_vps.ps1"
    Write-Host "  .\deploy_vps.ps1 -VPSHost myserver.com -VPSUser myuser"
    Write-Host "  .\deploy_vps.ps1 -UseWSL -WSLDistro Ubuntu"
    exit 0
}

# Check prerequisites
function Test-Prerequisites {
    [CmdletBinding()]
    param()

    Write-LogInfo "Checking prerequisites..."

    # Install build dependencies
    $requiredPackages = @('git')
    if (-not $UseWSL) {
        $requiredPackages += 'openssh'
    }

    if (-not (Install-BuildDependencies -RequiredPackages $requiredPackages -AutoInstall:$AutoInstall -SkipDependencyCheck:$SkipDependencyCheck)) {
        Write-LogError "Failed to install required dependencies"
        exit 1
    }

    # Synchronize SSH keys if requested
    if ($SyncSSHKeys) {
        Write-LogInfo "Synchronizing SSH keys from WSL to Windows..."
        if (-not (Sync-SSHKeys -AutoSync)) {
            Write-LogWarning "SSH key synchronization failed, but continuing with deployment"
        }
    }

    if ($UseWSL) {
        # Check WSL availability
        if (-not (Test-WSLAvailable)) {
            Write-LogError "WSL is not available on this system"
            Write-LogInfo "Install WSL: https://docs.microsoft.com/en-us/windows/wsl/install"
            exit 1
        }

        # Find suitable WSL distribution
        $script:LinuxDistro = $WSLDistro
        if (-not $script:LinuxDistro) {
            # Just use archlinux directly since we know it exists
            $script:LinuxDistro = "archlinux"

            # Verify it exists
            $wslList = wsl -l -q
            if ($wslList -notcontains "archlinux") {
                Write-LogError "Arch Linux WSL distribution not found"
                Write-LogInfo "Available distributions:"
                wsl -l -v
                exit 1
            }
        }

        Write-LogInfo "Using WSL distribution: $script:LinuxDistro"

        # Check SSH in WSL - simplified check
        try {
            wsl -d $script:LinuxDistro which ssh | Out-Null
            Write-LogInfo "SSH found in WSL distribution: $script:LinuxDistro"
        }
        catch {
            Write-LogError "SSH not found in WSL"
            Write-LogInfo "Install in WSL: sudo pacman -S openssh"
            exit 1
        }

        $script:SSHMethod = "WSL"
    }
    else {
        # Native Windows SSH should be available after dependency installation
        if (-not (Test-Command "ssh")) {
            Write-LogError "SSH is not available after installation attempt"
            Write-LogInfo "Try using -UseWSL flag for WSL-based SSH"
            exit 1
        }

        $script:SSHMethod = "Native"
    }

    Write-LogSuccess "Prerequisites check passed (using $($script:SSHMethod) SSH)"
}

# Execute SSH command
function Invoke-SSHCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [switch]$PassThru
    )
    
    $sshTarget = "$VPSUser@$VPSHost"
    
    if ($script:SSHMethod -eq "WSL") {
        if ($PassThru) {
            return wsl -d $script:LinuxDistro ssh $sshTarget $Command
        }
        else {
            wsl -d $script:LinuxDistro ssh $sshTarget $Command
        }
    }
    else {
        if ($PassThru) {
            return ssh $sshTarget $Command
        }
        else {
            ssh $sshTarget $Command
        }
    }
}

# Test VPS connectivity
function Test-VPSConnectivity {
    [CmdletBinding()]
    param()

    Write-LogInfo "Testing VPS connectivity..."

    # Test SSH connection directly using our SSH method
    try {
        $result = Invoke-SSHCommand -Command "echo 'SSH_TEST_SUCCESS'" -PassThru
        if ($result -like "*SSH_TEST_SUCCESS*") {
            Write-LogSuccess "VPS connectivity test passed"
        }
        else {
            throw "SSH test command did not return expected result"
        }
    }
    catch {
        Write-LogError "Failed to connect to VPS: $($_.Exception.Message)"
        Write-LogInfo "Troubleshooting steps:"
        Write-LogInfo "1. Verify SSH keys are properly configured"
        Write-LogInfo "2. Check VPS accessibility and firewall settings"
        Write-LogInfo "3. Ensure SSH service is running on VPS"
        Write-LogInfo "4. Try using -SyncSSHKeys flag to synchronize SSH keys"
        exit 1
    }
}

# Check VPS environment
function Test-VPSEnvironment {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Checking VPS environment..."
    
    # Check if project directory exists
    try {
        Invoke-SSHCommand -Command "test -d $ProjectDir"
        Write-LogInfo "Project directory exists: $ProjectDir"
    }
    catch {
        Write-LogError "Project directory not found: $ProjectDir"
        Write-LogInfo "Ensure the project is properly set up on the VPS"
        exit 1
    }
    
    # Check if compose file exists
    try {
        Invoke-SSHCommand -Command "test -f $ProjectDir/$ComposeFile"
        Write-LogInfo "Docker compose file exists: $ComposeFile"
    }
    catch {
        Write-LogError "Docker compose file not found: $ProjectDir/$ComposeFile"
        exit 1
    }
    
    # Check Docker
    try {
        Invoke-SSHCommand -Command "docker --version"
        Write-LogInfo "Docker is available on VPS"
    }
    catch {
        Write-LogError "Docker is not available on VPS"
        exit 1
    }
    
    # Check docker-compose
    try {
        Invoke-SSHCommand -Command "docker-compose --version"
        Write-LogInfo "Docker Compose is available on VPS"
    }
    catch {
        Write-LogError "Docker Compose is not available on VPS"
        exit 1
    }
    
    Write-LogSuccess "VPS environment check passed"
}

# Create backup of current deployment
function New-Backup {
    [CmdletBinding()]
    param()
    
    if ($SkipBackup) {
        Write-LogInfo "Skipping backup as requested"
        return
    }
    
    Write-LogInfo "Creating backup of current deployment..."
    
    $backupTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$BackupDir/backup_$backupTimestamp"
    
    try {
        # Create backup directory
        Invoke-SSHCommand -Command "mkdir -p $backupPath"
        
        # Backup docker-compose files
        Invoke-SSHCommand -Command "cp $ProjectDir/docker-compose*.yml $backupPath/ 2>/dev/null || true"
        
        # Backup Flutter web build
        Invoke-SSHCommand -Command "if [ -d $ProjectDir/build/web ]; then cp -r $ProjectDir/build/web $backupPath/; fi"
        
        # Backup nginx config
        Invoke-SSHCommand -Command "if [ -d $ProjectDir/nginx ]; then cp -r $ProjectDir/nginx $backupPath/; fi"
        
        Write-LogSuccess "Backup created: $backupPath"
    }
    catch {
        Write-LogError "Failed to create backup: $($_.Exception.Message)"
        exit 1
    }
}

# Pull latest changes from Git
function Update-GitRepository {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Pulling latest changes from Git..."
    
    try {
        # Stash any local changes
        Invoke-SSHCommand -Command "cd $ProjectDir && git stash push -m 'Auto-stash before deployment $(Get-Date)' || true"
        
        # Pull latest changes
        Invoke-SSHCommand -Command "cd $ProjectDir && git pull origin master"
        
        Write-LogSuccess "Git pull completed"
    }
    catch {
        Write-LogError "Failed to pull Git changes: $($_.Exception.Message)"
        exit 1
    }
}

# Update Flutter environment and dependencies
function Update-FlutterEnvironment {
    [CmdletBinding()]
    param()

    Write-LogInfo "Updating Flutter SDK and dependencies..."

    try {
        # Check Flutter installation
        Write-LogInfo "Checking Flutter installation..."
        $flutterVersion = Invoke-SSHCommand -Command "flutter --version | head -1" -PassThru
        Write-LogInfo "Current Flutter version: $flutterVersion"

        # Update Flutter SDK to latest stable
        Write-LogInfo "Upgrading Flutter SDK to latest stable version..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter upgrade --force"

        # Verify Flutter installation and dependencies
        Write-LogInfo "Running Flutter doctor to verify installation..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter doctor --android-licenses || true"
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter doctor"

        # Update package dependencies to latest compatible versions
        Write-LogInfo "Upgrading package dependencies..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter pub upgrade"

        # Clean any cached builds to ensure fresh build with new dependencies
        Write-LogInfo "Cleaning previous builds..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter clean"

        # Get updated dependencies
        Write-LogInfo "Getting updated dependencies..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter pub get"

        # Verify web platform support
        Write-LogInfo "Verifying web platform support..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter config --enable-web"

        $newFlutterVersion = Invoke-SSHCommand -Command "flutter --version | head -1" -PassThru

        # Verify compatibility
        Test-FlutterCompatibility

        Write-LogSuccess "Flutter environment updated successfully"
        Write-LogInfo "Updated Flutter version: $newFlutterVersion"
    }
    catch {
        Write-LogError "Failed to update Flutter environment: $($_.Exception.Message)"
        Write-LogWarning "Continuing with existing Flutter installation..."
    }
}

# Verify Flutter version and package compatibility
function Test-FlutterCompatibility {
    [CmdletBinding()]
    param()

    Write-LogInfo "Verifying Flutter compatibility with codebase..."

    try {
        # Check minimum Flutter version requirements
        $flutterVersionOutput = Invoke-SSHCommand -Command "flutter --version | head -1" -PassThru
        $minVersion = "3.16.0"  # Minimum required Flutter version for CloudToLocalLLM

        if ($flutterVersionOutput -match 'Flutter (\d+\.\d+\.\d+)') {
            $currentVersion = $matches[1]
            Write-LogInfo "Current Flutter version: $currentVersion"
            Write-LogInfo "Minimum required version: $minVersion"

            # Simple version comparison
            $current = [Version]$currentVersion
            $minimum = [Version]$minVersion

            if ($current -lt $minimum) {
                Write-LogWarning "Flutter version $currentVersion is below minimum required version $minVersion"
                Write-LogWarning "Some features may not work correctly"
            }
            else {
                Write-LogInfo "Flutter version compatibility check passed"
            }
        }
        else {
            Write-LogWarning "Could not determine Flutter version from: $flutterVersionOutput"
        }

        # Verify web platform support
        Write-LogInfo "Checking web platform support..."
        $webSupport = Invoke-SSHCommand -Command "cd $ProjectDir && flutter config | grep 'enable-web: true' || echo 'not-enabled'" -PassThru
        if ($webSupport -notmatch "not-enabled") {
            Write-LogInfo "Web platform support is enabled"
        }
        else {
            Write-LogWarning "Web platform support may not be enabled"
            Invoke-SSHCommand -Command "cd $ProjectDir && flutter config --enable-web"
        }

        # Check for critical package compatibility issues
        Write-LogInfo "Checking package compatibility..."
        $pubspecExists = Invoke-SSHCommand -Command "test -f $ProjectDir/pubspec.yaml && echo 'exists' || echo 'missing'" -PassThru
        if ($pubspecExists.Trim() -eq "exists") {
            # Verify pubspec.yaml syntax and dependencies
            $depsCheck = Invoke-SSHCommand -Command "cd $ProjectDir && flutter pub deps > /dev/null 2>&1 && echo 'ok' || echo 'error'" -PassThru
            if ($depsCheck.Trim() -eq "ok") {
                Write-LogInfo "Package dependencies are compatible"
            }
            else {
                Write-LogWarning "Package dependency issues detected - attempting to resolve..."
                Invoke-SSHCommand -Command "cd $ProjectDir && flutter pub get"
            }
        }
        else {
            Write-LogWarning "pubspec.yaml not found in project directory"
        }

        # Test basic Flutter commands
        Write-LogInfo "Testing Flutter web build capability..."
        $buildTest = Invoke-SSHCommand -Command "cd $ProjectDir && flutter build web --help > /dev/null 2>&1 && echo 'ok' || echo 'error'" -PassThru
        if ($buildTest.Trim() -eq "ok") {
            Write-LogInfo "Flutter web build capability verified"
        }
        else {
            Write-LogWarning "Flutter web build capability test failed"
        }

        Write-LogSuccess "Flutter compatibility verification completed"
    }
    catch {
        Write-LogWarning "Flutter compatibility verification failed: $($_.Exception.Message)"
    }
}

# Build Flutter web application
function Build-FlutterWeb {
    [CmdletBinding()]
    param()

    Write-LogInfo "Building Flutter web application..."

    try {
        # Build web application with optimizations
        Write-LogInfo "Building optimized web application..."
        Invoke-SSHCommand -Command "cd $ProjectDir && flutter build web --release --no-tree-shake-icons"

        # Verify build output
        $buildExists = Invoke-SSHCommand -Command "test -d $ProjectDir/build/web && echo 'exists' || echo 'missing'" -PassThru
        if ($buildExists.Trim() -ne "exists") {
            throw "Flutter web build output not found"
        }

        # Check build size and key files
        Write-LogInfo "Verifying build output..."
        Invoke-SSHCommand -Command "cd $ProjectDir/build/web && ls -la"

        $indexExists = Invoke-SSHCommand -Command "test -f $ProjectDir/build/web/index.html && echo 'exists' || echo 'missing'" -PassThru
        if ($indexExists.Trim() -ne "exists") {
            throw "index.html not found in build output"
        }

        Write-LogSuccess "Flutter web application built successfully"
    }
    catch {
        Write-LogError "Failed to build Flutter web application: $($_.Exception.Message)"
        exit 1
    }
}

# Stop existing containers
function Stop-Containers {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Stopping existing containers..."
    
    try {
        # Stop containers gracefully
        Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile down --timeout 30 || true"
        
        # Clean up any orphaned containers
        Invoke-SSHCommand -Command "docker container prune -f || true"
        
        Write-LogSuccess "Containers stopped"
    }
    catch {
        Write-LogError "Failed to stop containers: $($_.Exception.Message)"
        exit 1
    }
}

# Build and start containers
function Start-Containers {
    [CmdletBinding()]
    param()
    
    Write-LogInfo "Building and starting containers..."
    
    try {
        # Build containers with no cache for updated static files
        Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile build --no-cache"
        
        # Start containers
        Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile up -d"
        
        Write-LogSuccess "Containers started"
    }
    catch {
        Write-LogError "Failed to start containers: $($_.Exception.Message)"
        exit 1
    }
}

# Verify deployment
function Test-Deployment {
    [CmdletBinding()]
    param()

    Write-LogInfo "Verifying deployment..."

    # Wait for containers to be ready
    Start-Sleep -Seconds 10

    try {
        # Check container status
        $containerStatus = Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile ps --services --filter 'status=running' | wc -l" -PassThru
        $totalContainers = Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile ps --services | wc -l" -PassThru

        $runningCount = [int]$containerStatus.Trim()
        $totalCount = [int]$totalContainers.Trim()

        if ($runningCount -eq $totalCount) {
            Write-LogSuccess "All containers are running ($runningCount/$totalCount)"
        }
        else {
            Write-LogError "Some containers are not running ($runningCount/$totalCount)"
            Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile ps"
            throw "Container verification failed"
        }

        # Test HTTPS accessibility
        Write-LogInfo "Testing HTTPS accessibility..."

        $endpoints = @(
            "https://app.cloudtolocalllm.online",
            "https://cloudtolocalllm.online/downloads.html"
        )

        foreach ($endpoint in $endpoints) {
            try {
                if ($script:SSHMethod -eq "WSL") {
                    Invoke-WSLCommand -DistroName $script:LinuxDistro -Command "curl -I -s -f $endpoint > /dev/null"
                }
                else {
                    # Use PowerShell's Invoke-WebRequest for Windows
                    $response = Invoke-WebRequest -Uri $endpoint -Method Head -UseBasicParsing -TimeoutSec 10
                    if ($response.StatusCode -ne 200) {
                        throw "HTTP $($response.StatusCode)"
                    }
                }
                Write-LogSuccess "$endpoint is accessible"
            }
            catch {
                Write-LogError "$endpoint is not accessible: $($_.Exception.Message)"
                throw "Endpoint verification failed"
            }
        }

        Write-LogSuccess "Deployment verification passed"
    }
    catch {
        Write-LogError "Deployment verification failed: $($_.Exception.Message)"
        exit 1
    }
}

# Show deployment summary
function Show-DeploymentSummary {
    [CmdletBinding()]
    param()

    Write-LogInfo "Deployment Summary"
    Write-Host "===================="
    Write-Host "VPS Host: $VPSHost"
    Write-Host "Project Directory: $ProjectDir"
    Write-Host "Compose File: $ComposeFile"
    Write-Host "Deployment Time: $(Get-Date)"
    Write-Host ""

    Write-Host "Container Status:" -ForegroundColor Yellow
    try {
        Invoke-SSHCommand -Command "cd $ProjectDir && docker-compose -f $ComposeFile ps"
    }
    catch {
        Write-LogWarning "Could not retrieve container status"
    }

    Write-Host ""
    Write-Host "Available Endpoints:" -ForegroundColor Yellow
    Write-Host "  - Homepage: https://cloudtolocalllm.online"
    Write-Host "  - Web App: https://app.cloudtolocalllm.online"
    Write-Host "  - Downloads: https://cloudtolocalllm.online/downloads.html"
    Write-Host ""
    Write-Host "Logs:" -ForegroundColor Yellow
    Write-Host "  ssh $VPSUser@$VPSHost 'cd $ProjectDir && docker-compose -f $ComposeFile logs -f'"
    Write-Host ""
}

# Main deployment function
function Invoke-Main {
    [CmdletBinding()]
    param()

    Write-Host "CloudToLocalLLM VPS Deployment Script (PowerShell)" -ForegroundColor Blue
    Write-Host "==================================================" -ForegroundColor Blue
    Write-Host "Target: $VPSUser@$VPSHost"
    Write-Host "Project: $ProjectDir"
    Write-Host "SSH Method: $($script:SSHMethod)"
    Write-Host ""

    # Pre-deployment checks
    Test-Prerequisites
    Test-VPSConnectivity
    Test-VPSEnvironment

    # Create backup
    New-Backup

    # Deploy
    Update-GitRepository
    Update-FlutterEnvironment
    Build-FlutterWeb
    Stop-Containers
    Start-Containers

    # Verify
    Test-Deployment

    # Summary
    Show-DeploymentSummary

    Write-LogSuccess "CloudToLocalLLM deployment completed successfully!"
}

# Error handling
trap {
    Write-LogError "Script failed: $($_.Exception.Message)"
    Write-LogError "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

# Execute main function
Invoke-Main
