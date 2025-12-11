function New-CdInternalReport {
    <#
        .SYNOPSIS
        Génère le rapport HTML interne avec toutes les informations détaillées.
        
        .PARAMETER DiskRecords
        Liste des enregistrements de disques effacés.
        
        .PARAMETER CustomerInfo
        Hashtable contenant Societe, Site, Ville, Technicien.
        
        .PARAMETER Options
        Hashtable contenant WipeMode, BitLocker, VolumeLabel.
        
        .PARAMETER OutputPath
        Chemin du fichier HTML de sortie.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DiskRecords,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$CustomerInfo,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Options,
        
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
        $OutputPath = Join-Path $logsDir "Rapport_Interne_${safeCustomer}_${timestamp}.html"
    }

    # Construction du HTML
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Rapport Interne - CleanDisk</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        
        h2 {
            color: #34495e;
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        
        .info-section {
            background-color: #f8f9fa;
            padding: 15px;
            margin: 15px 0;
            border-left: 4px solid #3498db;
        }
        
        .info-section p {
            margin: 5px 0;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        
        th {
            background-color: #34495e;
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: bold;
        }
        
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        
        tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        
        .success {
            color: #27ae60;
            font-weight: bold;
        }
        
        .failure {
            color: #e74c3c;
            font-weight: bold;
        }
        
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #ddd;
            color: #888;
            font-size: 0.9em;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Rapport Interne d'Effacement - CleanDisk</h1>

        <div class="info-section">
            <p><strong>Date et heure :</strong> $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</p>
            <p><strong>Technicien :</strong> $($CustomerInfo.Technicien)</p>
        </div>

        <h2>Informations Client</h2>
        <div class="info-section">
            <p><strong>Societe :</strong> $($CustomerInfo.Societe)</p>
            <p><strong>Site :</strong> $($CustomerInfo.Site)</p>
            <p><strong>Ville :</strong> $($CustomerInfo.Ville)</p>
        </div>

        <h2>Options d'Effacement</h2>
        <div class="info-section">
            <p><strong>Mode :</strong> $($Options.WipeMode)</p>
            <p><strong>BitLocker pre-chiffrement :</strong> $(if ($Options.BitLocker) { "Oui" } else { "Non" })</p>
            <p><strong>Etiquette volume :</strong> $($Options.VolumeLabel)</p>
        </div>

        <h2>Details des Disques Effaces</h2>
        <table>
            <thead>
                <tr>
                    <th>No</th>
                    <th>Modele</th>
                    <th>S/N</th>
                    <th>Taille</th>
                    <th>Utilise</th>
                    <th>Lettre</th>
                    <th>Bus</th>
                    <th>BitLocker</th>
                    <th>Duree</th>
                    <th>Resultat</th>
                </tr>
            </thead>
            <tbody>
"@

    foreach ($record in $DiskRecords) {
        $okSymbol = [char]0x2713      # ✓
        $errorSymbol = [char]0x2717   # ✗
        
        $resultClass = if ($record.Result -eq "Success") { "success" } else { "failure" }
        $resultText  = if ($record.Result -eq "Success") { "$okSymbol Reussi" } else { "$errorSymbol Echec" }
        
        $sn = if ($record.Serial) { $record.Serial } else { "-" }
        $duration = if ($record.DurationSeconds) { "$($record.DurationSeconds)s" } else { "-" }
        
        $html += @"
                <tr>
                    <td>$($record.DiskNumber)</td>
                    <td>$($record.Model)</td>
                    <td>$sn</td>
                    <td>$($record.SizeGB) Go</td>
                    <td>$($record.UsedGB) Go</td>
                    <td>$($record.DriveLetter)</td>
                    <td>$($record.Bus)</td>
                    <td>$($record.BitLockerStatus)</td>
                    <td>$duration</td>
                    <td class="$resultClass">$resultText</td>
                </tr>
"@
    }

    $html += @"
            </tbody>
        </table>

        <h2>Statistiques</h2>
        <div class="info-section">
            <p><strong>Nombre total de disques :</strong> $($DiskRecords.Count)</p>
            <p><strong>Reussis :</strong> $(($DiskRecords | Where-Object { $_.Result -eq 'Success' }).Count)</p>
            <p><strong>Echecs :</strong> $(($DiskRecords | Where-Object { $_.Result -ne 'Success' }).Count)</p>
        </div>

        <div class="footer">
            Rapport genere par CleanDisk v0.2 - LOGICIA INFORMATIQUE<br>
            Document interne - Ne pas diffuser au client
        </div>
    </div>
</body>
</html>
"@

    # Sauvegarder le fichier en ASCII pour eviter les problemes d'encodage
    $html | Out-File -FilePath $OutputPath -Encoding ASCII -Force
    
    Write-Verbose "[New-CdInternalReport] Rapport interne généré : $OutputPath"
    return $OutputPath
}
