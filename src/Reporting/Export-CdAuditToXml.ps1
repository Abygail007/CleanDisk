function Export-CdAuditToXml {
    <#
        .SYNOPSIS
        Exporte les enregistrements d'audit de nettoyage dans un fichier XML.

        .DESCRIPTION
        Le fichier est sauvegardé dans le dossier Logs du projet sous le nom JournalNettoyage.xml.
        Ce XML servira de base pour les exports HTML / PDF / certificats.
    #>
    [CmdletBinding()]
    param()

    if (-not $global:CdAuditRecords -or $global:CdAuditRecords.Count -eq 0) {
        return
    }

    # Récupération du dossier de logs
    $rootPath = if ($global:CdRootPath) { $global:CdRootPath } else { Get-CdRootDirectory }
    $logsPath = if ($global:CdLogsPath) { $global:CdLogsPath } else { Get-CdLogsDirectory -RootPath $rootPath }

    if (-not (Test-Path -LiteralPath $logsPath)) {
        try {
            New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
        }
        catch {
            Write-Warning ("[Export-CdAuditToXml] Impossible de créer le dossier de logs : {0}" -f $_)
            return
        }
    }

    # Fichier XML d'audit de la session
    if ($global:CdAuditFilePath) {
        $xmlPath = $global:CdAuditFilePath
    }
    else {
        $xmlPath = Join-Path $logsPath 'CleanDiskAudit.xml'
    }


    # Construction du XML
    $xml = New-Object System.Xml.XmlDocument

    $decl = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $xml.AppendChild($decl) | Out-Null

    $root = $xml.CreateElement("CleanDiskAudit")
    $xml.AppendChild($root) | Out-Null

    foreach ($r in $global:CdAuditRecords) {
        $diskNode = $xml.CreateElement("Disk")

        foreach ($name in $r.PSObject.Properties.Name) {
            $value = [string]$r.$name
            $child = $xml.CreateElement($name)
            $child.InnerText = $value
            [void]$diskNode.AppendChild($child)
        }

        [void]$root.AppendChild($diskNode)
    }

    try {
        $xml.Save($xmlPath)
    }
    catch {
        Write-Warning ("[Export-CdAuditToXml] Impossible d'enregistrer le XML : {0}" -f $_)
    }
}
