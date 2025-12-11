function Save-CdTechnicianProfile {
    <#
        .SYNOPSIS
        Sauvegarde un nouveau technicien dans la base de donnees.

        .DESCRIPTION
        Cree un fichier JSON pour le technicien dans Config\Technicians.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NomComplet,

        [Parameter(Mandatory = $false)]
        [string]$Email = ""
    )

    try {
        $root = Get-CdRootDirectory
        $techPath = Join-Path $root 'Config\Technicians'

        if (-not (Test-Path -LiteralPath $techPath)) {
            New-Item -ItemType Directory -Path $techPath -Force | Out-Null
        }

        # Separer prenom et nom
        $parts = $NomComplet.Trim() -split '\s+', 2
        $prenom = if ($parts.Count -ge 1) { $parts[0] } else { "" }
        $nom = if ($parts.Count -ge 2) { $parts[1] } else { "" }

        # Creer un nom de fichier valide
        $safeName = $NomComplet -replace '[^\w\s-]', '' -replace '\s+', '_'
        $fileName = "$safeName.json"
        $filePath = Join-Path $techPath $fileName

        # Verifier si le technicien existe deja
        if (Test-Path -LiteralPath $filePath) {
            Write-Verbose "[Save-CdTechnicianProfile] Technicien deja existant : $NomComplet"
            return $filePath
        }

        # Creer l'objet technicien
        $tech = @{
            Nom      = $nom
            Prenom   = $prenom
            NomComplet = $NomComplet
            Email    = $Email
            DateCreation = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        # Sauvegarder en JSON
        $tech | ConvertTo-Json -Depth 3 | Out-File -FilePath $filePath -Encoding UTF8 -Force

        Write-Verbose "[Save-CdTechnicianProfile] Technicien sauvegarde : $filePath"
        return $filePath
    }
    catch {
        Write-Error "[Save-CdTechnicianProfile] Erreur : $_"
        return $null
    }
}
