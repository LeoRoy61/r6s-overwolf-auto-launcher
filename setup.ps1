#Requires -Version 5.1
<#
.SYNOPSIS
    First-time setup for R6 + Overwolf Launcher.

.DESCRIPTION
    Automatically detects Overwolf on your system (via Registry and drive scan),
    lets you confirm or enter the path manually, choose your language, and saves
    everything to config.ini.

    Run this once before using Avvia_R6.bat.

.NOTES
    Version : 2.0
    GitHub  : https://github.com/YOUR_USERNAME/r6-overwolf-launcher
    License : MIT
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigPath = Join-Path $ScriptDir 'config.ini'

# ─────────────────────────────────────────────────────────────────────────────
#  Helper Functions (shared with Avvia_R6.ps1)
# ─────────────────────────────────────────────────────────────────────────────

function Read-IniFile {
    param([string]$Path)
    $table = [ordered]@{}
    foreach ($line in (Get-Content $Path -Encoding UTF8 -ErrorAction Stop)) {
        $line = $line.Trim()
        if ($line -match '^\s*[;#]' -or $line -match '^\s*\[' -or $line -eq '') { continue }
        if ($line -match '^([^=]+?)\s*=\s*(.*)$') {
            $table[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $table
}

function Update-IniValue {
    param([string]$Path, [string]$Key, [string]$Value)
    $content  = Get-Content $Path -Encoding UTF8
    $replaced = $false
    $out = $content | ForEach-Object {
        if ($_ -match "^\s*$([regex]::Escape($Key))\s*=") {
            $replaced = $true
            "$Key=$Value"
        } else { $_ }
    }
    if (-not $replaced) { $out += "$Key=$Value" }
    $out | Set-Content -Path $Path -Encoding UTF8
}

function Find-OverwolfExe {
    # 1. Windows Registry
    $regKeys = @(
        'HKLM:\SOFTWARE\WOW6432Node\Overwolf',
        'HKLM:\SOFTWARE\Overwolf',
        'HKCU:\SOFTWARE\Overwolf'
    )
    foreach ($key in $regKeys) {
        if (Test-Path $key) {
            $dir = (Get-ItemProperty $key -ErrorAction SilentlyContinue) |
                   Select-Object -ExpandProperty InstallPath -ErrorAction SilentlyContinue
            if ($dir) {
                $candidate = Join-Path $dir.TrimEnd('\') 'Overwolf.exe'
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }

    # 2. Scan all fixed drives
    $fixedDrives = [System.IO.DriveInfo]::GetDrives() |
                   Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }
    $subPaths = @(
        'Program Files (x86)\Overwolf\Overwolf.exe',
        'Program Files\Overwolf\Overwolf.exe',
        'Overwolf\Overwolf.exe'
    )
    foreach ($drive in $fixedDrives) {
        foreach ($sub in $subPaths) {
            $candidate = Join-Path $drive.RootDirectory.FullName $sub
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

function Find-RainbowSixExe {
    # 1. Registry (Ubisoft Connect Game ID 635)
    $uplayKeys = @(
        'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\635',
        'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs\635'
    )
    foreach ($key in $uplayKeys) {
        if (Test-Path $key) {
            $dir = (Get-ItemProperty $key -ErrorAction SilentlyContinue) |
                   Select-Object -ExpandProperty InstallDir -ErrorAction SilentlyContinue
            if ($dir) {
                $candidate = Join-Path $dir.TrimEnd('\') 'RainbowSix.exe'
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }

    # 2. Registry (Steam App 359550)
    $steamKeys = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 359550',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 359550'
    )
    foreach ($key in $steamKeys) {
        if (Test-Path $key) {
            $dir = (Get-ItemProperty $key -ErrorAction SilentlyContinue) |
                   Select-Object -ExpandProperty InstallLocation -ErrorAction SilentlyContinue
            if ($dir) {
                $candidate = Join-Path $dir.TrimEnd('\') 'RainbowSix.exe'
                if (Test-Path $candidate) { return $candidate }
            }
        }
    }

    # 3. Scan common paths on fixed drives
    $fixedDrives = [System.IO.DriveInfo]::GetDrives() |
                   Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }
    $subPaths = @(
        'Program Files (x86)\Steam\steamapps\common\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe',
        'Program Files\Steam\steamapps\common\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe',
        'SteamLibrary\steamapps\common\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe',
        'Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe',
        'Program Files\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe',
        'Games\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe'
    )
    foreach ($drive in $fixedDrives) {
        foreach ($sub in $subPaths) {
            $candidate = Join-Path $drive.RootDirectory.FullName $sub
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

function Get-UserDesktopPath {
    $path = [System.Environment]::GetFolderPath('Desktop')
    if ($path -and (Test-Path $path)) { return $path }

    $candidate = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
    if (Test-Path $candidate) { return $candidate }

    $candidate = Join-Path $env:USERPROFILE 'Desktop'
    if (Test-Path $candidate) { return $candidate }

    return $null
}

function Get-UserProgramsPath {
    $path = [System.Environment]::GetFolderPath('Programs')
    if ($path -and (Test-Path $path)) { return $path }

    $candidate = Join-Path $env:USERPROFILE 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
    if (Test-Path $candidate) { return $candidate }

    $path = [System.Environment]::GetFolderPath('StartMenu')
    if ($path) {
        $candidate = Join-Path $path 'Programs'
        if (Test-Path $candidate) { return $candidate }
    }

    return $null
}

function Create-Shortcut {
    param(
        [string]$Target,
        [string]$Path,
        [string]$IconPath
    )
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($Path)
        $lnk.TargetPath = $Target
        $lnk.WorkingDirectory = Split-Path -Parent $Target
        if ($IconPath -and (Test-Path $IconPath)) {
            $lnk.IconLocation = "$IconPath,0"
        }
        $lnk.Save()
        return $true
    } catch {
        Write-Host "  [!] Exception creating shortcut at '$Path': $_" -ForegroundColor Red
        return $false
    }
}

function Get-Confirmation {
    param([string]$Message)
    while ($true) {
        $response = (Read-Host $Message).Trim().ToLower()
        if ($response -in @('y', 'yes')) {
            return $true
        }
        if ($response -in @('n', 'no')) {
            return $false
        }
        Write-Host "  [!] Invalid input. Please type 'y' or 'n'." -ForegroundColor Yellow
    }
}

function Write-Step {
    param([string]$Number, [string]$Text)
    Write-Host "[$Number] " -ForegroundColor DarkGray -NoNewline
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Rule {
    Write-Host ('=' * 53) -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
#  Check config.ini exists
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[ERROR] config.ini not found in: $ScriptDir" -ForegroundColor Red
    Write-Host "Please restore it from the GitHub repository." -ForegroundColor Yellow
    Read-Host 'Press ENTER to exit'
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
#  Header
# ─────────────────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ''
Write-Rule
Write-Host '  SETUP: R6 + Overwolf Launcher' -ForegroundColor Cyan
Write-Rule
Write-Host ''

# ─────────────────────────────────────────────────────────────────────────────
#  Step 1 — Find Overwolf
# ─────────────────────────────────────────────────────────────────────────────

Write-Step '1/4' 'Searching for Overwolf on your system...'
Write-Host ''

$foundOW = Find-OverwolfExe

if ($foundOW) {
    Write-Host '  Found: ' -ForegroundColor DarkGray -NoNewline
    Write-Host $foundOW -ForegroundColor Green
    Write-Host ''
    $confirm = Get-Confirmation '  Is this correct? [y/n]'
    if (-not $confirm) {
        $foundOW = $null
    }
}

if (-not $foundOW) {
    Write-Host ''
    Write-Host '  Please enter the full path to Overwolf.exe:' -ForegroundColor Yellow
    Write-Host '  E.g. C:\Program Files (x86)\Overwolf\Overwolf.exe' -ForegroundColor DarkGray
    Write-Host ''
    do {
        $input_path = (Read-Host '  Path').Trim().Trim('"')
        if (-not (Test-Path $input_path)) {
            Write-Host "  [!] Path not found. Try again." -ForegroundColor Red
            $input_path = $null
        }
    } while (-not $input_path)
    $foundOW = $input_path
}

Write-Host ''
Write-Host '  OK: ' -ForegroundColor Green -NoNewline
Write-Host $foundOW

# ─────────────────────────────────────────────────────────────────────────────
#  Step 2 — Find Rainbow Six Siege Exe
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Rule
Write-Step '2/4' 'Searching for RainbowSix.exe...'
Write-Host ''

$r6Exe = Find-RainbowSixExe

if ($r6Exe) {
    Write-Host '  Found: ' -ForegroundColor DarkGray -NoNewline
    Write-Host $r6Exe -ForegroundColor Green
    Write-Host ''
    $confirmR6 = Get-Confirmation '  Is this correct? [y/n]'
    if (-not $confirmR6) {
        $r6Exe = $null
    }
}

if (-not $r6Exe) {
    Write-Host ''
    Write-Host '  Please enter the full path to RainbowSix.exe:' -ForegroundColor Yellow
    Write-Host '  E.g. C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Tom Clancy''s Rainbow Six Siege\RainbowSix.exe' -ForegroundColor DarkGray
    Write-Host ''
    do {
        $input_path = (Read-Host '  Path').Trim().Trim('"')
        if (-not (Test-Path $input_path)) {
            Write-Host "  [!] Path not found. Try again." -ForegroundColor Red
            $input_path = $null
        }
    } while (-not $input_path)
    $r6Exe = $input_path
}

Write-Host ''
Write-Host '  OK: ' -ForegroundColor Green -NoNewline
Write-Host $r6Exe

# ─────────────────────────────────────────────────────────────────────────────
#  Step 3 — Shortcuts & Icon
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Rule
Write-Step '3/4' 'Shortcuts & Icon Creation'
Write-Host ''

$createDesktop = Get-Confirmation '  Create shortcut on the Desktop? [y/n]'
$createStart   = Get-Confirmation '  Create shortcut in the Start Menu? [y/n]'

if ($createDesktop -or $createStart) {
    $userDesktop = Get-UserDesktopPath
    $userPrograms = Get-UserProgramsPath
    
    $desktopPath = [System.IO.Path]::Combine($userDesktop, 'Tom Clancy''s Rainbow Six Siege.lnk')
    $startMenuPath = [System.IO.Path]::Combine($userPrograms, 'Tom Clancy''s Rainbow Six Siege.lnk')
    $batPath = Join-Path $ScriptDir 'Avvia_R6.bat'
    
    if ($createDesktop) {
        Write-Host ''
        Write-Host '  Creating Desktop shortcut...' -ForegroundColor Gray
        $ok = Create-Shortcut -Target $batPath -Path $desktopPath -IconPath $r6Exe
        if ($ok) {
            Write-Host '  [OK] Desktop shortcut created!' -ForegroundColor Green
        } else {
            Write-Host '  [ERR] Failed to create Desktop shortcut.' -ForegroundColor Red
        }
    }
    
    if ($createStart) {
        Write-Host ''
        Write-Host '  Creating Start Menu shortcut...' -ForegroundColor Gray
        if (-not (Test-Path $userPrograms)) {
            New-Item -ItemType Directory -Path $userPrograms -Force | Out-Null
        }
        $ok = Create-Shortcut -Target $batPath -Path $startMenuPath -IconPath $r6Exe
        if ($ok) {
            Write-Host '  [OK] Start Menu shortcut created!' -ForegroundColor Green
        } else {
            Write-Host '  [ERR] Failed to create Start Menu shortcut.' -ForegroundColor Red
        }
    }
} else {
    Write-Host ''
    Write-Host '  Skipped shortcut creation (no shortcuts selected).' -ForegroundColor Gray
}

# ─────────────────────────────────────────────────────────────────────────────
#  Step 4 — Save to config.ini
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Rule
Write-Step '4/4' 'Saving to config.ini...'
Write-Host ''

Update-IniValue -Path $ConfigPath -Key 'OVERWOLF_PATH' -Value $foundOW
Update-IniValue -Path $ConfigPath -Key 'GAME_EXE_PATH'  -Value $r6Exe

Write-Host '  [OK] config.ini updated.' -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Rule
Write-Host '  Setup complete!' -ForegroundColor Green
Write-Rule
Write-Host ''
Write-Host "  Overwolf : $foundOW" -ForegroundColor White
Write-Host "  Game Path: $r6Exe" -ForegroundColor White
Write-Host ''
Write-Host '  You can now run the game via the created shortcuts or Avvia_R6.bat.' -ForegroundColor Cyan
Write-Host ''

Read-Host 'Press ENTER to exit'
