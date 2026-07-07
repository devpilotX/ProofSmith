param([Parameter(Mandatory=$true)][string]$Tag, [int]$Tail = 40)
$proj = 'C:\Projects\Kiro\VaultVerify'
$log  = Join-Path $proj ("_bg_$Tag.log")
$flag = Join-Path $proj ("_bg_$Tag.done")
if (Test-Path $flag) { Write-Output ("STATUS: DONE (" + (Get-Content $flag) + ")") }
else { Write-Output "STATUS: RUNNING" }
Write-Output "---- tail of _bg_$Tag.log ----"
if (Test-Path $log) { Get-Content $log -Tail $Tail } else { Write-Output "(no log yet)" }
