function Set-CdSessionInfo {
    <#
        .SYNOPSIS
        Définit les informations de contexte pour la session CleanDisk
        (client, site, ville, technicien).

        .DESCRIPTION
        Ces valeurs seront stockées dans des variables globales et recopiées
        dans chaque enregistrement d'audit de disque. Elles serviront ensuite
        à générer le certificat de blanchiment.
    #>
    [CmdletBinding()]
    param(
        [string]$CustomerName,
        [string]$SiteName,
        [string]$City,
        [string]$TechnicianName
    )

    if ($PSBoundParameters.ContainsKey('CustomerName')) {
        $global:CdCustomerName = $CustomerName
    }

    if ($PSBoundParameters.ContainsKey('SiteName')) {
        $global:CdSiteName = $SiteName
    }

    if ($PSBoundParameters.ContainsKey('City')) {
        $global:CdCity = $City
    }

    if ($PSBoundParameters.ContainsKey('TechnicianName')) {
        $global:CdTechnicianName = $TechnicianName
    }
}
