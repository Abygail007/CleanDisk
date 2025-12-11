function Get-CdTechnicianProfiles {
    <#
        .SYNOPSIS
        Recupere la liste des techniciens enregistres.

        .DESCRIPTION
        Lit les fichiers JSON dans Config\Technicians et retourne
        la liste des techniciens disponibles.
    #>
    [CmdletBinding()]
    param()

    try {
        $root = Get-CdRootDirectory
        $techPath = Join-Path $root 'Config\Technicians'

        if (-not (Test-Path -LiteralPath $techPath)) {
            New-Item -ItemType Directory -Path $techPath -Force | Out-Null
            Write-Verbose "[Get-CdTechnicianProfiles] Dossier Technicians cree : $techPath"
            return @()
        }

        $jsonFiles = Get-ChildItem -Path $techPath -Filter '*.json' -ErrorAction SilentlyContinue

        if ($jsonFiles.Count -eq 0) {
            Write-Verbose "[Get-CdTechnicianProfiles] Aucun technicien trouve."
            return @()
        }

        $technicians = @()
        foreach ($file in $jsonFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
                $tech = $content | ConvertFrom-Json

                $technicians += [PSCustomObject]@{
                    Nom      = $tech.Nom
                    Prenom   = $tech.Prenom
                    NomComplet = "$($tech.Prenom) $($tech.Nom)"
                    Email    = $tech.Email
                    FilePath = $file.FullName
                }
            }
            catch {
                Write-Warning "[Get-CdTechnicianProfiles] Erreur lecture $($file.Name) : $_"
            }
        }

        return $technicians
    }
    catch {
        Write-Error "[Get-CdTechnicianProfiles] Erreur : $_"
        return @()
    }
}
