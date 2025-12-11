function Add-CdDiskAuditRecord {
    <#
        .SYNOPSIS
        Ajoute un enregistrement d'audit de nettoyage disque et met à jour le fichier XML.

        .PARAMETER Record
        Objet contenant les informations d'audit (PSCustomObject).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Record
    )

    if (-not $global:CdAuditRecords) {
        $global:CdAuditRecords = @()
    }

    $global:CdAuditRecords += $Record

    # Met immédiatement à jour le fichier XML (simple pour l'instant)
    Export-CdAuditToXml
}
