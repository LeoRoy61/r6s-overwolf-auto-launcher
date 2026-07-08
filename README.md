# 🎮 R6 + Overwolf Launcher

A lightweight Windows launcher that automatically starts **Overwolf** alongside **Rainbow Six Siege**, monitors the game, and closes Overwolf cleanly when you're done playing.

All settings live in a single `config.ini` — **no need to touch the scripts themselves**.

[![Download ZIP](https://img.shields.io/badge/Download-ZIP_v2.0-green?style=for-the-badge&logo=github)](https://github.com/LeoRoy61/r6s-overwolf-auto-launcher/releases/download/v2.0/r6s-overwolf-launcher-v2.0.zip)

> ⚠️ **Disclaimer:** This script is a launcher utility. It **does not** include or download Overwolf, Ubisoft Connect, or Rainbow Six Siege. You must have these applications installed on your system beforehand.

---

## ✨ Features

- 🚀 Launches Overwolf before the game so overlays are ready on time
- 🔎 **Auto-detects Overwolf and Rainbow Six Siege** via Windows Registry and all drives (C, D, E…)
- 🔍 Monitors the game process and waits gracefully for the game to appear
- 🛑 Detects when the game closes and terminates all Overwolf processes
- ⚙️ Fully configurable via `config.ini` (paths, timing, processes)
- 🔁 Works with **any Ubisoft Connect game** — just change the Game ID

---

## 📁 Files

```
r6-overwolf-launcher/
├── setup.bat          ← Run this first! Auto-detects Overwolf and saves config 🔧
├── Avvia_R6.bat       ← Run every time you play 🎮
│
├── setup.ps1          ← Setup logic (called by setup.bat)
├── Avvia_R6.ps1       ← Launcher logic (called by Avvia_R6.bat)
├── sign_script.ps1    ← Optional: self-sign scripts to remove SmartScreen warnings
│
├── config.ini         ← All user settings (auto-filled by setup.bat) ✏️
└── README.md
```

> 💡 The `.bat` files are **3-line wrappers** — you can open them in Notepad to verify they do nothing suspicious. All logic is in the `.ps1` files, which are readable plain text.

---

## ⚙️ Configuration (`config.ini`)

Open `config.ini` with any text editor and adjust the values as needed:

### `[PATHS]`

| Key | Default | Description |
|---|---|---|
| `OVERWOLF_PATH` | *(auto-detected)* | Full path to `Overwolf.exe` — set by `setup.bat` |
| `GAME_LAUNCH_URL` | `uplay://launch/635/0` | Ubisoft Connect launch URL |

### `[PROCESS]`

| Key | Default | Description |
|---|---|---|
| `GAME_PROCESS` | `RainbowSix.exe` | Process name to monitor (as shown in Task Manager) |
| `OVERWOLF_PROCESSES` | `Overwolf.exe,OverwolfBrowser.exe` | Comma-separated list of processes to close on exit |

### `[TIMING]`

| Key | Default | Description |
|---|---|---|
| `OVERWOLF_INIT_DELAY` | `3` | Seconds to wait after Overwolf starts |
| `MONITOR_INTERVAL` | `10` | Seconds between each game process check |
| `ABSENCE_THRESHOLD` | `5` | Consecutive missed checks before Overwolf is closed |
| `WAIT_START_INTERVAL` | `2` | Seconds between startup checks |
| `MAX_START_ATTEMPTS` | `90` | Max startup attempts before timeout (90×2s = 3 min) |


---

## 🚀 How to Use

### First time
1. **Download** the repository (Clone or Download ZIP from GitHub)
2. **Double-click `setup.bat`** — it will:
   - Automatically find Overwolf on your PC (Registry + all drives)
   - Ask you to confirm the path, or enter it manually if not found
   - Automatically locate `RainbowSix.exe` on your system (Registry/Common library paths)
   - Ask you to confirm the game path, or enter it manually if not found
   - Prompt you to automatically create shortcuts on your **Desktop** and/or **Start Menu**
   - Save your choices to `config.ini`
3. If you chose to create a shortcut during setup, you can launch the game directly from your **Desktop** or **Start Menu**! It will have the official Rainbow Six Siege game icon, behaving exactly like the original shortcut.

### Subsequent runs
Launch the game using the created **Desktop/Start Menu shortcut** or by running **`Avvia_R6.bat`** directly. All settings are read from `config.ini`.

> 💡 **Changed your Overwolf install or want to re-create shortcuts?** Just re-run `setup.bat`.

---

## 🎯 Supported Games

Pre-configured for **Rainbow Six Siege**. Works with any Ubisoft Connect title:

| Game | `GAME_LAUNCH_URL` | `GAME_PROCESS` |
|---|---|---|
| Rainbow Six Siege | `uplay://launch/635/0` | `RainbowSix.exe` |
| For Honor | `uplay://launch/304/0` | `ForHonor.exe` |
| The Division 2 | `uplay://launch/919/0` | `Division2.exe` |

---

## 🛡️ Windows Defender & SmartScreen

### Why does Windows show a warning?

When you download this script from GitHub, Windows marks it as "downloaded from the internet"
(a hidden tag called *Mark of the Web*). **SmartScreen blocks files without a known reputation**,
meaning files that haven't been downloaded by enough users yet.

This is **expected behavior for any new open-source project**, not a sign the script is malicious.

### Is it safe to run?

Yes. You can verify this yourself in seconds:

1. **Open `Avvia_R6.bat` in Notepad** — it's literally 3 lines:
   ```batch
   @echo off
   :: Comment
   powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Avvia_R6.ps1"
   ```
2. **Open `Avvia_R6.ps1` in Notepad or VS Code** — it's plain, readable PowerShell.
3. **Review the source on GitHub** before downloading.

### Why PowerShell instead of batch?

The original `.bat` version used commands like `taskkill /f` and drive scanning loops
that **trigger antivirus heuristics** — those patterns are identical to how ransomware
kills backup software and spreads across drives. This PowerShell rewrite uses standard
PowerShell cmdlets (`Stop-Process`, `Get-Process`, `[System.IO.DriveInfo]::GetDrives()`)
which have a much lower heuristic risk profile.

### How to bypass SmartScreen (one time)

When you see "Windows protected your PC":
1. Click **"More info"**
2. Click **"Run anyway"**

Windows remembers the choice — you won't be asked again for the same file.

### Optional: self-sign the scripts (advanced)

For a permanent fix on your own machine, run `sign_script.ps1` as Administrator.
It will create a code-signing certificate and sign the `.ps1` files.

```powershell
# In an elevated PowerShell prompt:
Set-ExecutionPolicy Bypass -Scope Process
.\sign_script.ps1
```

After signing, the scripts will be trusted locally without any SmartScreen prompt.

### Reporting a false positive

If an antivirus flags this script, please report it as a false positive:
- **Windows Defender:** [Microsoft Security Intelligence](https://www.microsoft.com/en-us/wdsi/filesubmission)
- **VirusTotal analysis:** Upload the `.ps1` to [virustotal.com](https://www.virustotal.com) and share the link in a GitHub issue

---

## 🐛 Troubleshooting

**SmartScreen blocks the file**
→ Click "More info" → "Run anyway". This is expected for new/unsigned scripts.

**"config.ini not found"**
→ Make sure all files are in the same folder. Re-download if needed.

**Game doesn't launch**
→ Make sure Ubisoft Connect is installed and the `GAME_LAUNCH_URL` is correct.

**Script closes too early**
→ Increase `ABSENCE_THRESHOLD` or `MONITOR_INTERVAL` in `config.ini`.

**PowerShell says "cannot be loaded because running scripts is disabled"**
→ The `.bat` launcher uses `-ExecutionPolicy Bypass` which overrides this automatically.
   If you run the `.ps1` directly, run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

---

## 📄 License

MIT License — free to use, modify, and distribute.
