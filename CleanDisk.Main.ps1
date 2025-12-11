#requires -version 5.1
<#
.SYNOPSIS
    CleanDisk - Outil de nettoyage et formatage de disques

.DESCRIPTION
    Script principal qui lance l'interface WPF de CleanDisk.
    Gère automatiquement l'élévation UAC et le mode STA.

.NOTES
    Auteur: Jean-Mickael Thomas (LOGICIA INFORMATIQUE)
    Version: 0.2
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# --- Auto-élévation (UAC) + STA obligatoire ---
$curr  = [Security.Principal.WindowsIdentity]::GetCurrent()
$princ = [Security.Principal.WindowsPrincipal]::new($curr)
$needAdmin = -not $princ.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$needSta   = ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA')

if ($needAdmin -or $needSta) {
    Write-Host "Relance du script avec les droits administrateur et en mode STA..." -ForegroundColor Yellow
    
    $psExe = Join-Path $PSHOME 'powershell.exe'
    $self  = if ($PSCommandPath) { 
        $PSCommandPath 
    } elseif ($MyInvocation.MyCommand.Path) { 
        $MyInvocation.MyCommand.Path 
    } else { 
        $null 
    }
    
    if (-not $self) { 
        throw "Impossible d'identifier le chemin du script pour la relance."
    }
    
    $args  = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', $self)
    $verb  = if ($needAdmin) { 'RunAs' } else { 'Open' }
    
    Start-Process -FilePath $psExe `
                  -ArgumentList $args `
                  -Verb $verb `
                  -WorkingDirectory (Split-Path -Path $self -Parent) | Out-Null
    exit
}

# À partir d'ici, on est en mode Administrateur + STA

# On part du principe que ce script est dans le dossier racine du projet
$scriptRoot = Split-Path -Parent $PSCommandPath
$modulesPath = Join-Path $scriptRoot 'src\Modules'
$loaderPath  = Join-Path $modulesPath 'CleanDisk.Loader.ps1'

if (-not (Test-Path -LiteralPath $loaderPath)) {
    Write-Error "Script de chargement introuvable : $loaderPath"
    exit 1
}

# On "dot-source" le loader (comme un .ps1 classique) pour disposer des helpers (chemins, logs, etc.)
. $loaderPath

# Initialise le projet (chemins globaux, dossier Logs, etc.)
Initialize-CdProject -RootPath $scriptRoot

# Charge explicitement toutes les fonctions (un fichier .ps1 = une fonction)
$srcPath = Join-Path $scriptRoot 'src'

$scriptFiles = Get-ChildItem -Path $srcPath -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($file in $scriptFiles) {
    # On évite de recharger le Main lui-même (il n'est pas dans src de toute façon, mais par sécurité)
    if ($file.FullName -ne $PSCommandPath) {
        try {
            . $file.FullName
        }
        catch {
            Write-Warning "Impossible de charger $($file.FullName) : $_"
        }
    }
}

# Vérifie que la fonction Show-CdMainWindow est bien chargée
if (-not (Get-Command Show-CdMainWindow -ErrorAction SilentlyContinue)) {
    Write-Error "La fonction Show-CdMainWindow n'a pas été chargée. Vérifie src\UI\Show-CdMainWindow.ps1."
    exit 1
}

# Lance l'interface principale
Show-CdMainWindow
