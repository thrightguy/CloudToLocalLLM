# Fix SSH config BOM issue
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
if (Test-Path $sshConfigPath) {
    $content = Get-Content $sshConfigPath -Raw
    $content = $content -replace '^\uFEFF', ''
    $content | Out-File $sshConfigPath -Encoding UTF8 -NoNewline
    Write-Host "Fixed SSH config BOM issue"
} else {
    Write-Host "SSH config file not found"
}
