<#
.SYNOPSIS
  Reversible, driver-level keyboard remap: make the remote's mic key look like a REAL Right Alt.

.DESCRIPTION
  Modern IMEs ignore synthetic keystrokes (LLKHF_INJECTED), but a scancode remap is applied by the
  keyboard class driver, so the resulting keystroke looks physical. This script writes:

    HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout  ->  Scancode Map  (REG_BINARY, 20 bytes)

    00 00 00 00 | 00 00 00 00 | 02 00 00 00 | 38 E0 3F 00 | 00 00 00 00
     version      flags         entries       F5->RAlt      terminator
                                            (new E0 38, old 3F 00)

  It backs up the whole key first and verifies the bytes after writing.
  Takes effect after a REBOOT.

  Side effect: your normal keyboard's F5 becomes Right Alt as well (use Ctrl+R to refresh browsers).

.PARAMETER Rollback
  Remove the Scancode Map value (then reboot) to restore the original keyboard behaviour.

.PARAMETER BackupDir
  Where to store the .reg backup. Defaults to this script's folder.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\apply-scancode-map.ps1
  powershell -ExecutionPolicy Bypass -File .\apply-scancode-map.ps1 -Rollback
#>
[CmdletBinding()]
param(
    [switch]$Rollback,
    [string]$BackupDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$keyPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
$valueName = 'Scancode Map'
# F5 (scan code 0x3F) -> extended Right Alt (0x38 with E0 prefix)
$mapBytes = [byte[]](0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0x38, 0xE0, 0x3F, 0x00, 0, 0, 0, 0)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error 'Administrator rights are required. Open an elevated PowerShell/terminal and run this again.'
    exit 1
}

function Show-Current {
    $cur = (Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue).$valueName
    if ($null -eq $cur) {
        Write-Host 'Current Scancode Map : (none)'
    }
    else {
        Write-Host ('Current Scancode Map : ' + (($cur | ForEach-Object { $_.ToString('X2') }) -join ' '))
    }
}

if ($Rollback) {
    if (Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $keyPath -Name $valueName -Force
        Write-Host 'Scancode Map removed. REBOOT to get your normal F5 back.'
    }
    else {
        Write-Host 'Nothing to roll back: there is no Scancode Map value.'
    }
    Show-Current
    exit 0
}

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupFile = Join-Path $BackupDir ("keyboard-layout-backup-$stamp.reg")
reg export 'HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout' "$backupFile" /y | Out-Null
Write-Host "Backup written       : $backupFile"
Show-Current

New-ItemProperty -Path $keyPath -Name $valueName -PropertyType Binary -Value $mapBytes -Force | Out-Null

$after = (Get-ItemProperty -Path $keyPath -Name $valueName).$valueName
$diff = Compare-Object -ReferenceObject $mapBytes -DifferenceObject $after
if ($null -ne $diff -or $after.Length -ne $mapBytes.Length) {
    Write-Error 'Verification failed: the value on disk does not match the intended mapping.'
    exit 1
}
Write-Host ('Written and verified : ' + (($after | ForEach-Object { $_.ToString('X2') }) -join ' '))
Write-Host ''
Write-Host 'NEXT   : REBOOT. Until you reboot, nothing changes.'
Write-Host 'Effect : remote mic key (F5) wakes the IME as a real Right Alt; your keyboard F5 becomes Right Alt too.'
Write-Host 'Undo   : powershell -ExecutionPolicy Bypass -File .\apply-scancode-map.ps1 -Rollback   (then reboot)'
