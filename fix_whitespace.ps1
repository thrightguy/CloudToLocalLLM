$content = Get-Content 'scripts\powershell\Upload-GitHubReleaseAssets.ps1'
$content | ForEach-Object { $_.TrimEnd() } | Set-Content 'scripts\powershell\Upload-GitHubReleaseAssets.ps1'

$content = Get-Content 'scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1'
$content | ForEach-Object { $_.TrimEnd() } | Set-Content 'scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1'
