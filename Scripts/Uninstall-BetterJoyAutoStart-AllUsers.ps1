$ErrorActionPreference = "Stop"

$taskName = "BetterJoy AutoStart (All Users)"
$taskPath = "\BetterJoy\"

Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Write-Host "Removed scheduled task '$taskPath$taskName' (if it existed)."
