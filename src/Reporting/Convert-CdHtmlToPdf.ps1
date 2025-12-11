function Convert-CdHtmlToPdf {
    <#
        .SYNOPSIS
        Convertit un fichier HTML en PDF en utilisant wkhtmltopdf.
        
        .DESCRIPTION
        Utilise wkhtmltopdf pour generer un PDF professionnel a partir d'un HTML.
        Si wkhtmltopdf n'est pas disponible, retourne le chemin HTML.
        
        .PARAMETER HtmlPath
        Chemin complet du fichier HTML source.
        
        .PARAMETER PdfPath
        Chemin complet du fichier PDF de sortie (optionnel).
        Si non fourni, remplace .html par .pdf.
        
        .OUTPUTS
        Chemin du fichier genere (PDF si succes, HTML sinon).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlPath,
        
        [Parameter(Mandatory = $false)]
        [string]$PdfPath
    )

    try {
        # Verifier que le fichier HTML existe
        if (-not (Test-Path $HtmlPath)) {
            throw "Fichier HTML introuvable : $HtmlPath"
        }
        
        # Determiner le chemin PDF si non fourni
        if (-not $PdfPath) {
            $PdfPath = [System.IO.Path]::ChangeExtension($HtmlPath, ".pdf")
        }
        
        # Chercher wkhtmltopdf
        $root = Get-CdRootDirectory
        $wkhtmltopdf = Join-Path $root "Tools\wkhtmltopdf.exe"
        
        if (-not (Test-Path $wkhtmltopdf)) {
            Write-Warning "[Convert-CdHtmlToPdf] wkhtmltopdf.exe non trouve dans Tools/"
            Write-Warning "[Convert-CdHtmlToPdf] Telechargez-le sur : https://wkhtmltopdf.org/downloads.html"
            Write-Warning "[Convert-CdHtmlToPdf] Placez wkhtmltopdf.exe dans : $root\Tools\"
            Write-Warning "[Convert-CdHtmlToPdf] Retour du fichier HTML uniquement."
            return $HtmlPath
        }
        
        Write-Verbose "[Convert-CdHtmlToPdf] Conversion HTML -> PDF..."
        Write-Verbose "[Convert-CdHtmlToPdf] Source : $HtmlPath"
        Write-Verbose "[Convert-CdHtmlToPdf] Destination : $PdfPath"
        
        # Convertir les chemins en chemins absolus
        $HtmlPathAbs = (Resolve-Path $HtmlPath).Path
        $PdfPathAbs = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PdfPath)
        
        # Arguments pour wkhtmltopdf
        $arguments = @(
            "--enable-local-file-access"
            "--quiet"
            "--page-size", "A4"
            "--margin-top", "10mm"
            "--margin-bottom", "10mm"
            "--margin-left", "10mm"
            "--margin-right", "10mm"
            "`"$HtmlPathAbs`""
            "`"$PdfPathAbs`""
        )
        
        # Lancer wkhtmltopdf
        $process = Start-Process -FilePath $wkhtmltopdf `
                                 -ArgumentList ($arguments -join " ") `
                                 -Wait `
                                 -NoNewWindow `
                                 -PassThru
        
        if ($process.ExitCode -eq 0 -and (Test-Path $PdfPathAbs)) {
            Write-Verbose "[Convert-CdHtmlToPdf] PDF genere avec succes : $PdfPathAbs"
            return $PdfPathAbs
        }
        else {
            Write-Warning "[Convert-CdHtmlToPdf] Echec conversion PDF (code: $($process.ExitCode))"
            Write-Warning "[Convert-CdHtmlToPdf] Retour du fichier HTML."
            return $HtmlPath
        }
    }
    catch {
        Write-Warning "[Convert-CdHtmlToPdf] Erreur : $_"
        Write-Warning "[Convert-CdHtmlToPdf] Retour du fichier HTML."
        return $HtmlPath
    }
}
