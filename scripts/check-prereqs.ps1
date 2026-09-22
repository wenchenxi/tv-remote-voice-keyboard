<#
.SYNOPSIS
  Check every link of the "TV remote as a voice keyboard" chain and print a short report.

.DESCRIPTION
  Read-only diagnostics. Verifies (in order):
    1. Bluetooth radio
    2. remote paired + its identity (VID_2717 / PID_32B8) + ATVV voice service AB5E0001-...
    3. virtual audio cable endpoints (CABLE Input / CABLE Output)
    4. keyboard remap (Scancode Map value)
    5. bridge process + newest log lines

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\check-prereqs.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$logPath = Join-Path $env:LOCALAPPDATA 'RemoteMic\RC003\logs\app.log'
$exePath = Join-Path $env:LOCALAPPDATA 'RemoteMic\RC003\RemoteMicRC003.exe'

function Section([string]$text) { Write-Host ''; Write-Host ('== ' + $text + ' ' + ('=' * [Math]::Max(0, 50 - $text.Length))) }

Section '1. Bluetooth radio'
$radio = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'USB\*' -or $_.InstanceId -like 'BTH\*' }
if ($radio) { $radio | Select-Object Status, FriendlyName | Format-Table -AutoSize | Out-String -Width 120 | Write-Host }
else { Write-Host '!! No Bluetooth radio found. The remote cannot work without one.' }

Section '2. Remote (VID_2717 / PID_32B8) + ATVV voice service'
$remote = Get-PnpDevice -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -match 'VID_2717|VID&012717' -or $_.FriendlyName -match 'MI RC|Xiaomi|遥控' }
if (-not $remote) {
    Write-Host '!! Remote not found. Pair it first: hold Home + Menu for 3-5 s, then add'
    Write-Host '   "Xiaomi Bluetooth Remote"/"Xiaomi Bluetooth Voice Remote" in Windows Bluetooth settings.'
}
else {
    $remote | Select-Object Status, Class, FriendlyName, InstanceId | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    $atvv = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'AB5E0001' }
    if ($atvv) { Write-Host '[ok] ATVV voice service present - the remote CAN act as a microphone.' }
    else { Write-Host '!! ATVV service (AB5E0001-5A21-4F05-BC7D-AF01F617B664) NOT found - no voice path on this device.' }
}

Section '3. Virtual audio cable endpoints'
$cable = Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'CABLE' }
if ($cable) { $cable | Select-Object Status, FriendlyName | Format-Table -AutoSize | Out-String -Width 120 | Write-Host }
else { Write-Host '!! No CABLE endpoints. Install VB-CABLE (official package) and reboot.' }

Section '4. Driver-level keyboard remap (Scancode Map)'
$map = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout' -Name 'Scancode Map' -ErrorAction SilentlyContinue).'Scancode Map'
if ($null -eq $map) { Write-Host '(none) - bridge-injected Right Alt will be IGNORED by most IMEs. Run apply-scancode-map.ps1.' }
else { Write-Host ('bytes: ' + (($map | ForEach-Object { $_.ToString('X2') }) -join ' ')) }

Section '5. Bridge process and log'
$proc = Get-Process RemoteMicRC003 -ErrorAction SilentlyContinue
if ($proc) { Write-Host ('[ok] RemoteMicRC003 running, pid ' + $proc.Id + ', started ' + $proc.StartTime) }
else { Write-Host '!! Bridge is NOT running. Start it with:  cmd /c start "" "' + $exePath + '" --bridge' }

if (Test-Path $logPath) {
    Write-Host ('log: ' + $logPath)
    Get-Content $logPath -Tail 6 | ForEach-Object { Write-Host ('   ' + $_) }
    $signal = Select-String -Path $logPath -Pattern 'result=signal' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($signal) { Write-Host ('[ok] last voice session captured real audio: ' + $signal.Line.Trim()) }
    else { Write-Host '(i) no successful voice session logged yet - hold the mic key and say something.' }
}
else { Write-Host '!! No log file yet - the bridge has never started.' }

Section 'Done'
Write-Host 'Reminder: the system default RECORDING device should be "CABLE Output" while you dictate.'
