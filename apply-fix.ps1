<#
    apply-fix.ps1
    Fixes the washed-out / overly bright mouse cursor caused by the NVIDIA
    hardware cursor color bug.

    Sets HKCU\Control Panel\Mouse -> MouseTrails = -1, which forces Windows to
    draw the cursor in SOFTWARE (composited by the DWM) instead of using the
    broken hardware cursor plane.

    -1 is outside the documented range (0, 2-7) but tested: it forces software
    rendering WITHOUT drawing a visible trail. Values 2-7 also work but leave a
    visible tail behind the cursor.

    Applies live - no reboot, no need to close the game. Persists across reboots.
    No process stays running.
#>

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class SpiTrails {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
"@

$SPI_SETMOUSETRAILS = [uint32]0x005D
$SPIF_UPDATE_AND_NOTIFY = [uint32]3      # SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
$VALUE_SOFTWARE_NO_TRAIL = [uint32]4294967295   # -1 as uint32

$key = 'HKCU:\Control Panel\Mouse'
$before = (Get-ItemProperty $key -Name MouseTrails -ErrorAction SilentlyContinue).MouseTrails
Write-Host "MouseTrails before : '$before'"

# The API rejects the raw value on some builds, so write the registry first...
Set-ItemProperty -Path $key -Name MouseTrails -Value '-1'

# ...then tell Windows to re-read it and apply immediately.
$ok = [SpiTrails]::SystemParametersInfo($SPI_SETMOUSETRAILS, $VALUE_SOFTWARE_NO_TRAIL, [IntPtr]::Zero, $SPIF_UPDATE_AND_NOTIFY)
Start-Sleep -Milliseconds 400

$after = (Get-ItemProperty $key -Name MouseTrails).MouseTrails
Write-Host "SystemParametersInfo : $ok"
Write-Host "MouseTrails after  : '$after'"

if ($after -eq '-1') {
    Write-Host ""
    Write-Host "DONE. The cursor is now software-rendered." -ForegroundColor Green
    Write-Host "Move the mouse over your game - the color should be correct and there should be no trail."
    Write-Host "Run revert-fix.ps1 to undo."
} else {
    Write-Host ""
    Write-Host "FAILED - MouseTrails is '$after', expected '-1'." -ForegroundColor Red
    exit 1
}
