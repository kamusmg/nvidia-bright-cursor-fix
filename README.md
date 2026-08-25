# Fix: mouse cursor is too bright / washed out in games (NVIDIA, Windows 11)

Your mouse cursor looks **overexposed, washed out, faded, or almost white** inside a game — but it
looks completely normal the moment you start a **Discord screen share**, and it looks normal in
screenshots. Turning HDR off doesn't help. It happens with the default cursor *and* with custom
cursors.

**This is a known NVIDIA hardware-cursor bug. One registry value fixes it, permanently, with zero
running processes.**

```powershell
# Run in PowerShell (no admin needed)
Set-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseTrails -Value '-1'
```

Then log off and back on — or run [`apply-fix.ps1`](apply-fix.ps1) from this repo, which applies it
**instantly**, without a reboot and without closing your game.

---

## Does this match your problem?

| Symptom | |
|---|---|
| Cursor looks blown out / too bright / washed out **in game** | ✅ |
| Starting a **screen share or recording** makes it normal, live, on your own monitor | ✅ |
| **Screenshots don't show the bug** — only a phone photo of the screen does | ✅ |
| Happens with the **default cursor and custom cursors** alike | ✅ |
| **HDR is off**, and turning it on/off changes nothing | ✅ |
| Affects **multiple games / any app**, not just one | ✅ |

If most of those match, this repo is for you.

## Why it happens

The mouse cursor is not part of the image your game renders. It's a **hardware cursor**: a separate
plane drawn by the GPU's display engine at the very last moment before the signal reaches your
monitor. It never passes through the same color pipeline as everything else on screen.

On affected NVIDIA drivers, that plane gets the color conversion wrong and the cursor comes out
overexposed. Because the broken cursor lives outside the framebuffer, screenshots and most capture
paths never see it — which is exactly why it "looks fine" in a Discord stream.

Reported on the official NVIDIA forums as
["Hardware Cursor Incorrectly Brightness/too white"](https://www.nvidia.com/en-us/geforce/forums/geforce-graphics-cards/5/579170/hardware-cursor-incorrectly-brightnesstoo-white-in/),
in **SDR mode** — this is *not* the well-known "HDR makes the cursor bright" issue.

- Confirmed affected: driver `32.0.16.1074` = **NVIDIA 610.74**
- Also reported: **591.44**
- Reported clean: **581.80**

## How the fix works

Enabling pointer trails forces Windows to render the cursor in **software** (composited by the DWM,
inside the frame) instead of using the broken hardware cursor plane.

The f.lux developer
[documented using this exact registry value](https://forum.justgetflux.com/topic/8548/disabled-software-mouse-cursor-for-windows-11-insider)
to *"force software drawing of the mouse... avoids bugs on GPUs that don't color-correct the cursor."*

### Which value to use

| `MouseTrails` | Result |
|---|---|
| `0` | Off — hardware cursor, **bug present** |
| `2`–`7` | Software cursor, **with a visible trail** (bad for competitive games) |
| **`-1`** | Software cursor, **no trail** ← **use this** |

`-1` is outside the documented range (`0`, `2`–`7`) but works and is the reason this repo exists —
most guides tell you to use `2` and leave you with a cursor trail.

### The one trade-off

A software cursor is composited **with the frame**, so it updates at your monitor's refresh rate
instead of moving independently of it. At 165 Hz that's roughly 6 ms of extra granularity.
Imperceptible for most people; a competitive player might notice.

**If that matters to you, rolling back to driver 581.80 is the only fix with no cursor cost** — it
keeps the hardware cursor and corrects the color.

## What does NOT fix it

Ten hypotheses were tested and measured before finding the answer. **Don't waste your time on these:**

| Suspect | Result |
|---|---|
| Turning HDR / Auto HDR off | No effect — measured 8 bpc RGB, HDR already off |
| Gamma ramp overrides | `GetDeviceGammaRamp` showed a clean identity ramp (deviation 0) |
| In-game brightness / gamma setting | No effect, and it can't explain "only the cursor" |
| `SwapEffectUpgradeEnable=0` ("optimizations for windowed games") | No effect |
| Changing cursor size / scale | No effect at 32×32 or above 64 px |
| Cursor cosmetics / cursor packs | Default and custom cursors break identically |
| **Disabling MPO** (`OverlayTestMode=5` + `OverlayMinFPS=0` + reboot) | No effect |
| A 1×1 topmost window to force Composed Flip | No effect |
| **A real Desktop Duplication capture session** | No effect |
| Switching output color depth 10 bpc → 8 bpc | Already at 8 bpc |

The last one is worth highlighting: **opening a genuine screen-capture session — the same API Discord
uses — does not fix the cursor.** So whatever Discord does to fix it live is still unexplained. The
fix works; that particular mystery remains open. If you know the answer,
[open an issue](../../issues).

## Files

| File | Purpose |
|---|---|
| [`apply-fix.ps1`](apply-fix.ps1) | Applies the fix live — no reboot, no closing your game |
| [`revert-fix.ps1`](revert-fix.ps1) | Undoes it and restores the hardware cursor |
| [`diagnose.ps1`](diagnose.ps1) | Read-only. Dumps driver, color depth, HDR state, gamma ramp, DWM keys, and the current cursor bitmap |
| `tools/StreamFantasma.exe` | Opens a real Desktop Duplication session and discards every frame. **Does not fix this bug** — included because it disproves the "capture forces composition" theory, and it's useful for forcing Composed Flip in other scenarios |

Nothing here installs anything or leaves a process running. The fix is a single registry value.

## Verifying it worked

```powershell
(Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseTrails).MouseTrails
# -1  = fix applied
```

Move the mouse over your game. The color should be correct, with no trail behind it.

## Credits

Found the hard way, on an RTX 2080 Super / Windows 11 25H2 (build 26200) / driver 610.74, while
trying to figure out why the cursor in Dota 2 only looked right during a Discord stream.

Sources: [NVIDIA forums](https://www.nvidia.com/en-us/geforce/forums/geforce-graphics-cards/5/579170/hardware-cursor-incorrectly-brightnesstoo-white-in/)
· [10-bit color depth thread](https://www.nvidia.com/en-us/geforce/forums/game-ready-drivers/13/560012/10bit-color-depth-issues/)
· [f.lux forum](https://forum.justgetflux.com/topic/8548/disabled-software-mouse-cursor-for-windows-11-insider)
· [MS Learn: DXGI flip model](https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/for-best-performance--use-dxgi-flip-model)

Portuguese version: [LEIA-ME.md](LEIA-ME.md)

## License

MIT
