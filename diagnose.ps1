<#
    diagnose.ps1
    Collects every measurement that mattered while tracking down the
    washed-out cursor bug. Run this first if the problem comes back, and
    compare against the values documented in README.md.

    Read-only: this script changes nothing.
#>

$ErrorActionPreference = 'SilentlyContinue'

function Section($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }

Section "1. THE FIX - is it applied?"
$mt = (Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseTrails).MouseTrails
$verdict = switch ($mt) {
    '-1'    { "software cursor, no trail  <-- THE FIX" }
    '0'     { "OFF - hardware cursor, bug can appear" }
    default { "software cursor WITH a visible trail (value $mt)" }
}
Write-Host "  MouseTrails = '$mt'  ->  $verdict"

Section "2. GPU and driver"
Get-CimInstance Win32_VideoController | ForEach-Object {
    Write-Host "  $($_.Name)"
    Write-Host "    driver  : $($_.DriverVersion)   ($($_.DriverDate))"
    Write-Host "    mode    : $($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate)Hz, $($_.CurrentBitsPerPixel)bpp"
}
Write-Host "  NOTE: driver 32.0.16.1074 = NVIDIA 610.74, which HAS the bug. 581.80 is reported clean."

Section "3. Output color depth / HDR per display  (10bpc+SDR was a suspect - it was not the cause)"
$code = @"
using System;
using System.Runtime.InteropServices;
public class DiagColor {
  [StructLayout(LayoutKind.Sequential)] public struct LUID { public uint Low; public int High; }
  [StructLayout(LayoutKind.Sequential)] public struct RATIONAL { public uint Num; public uint Den; }
  [StructLayout(LayoutKind.Sequential)] public struct SRC { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags; }
  [StructLayout(LayoutKind.Sequential)] public struct TGT { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint outputTechnology; public uint rotation; public uint scaling; public RATIONAL refreshRate; public uint scanLineOrdering; public int targetAvailable; public uint statusFlags; }
  [StructLayout(LayoutKind.Sequential)] public struct PATH { public SRC src; public TGT tgt; public uint flags; }
  [StructLayout(LayoutKind.Sequential, Size=64)] public struct MODE { public uint infoType; public uint id; public LUID adapterId; }
  [StructLayout(LayoutKind.Sequential)] public struct HDR { public uint type; public uint size; public LUID adapterId; public uint id; }
  [StructLayout(LayoutKind.Sequential)] public struct ADVCOLOR { public HDR header; public uint value; public uint colorEncoding; public uint bitsPerColorChannel; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct TGTNAME { public HDR header; public uint flags; public uint outputTechnology; public ushort edidMfg; public ushort edidProd; public uint connectorInstance; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string name; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string path; }
  [DllImport("user32.dll")] public static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPaths, out uint numModes);
  [DllImport("user32.dll")] public static extern int QueryDisplayConfig(uint flags, ref uint numPaths, [Out] PATH[] paths, ref uint numModes, [Out] MODE[] modes, IntPtr cur);
  [DllImport("user32.dll", EntryPoint="DisplayConfigGetDeviceInfo")] public static extern int GetAdvColor(ref ADVCOLOR req);
  [DllImport("user32.dll", EntryPoint="DisplayConfigGetDeviceInfo")] public static extern int GetTgtName(ref TGTNAME req);
  public static string Read() {
    uint np = 0, nm = 0;
    GetDisplayConfigBufferSizes(2, out np, out nm);
    PATH[] paths = new PATH[np]; MODE[] modes = new MODE[nm];
    QueryDisplayConfig(2, ref np, paths, ref nm, modes, IntPtr.Zero);
    string o = "";
    for (int i = 0; i < np; i++) {
      TGT t = paths[i].tgt;
      TGTNAME n = new TGTNAME();
      n.header.type = 2; n.header.size = (uint)Marshal.SizeOf(typeof(TGTNAME));
      n.header.adapterId = t.adapterId; n.header.id = t.id;
      GetTgtName(ref n);
      ADVCOLOR a = new ADVCOLOR();
      a.header.type = 9; a.header.size = (uint)Marshal.SizeOf(typeof(ADVCOLOR));
      a.header.adapterId = t.adapterId; a.header.id = t.id;
      GetAdvColor(ref a);
      string enc = a.colorEncoding == 0 ? "RGB" : a.colorEncoding == 1 ? "YCbCr444" : a.colorEncoding == 2 ? "YCbCr422" : a.colorEncoding == 3 ? "YCbCr420" : "?";
      double hz = t.refreshRate.Den > 0 ? (double)t.refreshRate.Num / t.refreshRate.Den : 0;
      o += "  " + (n.name == null ? "(unnamed)" : n.name.Trim()) + "\n";
      o += "    bits per color channel : " + a.bitsPerColorChannel + " bpc\n";
      o += "    color encoding         : " + enc + "\n";
      o += "    HDR supported / on     : " + ((a.value & 1) != 0) + " / " + ((a.value & 2) != 0) + "\n";
      o += "    refresh                : " + Math.Round(hz, 2) + " Hz\n";
    }
    return o;
  }
}
"@
try { Add-Type -TypeDefinition $code -ErrorAction Stop; Write-Host ([DiagColor]::Read()) } catch { Write-Host "  (failed: $_)" }

