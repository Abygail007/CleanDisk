# Script : CleanDisk.Loader.ps1
# Charge toutes les fonctions du projet CleanDisk (un fichier .ps1 = une fonction)

function Get-CdRootDirectory {
    <#
        .SYNOPSIS
        Retourne le dossier racine du projet CleanDisk.
    #>
    try {
        # $PSScriptRoot = ...\src\Modules
        $modulesPath = $PSScriptRoot
        $srcPath     = Split-Path -Path $modulesPath -Parent  # ...\src
        $rootPath    = Split-Path -Path $srcPath -Parent      # ...\New
        return $rootPath
    }
    catch {
        # Fallback : dossier courant
        return (Get-Location).Path
    }
}

function Get-CdLogsDirectory {
    param(
        [string]$RootPath
    )

    if (-not $RootPath) {
        $RootPath = Get-CdRootDirectory
    }

    $logsDir = Join-Path -Path $RootPath -ChildPath 'Logs'
    return $logsDir
}

function Import-CdAllFunctions {
    <#
        .SYNOPSIS
        Charge tous les fichiers .ps1 sous src\ (un fichier = une fonction).
    #>
    param(
        [string]$SrcPath
    )

    if (-not $SrcPath) {
        $root    = Get-CdRootDirectory
        $SrcPath = Join-Path $root 'src'
    }

    if (-not (Test-Path -LiteralPath $SrcPath)) {
        Write-Warning "Dossier src introuvable : $SrcPath"
        return
    }

    $scriptFiles = Get-ChildItem -Path $SrcPath -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue

    foreach ($file in $scriptFiles) {
        try {
            . $file.FullName
        }
        catch {
            Write-Warning ("[Import-CdAllFunctions] Impossible de charger {0} : {1}" -f $file.FullName, $_)
        }
    }
}

function Initialize-CdProject {
    <#
        .SYNOPSIS
        Initialise le projet CleanDisk :
        - Chemins globaux
        - Dossier de logs
        - Chargement de toutes les fonctions (.ps1)
    #>
    param(
        [string]$RootPath
    )

    if (-not $RootPath) {
        $RootPath = Get-CdRootDirectory
    }

    $global:CdRootPath = $RootPath
    $global:CdSrcPath  = Join-Path $RootPath 'src'
    $global:CdLogsPath = Get-CdLogsDirectory -RootPath $RootPath
    $global:CdConfigPath = Join-Path $RootPath 'Config'

    # Création du dossier de logs si besoin
    if (-not (Test-Path -LiteralPath $global:CdLogsPath)) {
        try {
            New-Item -ItemType Directory -Path $global:CdLogsPath -Force | Out-Null
        }
        catch {
            Write-Warning ("[Initialize-CdProject] Impossible de créer le dossier de logs : {0}" -f $_)
        }
    }

    # Nouvelle session d'audit à chaque lancement
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $global:CdSessionId      = $timestamp
    $global:CdAuditFilePath  = Join-Path $global:CdLogsPath ("CleanDiskAudit_{0}.xml" -f $timestamp)
    $global:CdAuditRecords   = @()

    # Chargement de toutes les fonctions (.ps1)
    Import-CdAllFunctions -SrcPath $global:CdSrcPath
}
