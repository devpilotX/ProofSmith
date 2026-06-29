# Background setup: resolve mathlib, fetch olean cache, build.
# Runs detached. Writes progress to _bg_setup.log and a final
# _bg_setup.done flag with the build exit code. Poll with status.ps1.
$ErrorActionPreference = 'Continue'
$proj = 'C:\Projects\Kiro\ProofSmith'
$log  = Join-Path $proj '_bg_setup.log'
$flag = Join-Path $proj '_bg_setup.done'
Remove-Item $log, $flag -ErrorAction SilentlyContinue
$env:Path = "$env:USERPROFILE\.elan\bin;" + $env:Path
Set-Location $proj

function Log($m) {
  ("[" + (Get-Date -Format 'HH:mm:ss') + "] " + $m) | Out-File -FilePath $log -Append
}

Log "STEP elan show (triggers toolchain install for v4.31.0)"
elan show *>> $log
Log "elan show exit=$LASTEXITCODE"

Log "STEP lake update"
lake update *>> $log
Log "lake update exit=$LASTEXITCODE"

Log "STEP lake exe cache get"
lake exe cache get *>> $log
Log "cache get exit=$LASTEXITCODE"

Log "STEP lake build"
lake build *>> $log
$build = $LASTEXITCODE
Log "lake build exit=$build"

"EXIT:$build" | Out-File -FilePath $flag
Log "ALL DONE flag written"
