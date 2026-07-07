param([Parameter(Mandatory=$true)][string]$Tag)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Projects\Kiro\VaultVerify'
$log  = Join-Path $proj ("_bg_$Tag.log")
$flag = Join-Path $proj ("_bg_$Tag.done")
$cmdf = Join-Path $proj ("_bg_$Tag.cmd")
Remove-Item $log, $flag -ErrorAction SilentlyContinue
$env:Path = "$env:USERPROFILE\.foundry\bin;" + $env:Path
Set-Location $proj
$Cmd = (Get-Content $cmdf -Raw).Trim()
("[" + (Get-Date -Format 'HH:mm:ss') + "] " + $Cmd) | Out-File $log -Append
Invoke-Expression $Cmd *>> $log 2>&1
$code = $LASTEXITCODE
("[" + (Get-Date -Format 'HH:mm:ss') + "] exit=" + $code) | Out-File $log -Append
"EXIT:$code" | Out-File $flag
