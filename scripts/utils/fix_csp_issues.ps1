param (
    [Parameter(Mandatory=$true)]
    [string]$VpsHost,
    
    [Parameter(Mandatory=$false)]
    [string]$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
)

# Convert the fix scripts to Unix line endings
$fixScript = Get-Content -Path "fix_index_local_resources.sh" -Raw
$fixScript = $fixScript -replace "`r`n", "`n"
$fixScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $fixScriptPath -Value $fixScript -NoNewline -Encoding utf8

$verifyScript = Get-Content -Path "verify_local_resources.sh" -Raw
$verifyScript = $verifyScript -replace "`r`n", "`n"
$verifyScriptPath = [System.IO.Path]::GetTempFileName()
Set-Content -Path $verifyScriptPath -Value $verifyScript -NoNewline -Encoding utf8

# Display info to the user
Write-Host "Uploading and running CSP fix scripts on $VpsHost"

# Upload and run the scripts on the VPS
Write-Host "Uploading scripts to VPS..."
scp -i $SshKeyPath $fixScriptPath "root@${VpsHost}:/tmp/fix_csp.sh"
scp -i $SshKeyPath $verifyScriptPath "root@${VpsHost}:/tmp/verify_resources.sh"
ssh -i $SshKeyPath "root@${VpsHost}" "chmod +x /tmp/fix_csp.sh /tmp/verify_resources.sh"

Write-Host "Verifying local resources..."
ssh -i $SshKeyPath "root@${VpsHost}" "/tmp/verify_resources.sh"

Write-Host "Running CSP fix script..."
ssh -i $SshKeyPath "root@${VpsHost}" "/tmp/fix_csp.sh"

# Restart Nginx
Write-Host "Restarting Nginx..."
ssh -i $SshKeyPath "root@${VpsHost}" "systemctl restart nginx"

# Clean up
Remove-Item -Force $fixScriptPath, $verifyScriptPath
Write-Host "Script execution completed."
Write-Host "Please clear your browser cache and check the website for any remaining CSP errors." 