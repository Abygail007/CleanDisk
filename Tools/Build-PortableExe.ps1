# Tools/Build-PortableExe.ps1
# Compile CleanDisk en un EXE portable autonome avec TOUT embarque
# Usage: .\Tools\Build-PortableExe.ps1

[CmdletBinding()]
param(
    [string]$Version = "1.0.0.0",
    [switch]$KeepMergedScript
)

$ErrorActionPreference = 'Stop'

# === CONFIGURATION ===
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildFolder = Join-Path $projectRoot 'Build'
$mergedScript = Join-Path $buildFolder 'CleanDisk.Merged.ps1'
$exePath = Join-Path $buildFolder 'CleanDisk.exe'
$iconPath = Join-Path $projectRoot 'logo-logicia.ico'

# Creer dossier Build
if (-not (Test-Path $buildFolder)) {
    New-Item -Path $buildFolder -ItemType Directory -Force | Out-Null
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "            CLEANDISK - BUILD EXE PORTABLE                      " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# === ETAPE 1: LIRE LE XAML ===
Write-Host "[1/6] Lecture du XAML..." -ForegroundColor Yellow
$xamlPath = Join-Path $projectRoot 'src\UI\CleanDisk.xaml'
$xamlContent = Get-Content $xamlPath -Raw -Encoding UTF8

# Lire aussi le XAML ClientDetails
$xamlClientDetailsPath = Join-Path $projectRoot 'src\UI\ClientDetailsWindow.xaml'
$xamlClientDetailsContent = ""
if (Test-Path $xamlClientDetailsPath) {
    $xamlClientDetailsContent = Get-Content $xamlClientDetailsPath -Raw -Encoding UTF8
}

$xamlSizeKB = [int]($xamlContent.Length / 1024)
Write-Host "      OK - XAML lu ($xamlSizeKB KB)" -ForegroundColor Green

# === ETAPE 2: DEFINIR L'ORDRE DES FICHIERS ===
Write-Host "[2/6] Fusion des modules..." -ForegroundColor Yellow

# Ordre important : d'abord les modules de base, puis les fonctions core, puis UI
$modulesOrder = @(
    # Modules de base (helpers, logging)
    'src\Modules\CleanDisk.Loader.ps1',
    'src\Modules\Write-CdErrorLog.ps1',
    'src\Modules\Invoke-CdWithRetry.ps1',
    'src\Modules\Get-CdClientProfiles.ps1',
    'src\Modules\Save-CdClientProfile.ps1',
    'src\Modules\Get-CdTechnicianProfiles.ps1',
    'src\Modules\Save-CdTechnicianProfile.ps1',

    # Core - System
    'src\Core\System\Set-CdSessionInfo.ps1',
    'src\Core\System\Enter-CdNoSleep.ps1',
    'src\Core\System\Exit-CdNoSleep.ps1',
    'src\Core\System\Enable-CdBitLockerEncryption.ps1',

    # Core - Disk
    'src\Core\Disk\Get-CdDiskList.ps1',
    'src\Core\Disk\Get-CdDiskSerial.ps1',
    'src\Core\Disk\Invoke-CdDiskWipe.ps1',
    'src\Core\Disk\Invoke-CdDiskWipeAndFormat.ps1',
    'src\Core\Disk\Invoke-CdDiskPartitionAndFormat.ps1',
    'src\Core\Disk\Invoke-CdDiskEject.ps1',

    # Reporting
    'src\Reporting\Add-CdDiskAuditRecord.ps1',
    'src\Reporting\Export-CdAuditToXml.ps1',
    'src\Reporting\Convert-CdAuditToHtml.ps1',
    'src\Reporting\Convert-CdHtmlToPdf.ps1',
    'src\Reporting\New-CdCertificatePdf.ps1',
    'src\Reporting\New-CdInternalReport.ps1',
    'src\Reporting\New-CdDashboard.ps1',
    'src\Reporting\New-CdClientHistory.ps1',

    # UI
    'src\UI\Show-CdEditSerialWindow.ps1',
    'src\UI\Show-CdClientDetailsWindow.ps1',
    'src\UI\Show-CdMainWindow.ps1'
)

# === ETAPE 3: CONSTRUIRE LE SCRIPT FUSIONNE ===
$headerContent = @"
# ================================================================================
# CLEANDISK - VERSION PORTABLE
# Ce fichier est genere automatiquement par Build-PortableExe.ps1
# NE PAS MODIFIER MANUELLEMENT
# Version: $Version
# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Auteur: Jean-Mickael Thomas (LOGICIA INFORMATIQUE)
# ================================================================================

#requires -version 5.1

`$ErrorActionPreference = 'Stop'

# === MARQUEUR MODE PORTABLE ===
`$script:IsPortableMode = `$true
`$script:PortableVersion = '$Version'

# === XAML EMBARQUE ===
`$script:EmbeddedXAML = @'
$xamlContent
'@

# === XAML CLIENT DETAILS EMBARQUE ===
`$script:EmbeddedClientDetailsXAML = @'
$xamlClientDetailsContent
'@

"@

$mergedContent = $headerContent

# Lire et fusionner chaque module
$moduleCount = 0
foreach ($modulePath in $modulesOrder) {
    $fullPath = Join-Path $projectRoot $modulePath
    if (Test-Path $fullPath) {
        $moduleContent = Get-Content $fullPath -Raw -Encoding UTF8

        $moduleName = Split-Path $modulePath -Leaf
        $mergedContent += @"

# ================================================================================
# MODULE: $moduleName
# ================================================================================

$moduleContent

"@
        $moduleCount++
        Write-Host "      + $moduleName" -ForegroundColor DarkGray
    } else {
        Write-Host "      X $modulePath non trouve!" -ForegroundColor Red
    }
}

Write-Host "      OK - $moduleCount modules fusionnes" -ForegroundColor Green

# === ETAPE 4: AJOUTER LE CODE PRINCIPAL ===
Write-Host "[3/6] Ajout du code principal..." -ForegroundColor Yellow

$mainCode = @'

# ================================================================================
# POINT D'ENTREE PRINCIPAL - MODE PORTABLE
# ================================================================================

# ===== ELEVATION ADMIN AUTOMATIQUE + STA =====
$curr  = [Security.Principal.WindowsIdentity]::GetCurrent()
$princ = [Security.Principal.WindowsPrincipal]::new($curr)
$needAdmin = -not $princ.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$needSta   = ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA')

if ($needAdmin -or $needSta) {
    $exePath = [Environment]::GetCommandLineArgs()[0]
    $psExe = Join-Path $PSHOME 'powershell.exe'

    # Pour un EXE compile, on relance l'EXE directement
    if ($exePath -match '\.exe$') {
        $args = @()
        $verb = if ($needAdmin) { 'RunAs' } else { 'Open' }
        Start-Process -FilePath $exePath -ArgumentList $args -Verb $verb | Out-Null
    } else {
        # Mode script
        $args = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', $exePath)
        $verb = if ($needAdmin) { 'RunAs' } else { 'Open' }
        Start-Process -FilePath $psExe -ArgumentList $args -Verb $verb | Out-Null
    }
    exit
}

# ===== DETECTION DU DOSSIER RACINE =====
$exePath = [Environment]::GetCommandLineArgs()[0]
$ScriptRoot = Split-Path -Parent $exePath
if (-not $ScriptRoot -or $ScriptRoot -eq '') {
    $ScriptRoot = (Get-Location).Path
}

Set-Location $ScriptRoot

# ===== INITIALISATION DU PROJET =====
# En mode portable, on initialise directement sans le Loader
$Global:CdRootPath = $ScriptRoot
$Global:CdLogsPath = Join-Path $ScriptRoot 'Logs'
$Global:CdConfigPath = Join-Path $ScriptRoot 'Config'

# Creer les dossiers necessaires
@($Global:CdLogsPath, $Global:CdConfigPath, (Join-Path $Global:CdConfigPath 'Clients')) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Fonction Get-CdRootDirectory pour compatibilite
function Get-CdRootDirectory { return $Global:CdRootPath }

# ===== LANCER L'UI =====
Show-CdMainWindow
'@

$mergedContent += $mainCode

Write-Host "      OK" -ForegroundColor Green

# === ETAPE 5: SAUVEGARDER LE SCRIPT FUSIONNE ===
Write-Host "[4/6] Sauvegarde du script fusionne..." -ForegroundColor Yellow

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($mergedScript, $mergedContent, $utf8NoBom)

$mergedSize = [int]((Get-Item $mergedScript).Length / 1024)
Write-Host "      OK - $mergedScript ($mergedSize KB)" -ForegroundColor Green

# === ETAPE 6: COMPILATION AVEC PS2EXE ===
Write-Host "[5/6] Compilation avec PS2EXE..." -ForegroundColor Yellow

$ps2exeModule = Get-Module -ListAvailable -Name ps2exe
if (-not $ps2exeModule) {
    Write-Host "      Module ps2exe non installe. Installation..." -ForegroundColor DarkYellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force
        Import-Module ps2exe
    }
    catch {
        Write-Host "      ERREUR - Impossible d'installer ps2exe: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "      Installation manuelle requise:" -ForegroundColor Yellow
        Write-Host "      Install-Module -Name ps2exe -Scope CurrentUser" -ForegroundColor White
        exit 1
    }
}

