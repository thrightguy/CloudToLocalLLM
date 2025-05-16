# CloudToLocalLLM - Script Organization
# This script moves PowerShell scripts from the root directory to appropriate subfolders

# Script categories
$buildScripts = @(
    "build.ps1",
    "build_android.ps1",
    "build_windows_admin_installer.ps1", 
    "build_windows_with_license.ps1",
    "prepare_cloud_build.ps1"
)

$deployScripts = @(
    "deploy_auth0_login_update.ps1",
    "deploy_cloud_app.ps1",
    "deploy_simple_web.ps1",
    "deploy_ssl_fix.ps1",
    "deploy_to_vps.ps1",
    "deploy_vps_powershell.ps1",
    "deploy-cloudtolocalllm.ps1",
    "containers_setup.ps1",
    "docker_only_setup.ps1",
    "docker_web_only_setup.ps1",
    "fix_container_setup.ps1",
    "fix_web_deployment.ps1",
    "setup_beta_environment.ps1",
    "setup_ssl.ps1"
)

$auth0Scripts = @(
    "auth0_integration.ps1",
    "auth0_main.ps1",
    "direct_vps_auth0_fix.ps1",
    "fix_api_login.ps1",
    "fix_ssl_and_add_auth.ps1",
    "revert_auth0_changes.ps1",
    "vps_auth0_fix_local.ps1",
    "vps_auth0_fix_simple.ps1"
)

$releaseScripts = @(
    "clean_releases.ps1",
    "check_for_updates.ps1"
)

$utilScripts = @(
    "add_construction_notice.ps1",
    "clean_setup_ssl.ps1",
    "fix_csp_issues.ps1",
    "fix_nginx_config.ps1",
    "fix_npm_install.ps1",
    "fix_ssl_issues.ps1",
    "Setup-Ollama.ps1",
    "update_platform_info.ps1",
    "wildcard_ssl_setup.ps1"
)

# Function to move scripts to folders
function Move-Scripts {
    param (
        [string[]]$ScriptList,
        [string]$TargetFolder
    )

    $fullTargetDirPath = Join-Path -Path $PSScriptRoot -ChildPath $TargetFolder
    if (-not (Test-Path $fullTargetDirPath)) {
        Write-Host "Creating target directory: $fullTargetDirPath" -ForegroundColor DarkYellow
        try {
            New-Item -ItemType Directory -Path $fullTargetDirPath -Force -ErrorAction Stop | Out-Null
            Write-Host "Successfully created directory: $fullTargetDirPath" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to create directory $fullTargetDirPath. $_" -ForegroundColor Red
            # Decide if script should exit or continue trying to move other categories
            # For now, let it continue to other categories, but this specific one might fail.
            return # Skip trying to move files to a folder that couldn't be created
        }
    }

    foreach ($script in $ScriptList) {
        $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "..\$script"
        # Target path should use the validated/created $fullTargetDirPath
        $targetPath = Join-Path -Path $fullTargetDirPath -ChildPath $script 
        
        if (Test-Path $sourcePath) {
            Write-Host "Moving $script from $($sourcePath) to $targetPath..." -ForegroundColor Cyan
            try {
                Move-Item -Path $sourcePath -Destination $targetPath -Force -ErrorAction Stop
                Write-Host "Successfully moved $script to $TargetFolder" -ForegroundColor Green
            } catch {
                Write-Host "ERROR: Failed to move $script to $TargetFolder. $_" -ForegroundColor Red
            }
        } else {
            Write-Host "Script $script not found in root directory. Skipping." -ForegroundColor Yellow
        }
    }
}

# Main process
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "CloudToLocalLLM - Organizing Scripts" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Move scripts to appropriate folders
Write-Host "`nMoving build scripts..." -ForegroundColor Green
Move-Scripts -ScriptList $buildScripts -TargetFolder "build"

Write-Host "`nMoving deployment scripts..." -ForegroundColor Green
Move-Scripts -ScriptList $deployScripts -TargetFolder "deploy"

Write-Host "`nMoving Auth0 integration scripts..." -ForegroundColor Green
Move-Scripts -ScriptList $auth0Scripts -TargetFolder "auth0"

Write-Host "`nMoving release management scripts..." -ForegroundColor Green
Move-Scripts -ScriptList $releaseScripts -TargetFolder "release"

Write-Host "`nMoving utility scripts..." -ForegroundColor Green
Move-Scripts -ScriptList $utilScripts -TargetFolder "utils"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Script organization complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan 