<#
    revert-fix.ps1
    Undoes apply-fix.ps1: turns pointer trails off and gives the hardware
    cursor back.

    WARNING: if your driver still has the hardware cursor color bug, the
    washed-out cursor WILL come back after running this.
#>

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class SpiTrailsOff {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
"@

$key = 'HKCU:\Control Panel\Mouse'
$before = (Get-ItemProperty $key -Name MouseTrails -ErrorAction SilentlyContinue).MouseTrails
Write-Host "MouseTrails before : '$before'"

Set-ItemProperty -Path $key -Name MouseTrails -Value '0'
$ok = [SpiTrailsOff]::SystemParametersInfo([uint32]0x005D, [uint32]0, [IntPtr]::Zero, [uint32]3)
Start-Sleep -Milliseconds 400

$after = (Get-ItemProperty $key -Name MouseTrails).MouseTrails
Write-Host "SystemParametersInfo : $ok"
Write-Host "MouseTrails after  : '$after'"
Write-Host ""
Write-Host "Reverted to the hardware cursor. The bug may return." -ForegroundColor Yellow