Import-Module ps2exe -ErrorAction Stop

if (Test-Path $exePath) {
    Remove-Item $exePath -Force
}

try {
    $ps2exeParams = @{
        inputFile   = $mergedScript
        outputFile  = $exePath
        noConsole   = $true
        STA         = $true
        requireAdmin = $true
        title       = 'CleanDisk'
        product     = 'CleanDisk'
        company     = 'Logicia / Jean-Mickael Thomas'
        version     = $Version
        copyright   = "(c) $(Get-Date -Format 'yyyy') Logicia Informatique"
        description = 'Outil de nettoyage et formatage securise de disques'
    }

    if (Test-Path $iconPath) {
        $ps2exeParams.iconFile = $iconPath
        Write-Host "      Icone: $iconPath" -ForegroundColor DarkGray
    }

    Invoke-ps2exe @ps2exeParams

    Write-Host "      OK - Compilation reussie!" -ForegroundColor Green
}
catch {
    Write-Host "      ERREUR - Compilation: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# === ETAPE 7: NETTOYAGE ===
if (-not $KeepMergedScript) {
    Write-Host "[6/6] Nettoyage..." -ForegroundColor Yellow
    Remove-Item $mergedScript -Force -ErrorAction SilentlyContinue
    Write-Host "      OK - Script temporaire supprime" -ForegroundColor Green
} else {
    Write-Host "[6/6] Script fusionne conserve pour debug" -ForegroundColor DarkGray
    Write-Host "      -> $mergedScript" -ForegroundColor DarkGray
}

# === RESULTAT FINAL ===
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                    COMPILATION TERMINEE                        " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $exePath) {
    $exeSize = [math]::Round((Get-Item $exePath).Length / 1MB, 2)
    Write-Host "EXE Portable cree: " -NoNewline
    Write-Host $exePath -ForegroundColor Cyan
    Write-Host "Taille: $exeSize MB"
    Write-Host ""
    Write-Host "L'EXE necessite les dossiers Logs et Config a cote de lui." -ForegroundColor Yellow
    Write-Host "Ces dossiers seront crees automatiquement au premier lancement." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "   - Double-clic pour lancer l'interface graphique"
    Write-Host "   - Necessite les droits administrateur (demande automatique)"
} else {
    Write-Host "ERREUR - L'EXE n'a pas ete cree!" -ForegroundColor Red
}
