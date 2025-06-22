# Upload assets to GitHub release v3.6.4
param(
    [string]$GitHubToken
)

$releaseId = "226900018"
$owner = "imrightguy"
$repo = "CloudToLocalLLM"

# Files to upload
$files = @(
    @{
        Path = "cloudtolocalllm-3.6.4-portable.zip"
        Name = "cloudtolocalllm-3.6.4-portable.zip"
        ContentType = "application/zip"
    },
    @{
        Path = "debian\cloudtolocalllm_3.6.4_amd64.deb"
        Name = "cloudtolocalllm_3.6.4_amd64.deb"
        ContentType = "application/vnd.debian.binary-package"
    },
    @{
        Path = "cloudtolocalllm-3.6.4-x86_64.AppImage"
        Name = "cloudtolocalllm-3.6.4-x86_64.AppImage"
        ContentType = "application/octet-stream"
    }
)

foreach ($file in $files) {
    if (Test-Path $file.Path) {
        Write-Host "Uploading $($file.Name)..." -ForegroundColor Green
        
        $uploadUrl = "https://uploads.github.com/repos/$owner/$repo/releases/$releaseId/assets?name=$($file.Name)"
        
        try {
            $headers = @{
                "Authorization" = "token $GitHubToken"
                "Content-Type" = $file.ContentType
            }
            
            $fileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $file.Path))
            
            $response = Invoke-RestMethod -Uri $uploadUrl -Method POST -Headers $headers -Body $fileBytes
            Write-Host "Successfully uploaded $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to upload $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "File not found: $($file.Path)" -ForegroundColor Yellow
    }
}
