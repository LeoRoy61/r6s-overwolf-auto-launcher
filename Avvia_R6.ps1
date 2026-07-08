#Requires -Version 5.1
<#
.SYNOPSIS
    R6 + Overwolf Launcher

.DESCRIPTION
    Launches Overwolf before Rainbow Six Siege, monitors the game process,
    and cleanly closes Overwolf when the game session ends.

    All settings are read from config.ini in the same directory.
    Run setup.bat (or setup.ps1) once to configure paths automatically.

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
#  Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

function Read-IniFile {
    <#
    .SYNOPSIS Parses a simple KEY=VALUE .ini file, skipping ; comments and [sections].
    #>
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
    <#
    .SYNOPSIS Rewrites a single KEY=VALUE pair in a .ini file in-place.
    #>
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
    <#
    .SYNOPSIS
        Searches for Overwolf.exe using the Windows Registry first,
        then by scanning fixed drives for common installation paths.
    .OUTPUTS
        Full path to Overwolf.exe, or $null if not found.
    #>

    # 1. Windows Registry (most reliable — set by the Overwolf installer)
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

    # 2. Scan all fixed (non-removable) drives for common install locations
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

function Write-Msg {
    <#
    .SYNOPSIS Writes a colored status message to the console.
    #>
    param(
        [string]$Text,
        [ValidateSet('info','ok','warn','err','dim')]
        [string]$Kind = 'info'
    )
    $colors = @{ info='Cyan'; ok='Green'; warn='Yellow'; err='Red'; dim='DarkGray' }
    Write-Host $Text -ForegroundColor $colors[$Kind]
}

function Write-Rule {
    Write-Host ('=' * 53) -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
#  Load & Validate Configuration
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $ConfigPath)) {
    Write-Msg "[ERROR] config.ini not found: $ConfigPath" 'err'
    Write-Msg 'Run setup.bat first to configure the launcher.' 'warn'
    Read-Host 'Press ENTER to exit'
    exit 1
}

$cfg = Read-IniFile -Path $ConfigPath

# Read values with safe defaults
$OverwolfPath    =        $cfg['OVERWOLF_PATH']
$GameExePath     =        $cfg['GAME_EXE_PATH']
$GameLaunchUrl   =        $cfg['GAME_LAUNCH_URL']
$GameProcess     =       ($cfg['GAME_PROCESS']          -replace '\.exe$', '')
$OWProcessNames  = ($cfg['OVERWOLF_PROCESSES'] -split ',') |
                   ForEach-Object { $_.Trim() -replace '\.exe$', '' } |
                   Where-Object { $_ -ne '' }
$OWInitDelay     = if ($cfg['OVERWOLF_INIT_DELAY'])    { [int]$cfg['OVERWOLF_INIT_DELAY'] }    else { 3 }
$MonitorInterval = if ($cfg['MONITOR_INTERVAL'])       { [int]$cfg['MONITOR_INTERVAL'] }       else { 10 }
$AbsenceThresh   = if ($cfg['ABSENCE_THRESHOLD'])      { [int]$cfg['ABSENCE_THRESHOLD'] }      else { 5 }
$WaitInterval    = if ($cfg['WAIT_START_INTERVAL'])    { [int]$cfg['WAIT_START_INTERVAL'] }    else { 2 }
$MaxAttempts     = if ($cfg['MAX_START_ATTEMPTS'])     { [int]$cfg['MAX_START_ATTEMPTS'] }     else { 90 }

# ─────────────────────────────────────────────────────────────────────────────
#  Language Strings (Defaulting to English)
# ─────────────────────────────────────────────────────────────────────────────

