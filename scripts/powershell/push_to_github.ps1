# PowerShell script to push all changes to GitHub
param(
    [string]$Message = "Update admin-ui and dependencies"
)

Write-Host "Checking for git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is not installed. Please install Git for Windows."
    exit 1
}

Write-Host "Adding all changes..."
git add .
Write-Host "Committing..."
git commit -m "$Message"
Write-Host "Pushing to GitHub..."
git push origin master
Write-Host "Push complete." 