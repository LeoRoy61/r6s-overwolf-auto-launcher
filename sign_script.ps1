#Requires -Version 5.1
<#
.SYNOPSIS
    Self-signs Avvia_R6.ps1 and setup.ps1 with a local code-signing certificate.

.DESCRIPTION
    Creates a self-signed code signing certificate in your personal certificate store,
    adds it to the Trusted Publishers store (so Windows trusts it), and signs both
    PowerShell scripts.

    After signing, Windows SmartScreen will no longer block these scripts on YOUR PC.
    Other users must either run this script themselves or trust your published certificate.

    For wider distribution, consider a commercial code signing certificate from:
    DigiCert, Sectigo, or GlobalSign (~$100-300/year).

.NOTES
    REQUIRES: Run as Administrator (needed to write to LocalMachine cert store).
    Version : 1.0
    GitHub  : https://github.com/YOUR_USERNAME/r6-overwolf-launcher
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$CertSubject  = 'CN=R6 Overwolf Launcher',
    [int]   $ValidYears   = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-Step {
    param([string]$Text)
    Write-Host ''
    Write-Host ">>> $Text" -ForegroundColor Cyan
}

function Write-Ok ([string]$Text) {
    Write-Host "    [OK] $Text" -ForegroundColor Green
}

function Write-Warn ([string]$Text) {
    Write-Host "    [!]  $Text" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '===================================================' -ForegroundColor DarkGray
Write-Host '  Code Signing — R6 Overwolf Launcher' -ForegroundColor Cyan
Write-Host '===================================================' -ForegroundColor DarkGray

# --- Step 1: Check for existing cert ------------------------------------------
Write-Step 'Checking for existing certificate...'

$existingCert = Get-ChildItem 'Cert:\CurrentUser\My' -CodeSigningCert |
                Where-Object { $_.Subject -eq $CertSubject -and $_.NotAfter -gt (Get-Date) } |
                Select-Object -First 1

if ($existingCert) {
    Write-Ok "Existing certificate found (expires: $($existingCert.NotAfter.ToString('yyyy-MM-dd')))"
    $cert = $existingCert
} else {
    # --- Step 2: Create self-signed certificate --------------------------------
    Write-Step 'Creating self-signed certificate...'

    $cert = New-SelfSignedCertificate `
        -Subject           $CertSubject `
        -KeyUsage          DigitalSignature `
        -Type              CodeSigningCert `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -HashAlgorithm     SHA256 `
        -NotAfter          (Get-Date).AddYears($ValidYears)

    Write-Ok "Certificate created: $($cert.Thumbprint)"
    Write-Ok "Valid until: $($cert.NotAfter.ToString('yyyy-MM-dd'))"
}

# --- Step 3: Add to Trusted Publishers (LocalMachine) -------------------------
Write-Step "Adding to Trusted Publishers (requires Admin)..."

try {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::TrustedPublisher,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    )
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($cert)
    $store.Close()
    Write-Ok 'Certificate successfully added to Trusted Publishers.'
} catch {
    Write-Warn "Unable to add to Trusted Publishers: $_"
    Write-Warn 'The scripts will be signed, but may still show a manual warning prompt.'
}

# --- Step 4: Sign all .ps1 files ---------------------------------------------
Write-Step 'Signing PowerShell scripts...'

$psFiles = Get-ChildItem $ScriptDir -Filter '*.ps1' |
           Where-Object { $_.Name -ne 'sign_script.ps1' }

if ($psFiles.Count -eq 0) {
    Write-Warn 'No .ps1 files found in the directory.'
} else {
    foreach ($file in $psFiles) {
        try {
            $result = Set-AuthenticodeSignature `
                -FilePath    $file.FullName `
                -Certificate $cert `
                -TimestampServer 'http://timestamp.digicert.com'

            if ($result.Status -eq 'Valid') {
                Write-Ok "Successfully signed: $($file.Name)"
            } else {
                Write-Warn "Signature with warnings ($($result.Status)): $($file.Name)"
            }
        } catch {
            Write-Warn "Error signing $($file.Name): $_"
        }
    }
}

# --- Step 5: Export certificate (optional, for sharing) ----------------------
Write-Step 'Exporting public certificate...'

$exportPath = Join-Path $ScriptDir 'r6_launcher_cert.cer'
try {
    $certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    [System.IO.File]::WriteAllBytes($exportPath, $certBytes)
    Write-Ok "Certificate exported: $exportPath"
    Write-Host ''
    Write-Host '    Other users can install this .cer to trust your signed scripts.' -ForegroundColor DarkGray
} catch {
    Write-Warn "Export failed: $_"
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '===================================================' -ForegroundColor DarkGray
Write-Host '  Signing complete!' -ForegroundColor Green
Write-Host '===================================================' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  NOTE: this signature is self-signed.' -ForegroundColor Yellow
Write-Host '  Windows SmartScreen might still prompt other users.' -ForegroundColor Yellow
Write-Host '  For public distribution, consider a commercial certificate.' -ForegroundColor Yellow
Write-Host ''

Read-Host 'Press ENTER to exit'
