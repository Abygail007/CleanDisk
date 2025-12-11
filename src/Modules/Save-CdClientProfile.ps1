function Save-CdClientProfile {
    <#
        .SYNOPSIS
        Sauvegarde un profil client pour reutilisation ulterieure.
        
        .PARAMETER ClientInfo
        Hashtable contenant Societe, Site, Ville, Technicien.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ClientInfo
    )

    try {
        $root = Get-CdRootDirectory
        $clientsDir = Join-Path $root 'Config\Clients'
        
        if (-not (Test-Path $clientsDir)) {
            New-Item -ItemType Directory -Path $clientsDir -Force | Out-Null
        }
        
        # Verifier que Societe est renseignee
        if (-not $ClientInfo.Societe -or $ClientInfo.Societe.Trim() -eq "") {
            Write-Warning "[Save-CdClientProfile] Societe vide, profil non sauvegarde."
            return $null
        }
        
        # Creer un nom de fichier securise
        $safeName = $ClientInfo.Societe -replace '[^a-zA-Z0-9_\-]', '_'
        $safeName = $safeName.Substring(0, [Math]::Min(50, $safeName.Length))
        
        # Chercher un nom unique
        $index = 1
        $fileName = "$safeName.json"
        $filePath = Join-Path $clientsDir $fileName
        
        while (Test-Path $filePath) {
            $fileName = "${safeName}_${index}.json"
            $filePath = Join-Path $clientsDir $fileName
            $index++
            
            if ($index -gt 100) {
                Write-Warning "[Save-CdClientProfile] Trop de profils pour ce client."
                break
            }
        }
        
        # Sauvegarder en JSON
        $profileData = @{
            Societe    = $ClientInfo.Societe
            Site       = $ClientInfo.Site
            Ville      = $ClientInfo.Ville
            Technicien = $ClientInfo.Technicien
            DateCreation = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        $profileData | ConvertTo-Json | Out-File -FilePath $filePath -Encoding UTF8 -Force
        
        Write-Verbose "[Save-CdClientProfile] Profil sauvegarde : $filePath"
        return $filePath
    }
    catch {
        Write-Warning "[Save-CdClientProfile] Erreur : $_"
        return $null
    }
}