$L = @{
    Title      = '  GAME LAUNCHER: RAINBOW SIX SIEGE + OVERWOLF'
    Step1      = '[1/3] Starting Overwolf in background...'
    Step2      = "[2/3] Waiting $OWInitDelay seconds for Overwolf to initialize..."
    Step3      = '[3/3] Launching Rainbow Six Siege via Ubisoft Connect...'
    Wait       = "[i] Waiting for $($cfg['GAME_PROCESS']) to start..."
    Detected   = "[OK] $($cfg['GAME_PROCESS']) detected. Starting monitoring loop."
    Timeout    = "[!] Timeout: game did not start within $($MaxAttempts * $WaitInterval)s."
    CloseOW    = '[!] Closing Overwolf processes...'
    Absent     = '[!] Process not detected.'
    Restore    = '[i] Process active again. Monitoring restored.'
    Prolonged  = '[!] Extended closure of game detected.'
    Done       = '[OK] Processes terminated successfully.'
    AbsCtrl    = '[!] Absence check'
    Of         = 'of'
    AutoFind   = '[*] Overwolf path in config is invalid. Searching automatically...'
    OWFound    = '[OK] Overwolf found: '
    OWNotFound = "[!] Overwolf not found automatically.`n    Please run setup.bat to configure manually."
    AutoFindR6 = '[*] Rainbow Six path in config is invalid. Searching automatically...'
    R6Found    = '[OK] Rainbow Six found: '
    R6NotFound = "[!] RainbowSix.exe not found automatically.`n    Please run setup.bat to configure manually."
    AskSetup   = 'Open setup.bat now? [Y/n]: '
    Saved      = '[i] Path saved automatically to config.ini.'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Validate / Auto-detect Overwolf Path
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $OverwolfPath -ErrorAction SilentlyContinue)) {
    Write-Msg $L.AutoFind 'warn'
    $found = Find-OverwolfExe
    if ($found) {
        $OverwolfPath = $found
        Write-Msg ($L.OWFound + $found) 'ok'
        Update-IniValue -Path $ConfigPath -Key 'OVERWOLF_PATH' -Value $found
        Write-Msg $L.Saved 'info'
        Write-Host ''
    } else {
        Write-Msg $L.OWNotFound 'err'
        $ans = Read-Host $L.AskSetup
        if ($ans -ine 'n') {
            Start-Process -FilePath (Join-Path $ScriptDir 'setup.bat')
        }
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Validate / Auto-detect Rainbow Six Path
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $GameExePath -ErrorAction SilentlyContinue)) {
    Write-Msg $L.AutoFindR6 'warn'
    $foundR6 = Find-RainbowSixExe
    if ($foundR6) {
        $GameExePath = $foundR6
        Write-Msg ($L.R6Found + $foundR6) 'ok'
        Update-IniValue -Path $ConfigPath -Key 'GAME_EXE_PATH' -Value $foundR6
        Write-Msg $L.Saved 'info'
        Write-Host ''
    } else {
        Write-Msg $L.R6NotFound 'err'
        $ans = Read-Host $L.AskSetup
        if ($ans -ine 'n') {
            Start-Process -FilePath (Join-Path $ScriptDir 'setup.bat')
        }
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Launch Sequence
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Rule
Write-Host $L.Title -ForegroundColor Cyan
Write-Rule
Write-Host ''

Write-Msg $L.Step1 'info'
Start-Process -FilePath $OverwolfPath

Write-Msg $L.Step2 'info'
Start-Sleep -Seconds $OWInitDelay

Write-Msg $L.Step3 'info'
Start-Process -FilePath $GameLaunchUrl

Write-Host ''
Write-Msg $L.Wait 'info'

# ─────────────────────────────────────────────────────────────────────────────
#  Wait for Game to Start
# ─────────────────────────────────────────────────────────────────────────────

$gameStarted = $false
for ($i = 0; $i -lt $MaxAttempts; $i++) {
    Start-Sleep -Seconds $WaitInterval
    if (Get-Process -Name $GameProcess -ErrorAction SilentlyContinue) {
        Write-Msg $L.Detected 'ok'
        $gameStarted = $true
        break
    }
    Write-Host "  [i] $($i + 1) / $MaxAttempts" -ForegroundColor DarkGray
}

if (-not $gameStarted) {
    Write-Msg $L.Timeout 'warn'
}

# ─────────────────────────────────────────────────────────────────────────────
#  Game Monitoring Loop
# ─────────────────────────────────────────────────────────────────────────────

if ($gameStarted) {
    $absenceCount = 0
    while ($true) {
        Start-Sleep -Seconds $MonitorInterval
        if (Get-Process -Name $GameProcess -ErrorAction SilentlyContinue) {
            if ($absenceCount -gt 0) {
                Write-Msg $L.Restore 'ok'
                $absenceCount = 0
            }
        } else {
            $absenceCount++
            Write-Msg "$($L.AbsCtrl) $absenceCount $($L.Of) $AbsenceThresh..." 'warn'
            if ($absenceCount -ge $AbsenceThresh) {
                Write-Host ''
                Write-Msg $L.Prolonged 'warn'
                break
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Close Overwolf
# ─────────────────────────────────────────────────────────────────────────────

Write-Msg $L.CloseOW 'warn'

foreach ($name in $OWProcessNames) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Msg "  OK: $name chiuso / closed" 'ok'
    }
}

Write-Msg $L.Done 'ok'
Start-Sleep -Seconds 3
