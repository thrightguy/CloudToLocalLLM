# Fix line endings for bash scripts
param(
    [string]$ScriptPath
)

if (Test-Path $ScriptPath) {
    $content = Get-Content $ScriptPath -Raw
    $content = $content -replace "`r`n", "`n"
    $content = $content -replace "`r", "`n"
    [System.IO.File]::WriteAllText($ScriptPath, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Fixed line endings for: $ScriptPath"
} else {
    Write-Host "File not found: $ScriptPath"
}
