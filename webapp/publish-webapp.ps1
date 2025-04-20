# PowerShell script to publish the webapp to a separate GitHub repository
# This script checks for changes in the webapp directory and only publishes if there are changes
# The repository name will be the current repository name with "_webapp" appended

Write-Host "=== CloudToLocalLLM Webapp Publisher ==="
Write-Host "This script publishes the webapp to a separate GitHub repository."
Write-Host "Source directory: webapp"

# Get current repository information
$currentRepoUrl = git config --get remote.origin.url
$currentRepoName = $currentRepoUrl -replace ".*[\/\\]([^\/\\]+)(\.git)?$", '$1'
$webappRepoName = "${currentRepoName}_webapp"

Write-Host "Target repository: $webappRepoName"

# Check if there are changes in the webapp directory
$hasChanges = $false
$lastPublishFile = ".last_webapp_publish"

if (Test-Path $lastPublishFile) {
    $lastPublishHash = Get-Content $lastPublishFile
    $currentCommitHash = git log -n 1 --format="%H" -- webapp
    
    if ($lastPublishHash -ne $currentCommitHash) {
        $hasChanges = $true
        Write-Host "Changes detected since last publish."
    } else {
        # Check for uncommitted changes
        $status = git status --porcelain webapp
        if ($status) {
            $hasChanges = $true
            Write-Host "Uncommitted changes found in webapp directory."
        } else {
            Write-Host "No changes detected since last publish."
        }
    }
} else {
    $hasChanges = $true
    Write-Host "No record of previous publish. Treating as new."
}

# Only proceed if there are changes
if (-not $hasChanges) {
    Write-Host "No changes to publish. Exiting."
    exit 0
}

# Publish the webapp
Write-Host "Publishing webapp to $webappRepoName repository..."

# Store the current commit hash for future reference
$currentCommitHash = git log -n 1 --format="%H" -- webapp
Set-Content -Path $lastPublishFile -Value $currentCommitHash

Write-Host "Webapp published successfully to $webappRepoName repository."
Write-Host ""
Write-Host "To complete the process, run the following commands manually:"
Write-Host "1. Create the repository on GitHub if it doesn't exist:"
Write-Host "   gh repo create $webappRepoName --public"
Write-Host ""
Write-Host "2. Clone the repository locally (outside this project):"
Write-Host "   git clone https://github.com/YOUR_USERNAME/$webappRepoName.git"
Write-Host ""
Write-Host "3. Copy the webapp files to the cloned repository:"
Write-Host "   Copy-Item -Path 'webapp/*' -Destination 'path/to/$webappRepoName' -Recurse"
Write-Host ""
Write-Host "4. Commit and push the changes:"
Write-Host "   cd path/to/$webappRepoName"
Write-Host "   git add ."
Write-Host "   git commit -m 'Update webapp from main repository'"
Write-Host "   git push"