function New-CdCertificatePdf {
    <#
        .SYNOPSIS
        Génère le certificat PDF officiel pour le client (format LOGICIA).
        
        .PARAMETER DiskRecords
        Liste des enregistrements de disques effacés.
        
        .PARAMETER CustomerInfo
        Hashtable contenant Societe, Site, Ville, Technicien.
        
        .PARAMETER OutputPath
        Chemin du fichier PDF de sortie.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DiskRecords,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CustomerInfo,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    # Déterminer le chemin de sortie
    if (-not $OutputPath) {
        $root = Get-CdRootDirectory
        $logsDir = Join-Path $root 'Logs'
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $safeCustomer = ($CustomerInfo.Societe -replace '[^a-zA-Z0-9]', '_').Substring(0, [Math]::Min(20, $CustomerInfo.Societe.Length))
        $OutputPath = Join-Path $logsDir "Certificat_${safeCustomer}_${timestamp}.pdf"
    }

    # Charger le template HTML
    if (-not $global:CdConfigPath) {
        $root = Get-CdRootDirectory
        $global:CdConfigPath = Join-Path $root 'Config'
    }

    $templatePath = Join-Path $global:CdConfigPath 'Templates\certificat_template.html'
    
    if (-not (Test-Path $templatePath)) {
        Write-Error "Template de certificat introuvable : $templatePath"
        return $null
    }

    $templateHtml = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8

    # Remplacer le chemin relatif de l'image par un chemin absolu
    $imagesDir = Join-Path $global:CdConfigPath 'Templates\images'
    $templateHtml = $templateHtml -replace 'src="images/', "src=`"file:///$($imagesDir -replace '\\','/')/"

    # Préparer les données
    $dateEffacement = Get-Date -Format "dd/MM/yyyy"
    $societe = $CustomerInfo.Societe
    
    # Construire la liste des Serial Numbers au format template LOGICIA
    $snList = '<ul class="c12 lst-kix_2nctsrqzwqbr-0 start">'
    foreach ($record in $DiskRecords) {
        if ($record.Result -eq "Success") {
            $sn = if ($record.Serial) { $record.Serial } else { "(non recupere)" }
            $snList += '<li class="c2 li-bullet-0"><span class="c3">SN : ' + $sn + '</span></li>'
        }
    }
    $snList += '<li class="c2 c16 li-bullet-0"><span class="c3"></span></li></ul>'

    # Remplacer les placeholders dans le template
    $htmlContent = $templateHtml -replace '\{\{DATE\}\}', $dateEffacement
    $htmlContent = $htmlContent -replace '\{\{SOCIETE\}\}', $societe
    $htmlContent = $htmlContent -replace '\{\{SERIAL_NUMBERS\}\}', $snList

    # Sauvegarder le HTML temporaire
    $tempHtml = [System.IO.Path]::GetTempFileName() + ".html"
    $htmlContent | Out-File -FilePath $tempHtml -Encoding UTF8 -Force

    try {
        # Conversion HTML vers PDF avec wkhtmltopdf (si disponible)
        $wkhtmltopdfPath = Join-Path (Get-CdRootDirectory) 'Tools\wkhtmltopdf.exe'
        
        if (Test-Path $wkhtmltopdfPath) {
            $process = Start-Process -FilePath $wkhtmltopdfPath `
                                     -ArgumentList "--enable-local-file-access `"$tempHtml`" `"$OutputPath`"" `
                                     -NoNewWindow `
                                     -Wait `
                                     -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Verbose "[New-CdCertificatePdf] Certificat PDF généré : $OutputPath"
                return $OutputPath
            }
            else {
                Write-Error "Erreur lors de la génération du PDF (code: $($process.ExitCode))"
                return $null
            }
        }
        else {
            # Si wkhtmltopdf n'est pas disponible, copier le HTML comme fallback
            Write-Warning "[New-CdCertificatePdf] wkhtmltopdf non trouvé. Génération HTML uniquement."
            $htmlOutput = $OutputPath -replace '\.pdf$', '.html'
            Copy-Item -Path $tempHtml -Destination $htmlOutput -Force
            return $htmlOutput
        }
    }
    finally {
        # Nettoyage
        if (Test-Path $tempHtml) {
            Remove-Item -Path $tempHtml -Force -ErrorAction SilentlyContinue
        }
    }
}
