function Convert-CdAuditToHtml {
    <#
        .SYNOPSIS
        Génère un rapport HTML à partir d'un fichier d'audit CleanDisk (XML).

        .DESCRIPTION
        Le HTML généré sera utilisé ensuite pour produire un certificat / PDF.
        Il est alimenté par :
        - les infos de session (Set-CdSessionInfo) si présentes
        - sinon, les infos du premier disque dans l'audit
        - sinon, des valeurs par défaut (Client / Laval / login).
    #>
    [CmdletBinding()]
    param(
        [string]$XmlPath,
        [string]$HtmlPath
    )

    # Nécessaire pour System.Web.HttpUtility
    try {
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Impossible de charger l'assembly System.Web, l'encodage HTML pourra être limité."
    }

    # Déterminer le XML de session par défaut
    if (-not $XmlPath) {
        if ($global:CdAuditFilePath -and (Test-Path -LiteralPath $global:CdAuditFilePath)) {
            $XmlPath = $global:CdAuditFilePath
        }
        else {
            Write-Error "Aucun fichier XML d'audit trouvé. Lance au moins une opération de nettoyage avant de générer le rapport."
            return
        }
    }

    if (-not (Test-Path -LiteralPath $XmlPath)) {
        Write-Error ("Fichier XML introuvable : {0}" -f $XmlPath)
        return
    }

    # Déterminer le chemin HTML par défaut (même nom que le XML, en .html)
    if (-not $HtmlPath) {
        $directory = Split-Path -Parent $XmlPath
        $name      = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
        $HtmlPath  = Join-Path $directory ("{0}.html" -f $name)
    }

    # Charger le XML
    try {
        [xml]$xmlDoc = Get-Content -LiteralPath $XmlPath -Raw
    }
    catch {
        Write-Error ("Impossible de charger le XML d'audit : {0}" -f $_)
        return
    }

    $diskNodes = $xmlDoc.CleanDiskAudit.Disk
    if (-not $diskNodes) {
        Write-Error "Aucun disque dans le fichier d'audit. Rien à mettre dans le rapport."
        return
    }

    # Infos générales : priorité aux infos de session, puis fallback sur le premier disque, sinon valeurs par défaut
    $today      = Get-Date
    $dateString = $today.ToString("dd/MM/yyyy")

    $firstDisk = $diskNodes[0]

    # Société / client
    if ($global:CdCustomerName) {
        $societe = $global:CdCustomerName
    }
    elseif ($firstDisk.CustomerName) {
        $societe = $firstDisk.CustomerName
    }
    else {
        $societe = "Client"
    }

    # Site
    if ($global:CdSiteName) {
        $site = $global:CdSiteName
    }
    elseif ($firstDisk.SiteName) {
        $site = $firstDisk.SiteName
    }
    else {
        $site = ""
    }

    # Ville
    if ($global:CdCity) {
        $ville = $global:CdCity
    }
    elseif ($firstDisk.City) {
        $ville = $firstDisk.City
    }
    else {
        $ville = "Laval"
    }

    # Technicien
    if ($global:CdTechnicianName) {
        $tech = $global:CdTechnicianName
    }
    elseif ($firstDisk.TechnicianName) {
        $tech = $firstDisk.TechnicianName
    }
    else {
        $tech = $env:USERNAME
    }

    # Construire les lignes du tableau
    $rows = @()
    foreach ($d in $diskNodes) {
        $rows += ("            <tr>" +
                  "<td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td>" +
                  "</tr>") -f `
                  [System.Web.HttpUtility]::HtmlEncode($d.DiskNumber), `
                  [System.Web.HttpUtility]::HtmlEncode($d.Model), `
                  [System.Web.HttpUtility]::HtmlEncode($d.SizeGB), `
                  [System.Web.HttpUtility]::HtmlEncode($d.Bus), `
                  [System.Web.HttpUtility]::HtmlEncode($d.WipeMode), `
                  [System.Web.HttpUtility]::HtmlEncode($d.PreEncryptWithBitLocker)
    }

    $rowsHtml = ($rows -join "`r`n")

    # HTML simple, propre, qui servira de base pour ton modèle final
    $htmlLines = @()
    $htmlLines += '<!DOCTYPE html>'
    $htmlLines += '<html lang="fr">'
    $htmlLines += '<head>'
    $htmlLines += '  <meta charset="utf-8" />'
    $htmlLines += '  <title>Certificat de nettoyage de supports de stockage</title>'
    $htmlLines += '  <style>'
    $htmlLines += '    body { font-family: Arial, sans-serif; font-size: 11pt; margin: 40px; }'
    $htmlLines += '    h1 { font-size: 16pt; margin-bottom: 10px; }'
    $htmlLines += '    h2 { font-size: 13pt; margin-top: 20px; }'
    $htmlLines += '    .entete { margin-bottom: 30px; }'
    $htmlLines += '    .entete strong { display: block; }'
    $htmlLines += '    .coord { font-size: 9pt; }'
    $htmlLines += '    table { border-collapse: collapse; width: 100%; margin-top: 10px; }'
    $htmlLines += '    th, td { border: 1px solid #000; padding: 4px 6px; }'
    $htmlLines += '    th { background-color: #eee; }'
    $htmlLines += '    .signature { margin-top: 40px; }'
    $htmlLines += '  </style>'
    $htmlLines += '</head>'
    $htmlLines += '<body>'
    $htmlLines += '  <div class="entete">'
    $htmlLines += ('    <strong>{0}</strong>' -f [System.Web.HttpUtility]::HtmlEncode($societe))
    $htmlLines += '    <div class="coord">'
    $htmlLines += '      Parc Technopole de Changé<br />'
    $htmlLines += '      Rue Albert Einstein<br />'
    $htmlLines += '      53061 LAVAL Cedex 9<br />'
    $htmlLines += '      Tél. : 02 43 69 90 05<br />'
    $htmlLines += '    </div>'
    $htmlLines += '  </div>'

    $htmlLines += ("  <p>{0}, le {1}</p>" -f [System.Web.HttpUtility]::HtmlEncode($ville), $dateString)
    $htmlLines += '  <h1>Certificat de nettoyage de supports de stockage</h1>'

    $htmlLines += '  <p>'
    $htmlLines += "  Conformément aux recommandations de l'ANSSI (Agence nationale de la sécurité des systèmes d'information),"
    $htmlLines += "  nous attestons que les supports de stockage listés ci-dessous ont fait l'objet d'une procédure de nettoyage"
    $htmlLines += "  réalisée à l'aide de l'outil CleanDisk."
    $htmlLines += '  </p>'

    $htmlLines += '  <h2>Supports traités</h2>'
    $htmlLines += '  <table>'
    $htmlLines += '    <thead>'
    $htmlLines += '      <tr>'
    $htmlLines += '        <th>N° disque</th>'
    $htmlLines += '        <th>Modèle</th>'
    $htmlLines += '        <th>Taille (Go)</th>'
    $htmlLines += '        <th>Bus</th>'
    $htmlLines += '        <th>Mode d''effacement</th>'
    $htmlLines += '        <th>Pré-chiffré BitLocker</th>'
    $htmlLines += '      </tr>'
    $htmlLines += '    </thead>'
    $htmlLines += '    <tbody>'
    $htmlLines += $rowsHtml
    $htmlLines += '    </tbody>'
    $htmlLines += '  </table>'

    $htmlLines += '  <p>'
    $htmlLines += "  Pour chaque support, la procédure d'effacement a été menée à son terme sans erreur signalée par l'outil."
    $htmlLines += '  </p>'

    $htmlLines += '  <div class="signature">'
    $htmlLines += ("    Fait à {0}, le {1}.<br />" -f [System.Web.HttpUtility]::HtmlEncode($ville), $dateString)
    $htmlLines += ("    Pour {0}.<br /><br />" -f [System.Web.HttpUtility]::HtmlEncode($societe))
    $htmlLines += ("    {0}" -f [System.Web.HttpUtility]::HtmlEncode($tech))
    $htmlLines += '  </div>'

    $htmlLines += '</body>'
    $htmlLines += '</html>'

    try {
        $htmlLines -join "`r`n" | Set-Content -LiteralPath $HtmlPath -Encoding UTF8
        Write-Verbose ("Rapport HTML généré : {0}" -f $HtmlPath)
        return $HtmlPath
    }
    catch {
        Write-Error ("Impossible d'enregistrer le rapport HTML : {0}" -f $_)
    }
}
