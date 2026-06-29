# Background build of a lake target. Usage: build.ps1 [-Target name]
param([string]$Target = 'ProofSmith')
$ErrorActionPreference = 'Continue'
$proj = 'C:\Projects\Kiro\ProofSmith'
$log  = Join-Path $proj '_bg_build.log'
$flag = Join-Path $proj '_bg_build.done'
Remove-Item $log, $flag -ErrorAction SilentlyContinue
$env:Path = "$env:USERPROFILE\.elan\bin;" + $env:Path
Set-Location $proj
("[" + (Get-Date -Format 'HH:mm:ss') + "] lake build " + $Target) | Out-File $log -Append
lake build $Target *>> $log
$code = $LASTEXITCODE
("[" + (Get-Date -Format 'HH:mm:ss') + "] build exit=" + $code) | Out-File $log -Append
"EXIT:$code" | Out-File $flag
