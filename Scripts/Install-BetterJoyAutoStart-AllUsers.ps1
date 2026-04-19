param(
    [string]$BetterJoyExePath = "",
    [string]$InstallRoot = "$env:ProgramData\BetterJoy",
    [bool]$StartInTray = $true,
    [int]$StartupDelaySeconds = 15
)

$ErrorActionPreference = "Stop"

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell session (Run as Administrator)."
}

if ([string]::IsNullOrWhiteSpace($BetterJoyExePath)) {
    $defaultPath = Join-Path $PSScriptRoot "..\BetterJoyForCemu\bin\x64\Release\BetterJoyForCemu.exe"
    $resolvedDefault = Resolve-Path -Path $defaultPath -ErrorAction SilentlyContinue
    if ($resolvedDefault) {
        $BetterJoyExePath = $resolvedDefault.Path
    }
}

if ([string]::IsNullOrWhiteSpace($BetterJoyExePath)) {
    throw "Provide -BetterJoyExePath to BetterJoyForCemu.exe."
}

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -Path (Join-Path $scriptRoot "..")

$pathCandidates = New-Object System.Collections.Generic.List[string]
$pathCandidates.Add($BetterJoyExePath)

if (-not [System.IO.Path]::IsPathRooted($BetterJoyExePath)) {
    $pathCandidates.Add((Join-Path $repoRoot.Path $BetterJoyExePath))
    $pathCandidates.Add((Join-Path $scriptRoot $BetterJoyExePath))
}

$resolvedExe = $null
foreach ($candidate in $pathCandidates) {
    $probe = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
    if ($probe) {
        $resolvedExe = $probe
        break
    }
}

if (-not $resolvedExe) {
    throw "Could not find BetterJoy executable. Tried: $($pathCandidates -join '; ')"
}

$exePath = $resolvedExe.Path

if (-not (Test-Path -Path $exePath -PathType Leaf)) {
    throw "Executable not found: $exePath"
}

$sourceDir = Split-Path -Parent $exePath
$installDir = Join-Path $InstallRoot "Current"
New-Item -Path $installDir -ItemType Directory -Force | Out-Null

# Stop a running instance to avoid partially overwritten binaries.
Get-Process BetterJoyForCemu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Copy-Item -Path (Join-Path $sourceDir "*") -Destination $installDir -Recurse -Force

$deployedExe = Join-Path $installDir "BetterJoyForCemu.exe"
if (-not (Test-Path -Path $deployedExe -PathType Leaf)) {
    throw "Deployment failed. Expected executable at: $deployedExe"
}

$taskName = "BetterJoy AutoStart (All Users)"
$taskPath = "\BetterJoy\"

$taskArgs = ""
if ($StartInTray) {
    $taskArgs = "--tray"
}

$action = New-ScheduledTaskAction -Execute $deployedExe -Argument $taskArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

if ($StartupDelaySeconds -gt 0) {
    $trigger.Delay = "PT${StartupDelaySeconds}S"
}

try {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop | Out-Null
} catch { }

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Starts BetterJoy at logon for any local user session." -ErrorAction Stop | Out-Null

Write-Host "Deployed BetterJoy to: $installDir"
Write-Host "Installed scheduled task '$taskPath$taskName' using executable: $deployedExe"