Section "4. Gamma ramp  (a forced ramp was a suspect - it was not the cause)"
$g = @"
using System;
using System.Runtime.InteropServices;
public class DiagGamma {
  [DllImport("gdi32.dll", CharSet=CharSet.Auto)] public static extern IntPtr CreateDC(string d, string dev, string p, IntPtr dm);
  [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr hdc);
  [DllImport("gdi32.dll")] public static extern bool GetDeviceGammaRamp(IntPtr hDC, [Out] ushort[] lpRamp);
}
"@
try {
  Add-Type -TypeDefinition $g -ErrorAction Stop
  foreach ($dev in @('\\.\DISPLAY1','\\.\DISPLAY2','\\.\DISPLAY3')) {
    $hdc = [DiagGamma]::CreateDC($dev, $null, $null, [IntPtr]::Zero)
    if ($hdc -eq [IntPtr]::Zero) { continue }
    $ramp = [uint16[]]::new(768)
    if ([DiagGamma]::GetDeviceGammaRamp($hdc, $ramp)) {
      $max = 0
      for ($i=0; $i -lt 256; $i++) { $d = [Math]::Abs([int]$ramp[$i] - ($i*257)); if ($d -gt $max) { $max = $d } }
      $s = if ($max -eq 0) { "clean (identity)" } else { "A RAMP IS APPLIED" }
      Write-Host "  $dev  max deviation from identity = $max  ->  $s"
    }
    [void][DiagGamma]::DeleteDC($hdc)
  }
} catch { Write-Host "  (failed: $_)" }

Section "5. DWM overlay keys  (MPO was a suspect - it was not the cause)"
$d = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'
foreach ($n in 'OverlayTestMode','OverlayMinFPS') {
  if ($d.PSObject.Properties.Name -contains $n) { Write-Host "  $n = $($d.$n)" } else { Write-Host "  $n = (not set)" }
}

Section "6. Current cursor handed to Windows"
try {
  Add-Type -AssemblyName System.Drawing
  $c = @"
using System;
using System.Runtime.InteropServices;
public class DiagCur {
  [StructLayout(LayoutKind.Sequential)] public struct CURSORINFO { public int cbSize; public int flags; public IntPtr hCursor; public int x; public int y; }
  [DllImport("user32.dll")] public static extern bool GetCursorInfo(ref CURSORINFO pci);
}
"@
  Add-Type -TypeDefinition $c -ErrorAction Stop
  $ci = New-Object DiagCur+CURSORINFO
  $ci.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($ci)
  if ([DiagCur]::GetCursorInfo([ref]$ci) -and $ci.hCursor -ne [IntPtr]::Zero) {
    $bmp = ([System.Drawing.Icon]::FromHandle($ci.hCursor)).ToBitmap()
    Write-Host "  handle $([int64]$ci.hCursor)   bitmap $($bmp.Width)x$($bmp.Height)"
    Write-Host "  NOTE: sizes over 64x64 are non-standard for a hardware cursor."
    Write-Host "        The bitmap itself was measured CORRECT during the investigation -"
    Write-Host "        the corruption happens on the way to the screen, not in the drawing."
    $bmp.Dispose()
  }
} catch { Write-Host "  (failed: $_)" }

Write-Host ""
Write-Host "Compare these values against README.md before forming any new theory." -ForegroundColor Cyan
