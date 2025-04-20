# PowerShell script to initialize a Git repository, add, commit, and push to a GitHub repository
$ErrorActionPreference = "Stop"

# Define the repository URL
$repoUrl = "https://github.com/thrightguy/CloudToLocalLLM.git"
$remoteName = "origin"
$branchName = "main"  # Default branch; GitHub typically uses 'main' for new repos

# Function to log messages
function Log-Message {
    param ($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Write-Host "$timestamp - $Message"
}

# Check if Git is installed
Log-Message "Checking if Git is installed..."
try {
    git --version | Out-Null
    Log-Message "Git is installed."
} catch {
    Log-Message "ERROR: Git is not installed. Please install Git and try again."
    exit 1
}

# Check if the current directory is a Git repository, and initialize if not
Log-Message "Checking if the current directory is a Git repository..."
if (-not (Test-Path ".git")) {
    Log-Message "No Git repository found. Initializing a new Git repository..."
    try {
        git init
        Log-Message "Git repository initialized successfully."
    } catch {
        Log-Message "ERROR: Failed to initialize Git repository. $_"
        exit 1
    }
} else {
    Log-Message "Git repository already exists."
}

# Check if the remote repository is already set
Log-Message "Setting up remote '$remoteName'..."
$remoteExists = $false
$currentRemoteUrl = $null
try {
    $remoteOutput = git remote -v
    foreach ($line in $remoteOutput) {
        if ($line -match "^$remoteName\s+(.+)\s+\(fetch\)") {
            $remoteExists = $true
            $currentRemoteUrl = $matches[1]
            break
        }
    }
} catch {
    Log-Message "No remote found. Will add a new remote."
}

if ($remoteExists) {
    if ($currentRemoteUrl -ne $repoUrl) {
        Log-Message "Remote '$remoteName' is currently set to $currentRemoteUrl, but the script expects $repoUrl."
        Log-Message "Updating remote URL..."
        git remote set-url $remoteName $repoUrl
    } else {
        Log-Message "Remote '$remoteName' is already set to $repoUrl."
    }
} else {
    Log-Message "Remote '$remoteName' not found. Adding remote..."
    git remote add $remoteName $repoUrl
}

# Set the default branch to main
Log-Message "Setting the default branch to $branchName..."
try {
    git branch -M $branchName
} catch {
    Log-Message "ERROR: Failed to set the default branch to $branchName. $_"
    exit 1
}

# Check for changes
Log-Message "Checking for changes to commit..."
if (-not (git status --porcelain)) {
    Log-Message "No changes to commit. Please add files to the repository."
    exit 0
}

# Prompt for commit message
$commitMessage = Read-Host "Enter your commit message (e.g., 'Initial commit')"
if (-not $commitMessage) {
    $commitMessage = "Initial commit"
    Log-Message "No commit message provided. Using default: 'Initial commit'"
}

# Add all changes
Log-Message "Adding all changes..."
git add .

# Commit changes
Log-Message "Committing changes with message: $commitMessage"
try {
    git commit -m $commitMessage
} catch {
    Log-Message "ERROR: Failed to commit changes. $_"
    exit 1
}

# Push to the remote repository
Log-Message "Pushing changes to $remoteName $branchName..."
try {
    git push -u $remoteName $branchName
    Log-Message "Successfully pushed changes to $repoUrl"
} catch {
    Log-Message "ERROR: Failed to push changes. $_"
    Log-Message "Possible issues: Authentication failure, network error, or the repository may not exist on GitHub."
    Log-Message "Ensure you have created the repository at $repoUrl and have the correct permissions."
    exit 1
}

Log-Message "Git push completed successfully."