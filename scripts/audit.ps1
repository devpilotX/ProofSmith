# Background axiom audit. Runs lean on the audit file, capturing
# #print axioms output. Writes _bg_audit.log and _bg_audit.done.
$ErrorActionPreference = 'Continue'
$proj = 'C:\Projects\Kiro\ProofSmith'
$log  = Join-Path $proj '_bg_audit.log'
$flag = Join-Path $proj '_bg_audit.done'
Remove-Item $log, $flag -ErrorAction SilentlyContinue
$env:Path = "$env:USERPROFILE\.elan\bin;" + $env:Path
Set-Location $proj
lake env lean ProofSmith/Audit.lean *>> $log
"EXIT:$LASTEXITCODE" | Out-File $flag
