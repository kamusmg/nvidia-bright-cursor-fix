# Guide for AI coding agents

You are probably here because a user said something like *"my cursor is too bright in game"*,
*"washed out cursor"*, or *"the cursor looks normal when I stream on Discord"*.

**Read this before forming a hypothesis.** This bug wastes an enormous amount of time if you
approach it as a color-pipeline problem. Ten reasonable theories were tested and measured before the
answer was found. They are listed below so you skip all of them.

---

## TL;DR — the fix

```powershell
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseTrails '-1'
# then notify Windows so it applies live (no reboot, no closing the game):
Add-Type 'using System;using System.Runtime.InteropServices;public class FixCursor{[DllImport("user32.dll")]public static extern bool SystemParametersInfo(uint a,uint b,IntPtr c,uint d);}'
[void][FixCursor]::SystemParametersInfo(0x005D,[uint32]4294967295,[IntPtr]::Zero,3)
```

`0x005D` = `SPI_SETMOUSETRAILS`. `4294967295` = `-1` as `uint32`. `3` = `SPIF_UPDATEINIFILE | SPIF_SENDCHANGE`.

No admin required. Persists across reboots. No process stays running.

---

## Step 1 — confirm it is this bug

Ask the user, or measure. **All of these should be true:**

| Check | Expected for this bug |
|---|---|
| Cursor looks washed out **inside a game** | yes |
| Starting a screen share / recording fixes it **live on their own monitor** | yes |
| Screenshots do **not** reproduce it (only a phone photo of the screen does) | yes |
| Happens with the **default cursor and custom cursors alike** | yes |
| GPU is **NVIDIA** | yes |
| HDR is **off** | yes — this is the SDR variant, not the common HDR cursor issue |

⚠️ **Ask explicitly where the cursor looks normal during a screen share: on their physical monitor,
or only in the stream image?** These are different problems. Discord draws its own cursor overlay on
top of captured video, so "it looks right in the stream" proves nothing. Only "it looks right on my
monitor, live" points at this bug. Getting this wrong sends you down three dead ends.

### Measure the environment

```powershell
# Driver version (32.0.16.1074 = NVIDIA 610.74, confirmed affected; 581.80 reported clean)
Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate

# Is the fix already applied?
(Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseTrails).MouseTrails
```

Or run `diagnose.ps1` from this repo — it dumps driver, per-display color depth, HDR state, gamma
ramp, DWM overlay keys and the current cursor bitmap. It is read-only.

## Step 2 — apply and verify

Apply the TL;DR command, then verify:

```powershell
(Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseTrails).MouseTrails   # expect -1
```

Then ask the user to look at the cursor **in an actual game**, not the desktop or a menu.

## Step 3 — if it did not work

1. Confirm the value really is `-1`. Do not trust that the command succeeded — read it back.
2. If it is `-1` and the cursor is still broken, the driver behaviour differs. Recommend **rolling
   back to NVIDIA 581.80**, which is reported clean.
3. Do not start theorizing about the color pipeline. See the list below.

---

## ❌ Do NOT investigate these — all measured, all negative

| # | Hypothesis | How it was ruled out |
|---|---|---|
| 1 | HDR / Auto HDR | No registry keys set; measured 8 bpc RGB, HDR off, on both displays |
| 2 | Forced gamma ramp | `GetDeviceGammaRamp` → identity, deviation **0**, with the game running |
| 3 | In-game brightness / gamma | No effect. Also cannot explain why *only* the cursor is affected |
| 4 | `SwapEffectUpgradeEnable=0` | No effect — it is a no-op for engines already on the flip model |
| 5 | Cursor size / scale | No effect at 32×32, nor above the 64 px hardware-cursor limit |
| 6 | Cursor cosmetics / cursor packs | Default and custom cursors break identically |
| 7 | **MPO** — `OverlayTestMode=5` + `OverlayMinFPS=0` + reboot | No effect |
| 8 | 1×1 topmost window to force Composed Flip | No effect |
| 9 | **A real Desktop Duplication capture session** | No effect |
| 10 | Output color depth 10 bpc → 8 bpc | Already at 8 bpc |

**#9 is the important one.** Opening a genuine capture session — the same API Discord uses — does
**not** fix the cursor. So the intuitive model ("capture forces DWM composition, which bypasses the
broken hardware cursor plane") is **wrong**, or at least incomplete. `tools/StreamFantasma.exe` in
this repo is that experiment, kept as evidence.

**Open question:** what Discord actually does that fixes the cursor live is still unexplained. The
fix works regardless. If you determine the mechanism, please open an issue — do not present a guess
as the answer.

---

## Gotchas that will cost you time

### PowerShell

```powershell
# WRONG - assigns to a COPY of the nested struct, silently does nothing
$s.header.size = 32

# RIGHT - build the whole header, assign it in one go (or do it all in C#)
$h = New-Object MyType+HDR; $h.size = 32; $s.header = $h
```

- `0xFFFFFFFF` is parsed as `Int32 -1` and fails a `uint` parameter. Use `[uint32]4294967295`.
- Each tool call may open a fresh shell — `Add-Type` from a previous call is gone. Keep the type
  definition and its use in the same script.
- Never `Set-Content -Encoding utf8` on a game config: it writes a BOM and corrupts the file. Use
  `[IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($false)))` and verify the
  first 4 bytes before and after.
- Markdown backticks inside a double-quoted string become escape characters. Use `@'...'@`.

### Dota 2 specifically (if that is the game)

- **Brightness and cursor settings do not live in `video.txt`.** They live in `machine_convars.vcfg`
  under the Steam userdata folder. `video.txt` is a mirror the game rewrites **on exit** — editing it
  while the game is closed is silently ignored on the next launch. This invalidated an entire test.
- The install may not be under `C:\Program Files (x86)\Steam`. Check the running process path:
  `Get-CimInstance Win32_Process -Filter "Name='dota2.exe'" | Select ExecutablePath`. A stale entry
  in `HKCU\Software\Microsoft\DirectX\UserGpuPreferences` pointing at an old install will absorb your
  edits and do nothing.

---

## Method notes

Two mistakes are worth inheriting:

1. **The answer was in the first web search and was applied last.** Community sources unanimously
   recommend enabling pointer trails. That recommendation was deprioritized in favour of chasing
   *why* Discord fixes it. Apply the documented fix first; investigate the mechanism after.
2. **The disambiguating question was asked too late.** "Discord fixes it" was ambiguous between two
   very different scenarios (see Step 1). Three hypotheses were built on the ambiguous reading before
   anyone asked. Ask first.

Report what you measured versus what you inferred. Do not present a hypothesis as a conclusion.
