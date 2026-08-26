# Mouse cursor too bright / washed out in games? Here's the fix.

Your cursor looks **faded, overexposed, or almost white** inside a game — but goes back to normal the
second you start a **Discord screen share**. Screenshots don't show the problem. Turning HDR off
doesn't help.

It's a known NVIDIA driver bug. **Fixing it takes about 20 seconds.**

---

# ✅ Just fix it

**1.** Press <kbd>Win</kbd> + <kbd>X</kbd> and click **Terminal** (or **Windows PowerShell**).

**2.** Paste this and press <kbd>Enter</kbd>:

```powershell
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseTrails '-1'; try{Add-Type 'using System;using System.Runtime.InteropServices;public class FixCursor{[DllImport("user32.dll")]public static extern bool SystemParametersInfo(uint a,uint b,IntPtr c,uint d);}'}catch{}; [void][FixCursor]::SystemParametersInfo(0x005D,[uint32]4294967295,[IntPtr]::Zero,3); "Cursor fixed. MouseTrails = " + (Get-ItemProperty 'HKCU:\Control Panel\Mouse' -Name MouseTrails).MouseTrails
```

**3.** It prints `Cursor fixed. MouseTrails = -1`. Move your mouse over your game — the color is back.

That's it. **No admin. No download. No reboot. You don't even have to close your game.**

Nothing gets installed and nothing keeps running — it changes one Windows setting. It survives
restarts, so you only do this once.

### To undo it

```powershell
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseTrails '0'; try{Add-Type 'using System;using System.Runtime.InteropServices;public class UndoCursor{[DllImport("user32.dll")]public static extern bool SystemParametersInfo(uint a,uint b,IntPtr c,uint d);}'}catch{}; [void][UndoCursor]::SystemParametersInfo(0x005D,0,[IntPtr]::Zero,3); "Reverted."
```

### It came back later?

Windows updates can silently reset it. Run the fix again — same line, same result.

---

# Is this actually your problem?

| Symptom | |
|---|---|
| Cursor looks blown out / too bright / washed out **in game** | ✅ |
| Starting a **screen share or recording** makes it normal, live, on your own monitor | ✅ |
| **Screenshots don't show the bug** — only a phone photo of your screen does | ✅ |
| Happens with the **default cursor and custom cursors** alike | ✅ |
| **HDR is off**, and toggling it changes nothing | ✅ |
| Affects **any game or app**, not just one | ✅ |

If most of those match, the fix above is for you.

---

# Why it happens

Your mouse cursor is not part of the image your game renders. It's a **hardware cursor** — a separate
layer drawn by the GPU's display engine at the very last moment before the signal reaches your
monitor. It never goes through the same color pipeline as everything else on screen.

On affected NVIDIA drivers that layer gets the color conversion wrong, and the cursor comes out
overexposed. Because the broken cursor lives outside the frame, screenshots and most capture paths
never see it — which is exactly why it "looks fine" in a Discord stream.

Reported on the official NVIDIA forums as
["Hardware Cursor Incorrectly Brightness/too white"](https://www.nvidia.com/en-us/geforce/forums/geforce-graphics-cards/5/579170/hardware-cursor-incorrectly-brightnesstoo-white-in/),
in **SDR mode** — this is *not* the well-known "HDR makes the cursor bright" issue.

- Confirmed affected: driver `32.0.16.1074` = **NVIDIA 610.74**
- Also reported: **591.44**
- Reported clean: **581.80**

## What the fix actually does

`MouseTrails` is the "pointer trails" accessibility setting. Turning it on forces Windows to render
the cursor in **software** (composited by the DWM, inside the frame) instead of using the broken
hardware cursor layer.

The f.lux developer
[documented using this exact registry value](https://forum.justgetflux.com/topic/8548/disabled-software-mouse-cursor-for-windows-11-insider)
to *"force software drawing of the mouse... avoids bugs on GPUs that don't color-correct the cursor."*

### Why `-1` and not `2`

| `MouseTrails` | Result |
|---|---|
| `0` | Off — hardware cursor, **bug present** |
| `2`–`7` | Software cursor, **with a visible trail** behind it |
| **`-1`** | Software cursor, **no trail at all** ← what this repo uses |

Most guides out there tell you to use `2`, which fixes the color but leaves a cursor trail — useless
for competitive games, and the reason a lot of people give up on this fix. **`-1` is undocumented
(the documented range is `0`, `2`–`7`) but it works.** That's the main thing this repo adds.

### The one trade-off

A software cursor is composited **with the frame**, so it updates at your monitor's refresh rate
instead of moving independently of it. At 165 Hz that's roughly 6 ms of extra granularity.
Imperceptible for most people; a competitive player might notice it.

**If that bothers you, rolling back to driver 581.80 is the only fix with no cursor cost** — it keeps
the hardware cursor and corrects the color.

---

# What does NOT fix it

Ten hypotheses were tested and measured before finding the answer. **Don't waste your time:**

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

The last row deserves attention: **opening a genuine screen-capture session — the same API Discord
uses — does not fix the cursor.** So whatever Discord does to fix it live is still unexplained. The
fix works; that particular mystery is open. If you know the answer, [open an issue](../../issues).

---

# Scripts (optional)

You don't need these — the one-liner above is the whole fix. They exist if you'd rather click a file
or want the diagnostics.

| File | Purpose |
|---|---|
| `apply-fix.bat` | Double-click to apply the fix |
| `revert-fix.bat` | Double-click to undo |
| `diagnose.bat` | Double-click to dump driver, color depth, HDR state, gamma ramp, DWM keys and the current cursor bitmap. **Read-only** — changes nothing |
| `*.ps1` | The actual scripts behind those, if you want to read them first |
| `tools/StreamFantasma.exe` | Opens a real Desktop Duplication session and throws every frame away. **Does not fix this bug** — included because it's what disproves the "capture forces composition" theory |

> If you download these, Windows may warn you about files from the internet. That's normal for any
> downloaded `.bat`. If that bothers you, just use the copy-paste line at the top — it does the same
> thing with nothing to download.

---

# Credits

Found the hard way on an RTX 2080 Super / Windows 11 25H2 (build 26200) / driver 610.74, while trying
to work out why the cursor in Dota 2 only looked right during a Discord stream.

Sources: [NVIDIA forums](https://www.nvidia.com/en-us/geforce/forums/geforce-graphics-cards/5/579170/hardware-cursor-incorrectly-brightnesstoo-white-in/)
· [10-bit color depth thread](https://www.nvidia.com/en-us/geforce/forums/game-ready-drivers/13/560012/10bit-color-depth-issues/)
· [f.lux forum](https://forum.justgetflux.com/topic/8548/disabled-software-mouse-cursor-for-windows-11-insider)
· [MS Learn: DXGI flip model](https://learn.microsoft.com/en-us/windows/win32/direct3ddxgi/for-best-performance--use-dxgi-flip-model)

Em português: [LEIA-ME.md](LEIA-ME.md)

**Using an AI assistant to fix this?** Point it at [AGENTS.md](AGENTS.md) — a guide written for AI
coding agents, with the exact commands, the ten hypotheses that were measured and ruled out, and the
disambiguating question that has to be asked first. It exists so an agent doesn't repeat the same
eleven-hypothesis investigation.

## License

MIT — use it, copy it, paste it in a forum thread. That's the point.
