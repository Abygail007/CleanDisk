function Get-CdClientProfiles {
    <#
        .SYNOPSIS
        Recupere tous les profils clients sauvegardes.
        
        .OUTPUTS
        Tableau d'objets contenant les profils clients.
    #>
    [CmdletBinding()]
    param()

    try {
        $root = Get-CdRootDirectory
        $clientsDir = Join-Path $root 'Config\Clients'
        
        if (-not (Test-Path $clientsDir)) {
            Write-Verbose "[Get-CdClientProfiles] Aucun profil client trouve."
            return @()
        }
        
        $profiles = @()
        $jsonFiles = Get-ChildItem -Path $clientsDir -Filter "*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $jsonFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                
                $profile = [PSCustomObject]@{
                    FileName     = $file.Name
                    FilePath     = $file.FullName
                    Societe      = $content.Societe
                    Site         = $content.Site
                    Ville        = $content.Ville
                    Technicien   = $content.Technicien
                    DateCreation = $content.DateCreation
                }
                
                $profiles += $profile
            }
            catch {
                Write-Warning "[Get-CdClientProfiles] Erreur lecture $($file.Name) : $_"
            }
        }
        
        # Dedoublonner par nom de societe (garder le plus recent)
        $uniqueProfiles = $profiles | Group-Object -Property Societe | ForEach-Object {
            $_.Group | Sort-Object -Property DateCreation -Descending | Select-Object -First 1
        }

        Write-Verbose "[Get-CdClientProfiles] $(@($uniqueProfiles).Count) profils uniques charges."
        return @($uniqueProfiles)
    }
    catch {
        Write-Warning "[Get-CdClientProfiles] Erreur : $_"
        return @()
    }
}
