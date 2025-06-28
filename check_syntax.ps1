$errors = $null
$tokens = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile('scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1', [ref]$tokens, [ref]$errors)

if ($errors) {
    Write-Host "Syntax errors found:" -ForegroundColor Red
    $errors | ForEach-Object {
        Write-Host "Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "No syntax errors found" -ForegroundColor Green
}
