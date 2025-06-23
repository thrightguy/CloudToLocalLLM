# Fix line endings and BOM for bash scripts
param(
    [string]$ScriptPath
)

if (Test-Path $ScriptPath) {
    # Read as bytes to handle BOM properly
    $bytes = [System.IO.File]::ReadAllBytes($ScriptPath)

    # Remove BOM if present (UTF-8 BOM is EF BB BF)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length - 1)]
        Write-Host "Removed BOM from: $ScriptPath"
    }

    # Convert to string and fix line endings
    $content = [System.Text.Encoding]::UTF8.GetString($bytes)
    $content = $content -replace "`r`n", "`n"
    $content = $content -replace "`r", "`n"

    # Write back without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ScriptPath, $content, $utf8NoBom)
    Write-Host "Fixed line endings for: $ScriptPath"
} else {
    Write-Host "File not found: $ScriptPath"
}
