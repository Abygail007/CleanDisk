function New-CdClientHistory {
    <#
        .SYNOPSIS
        Genere un rapport HTML complet de l'historique d'un client.
        
        .DESCRIPTION
        Compile toutes les sessions d'effacement pour un client donne
        et genere un rapport HTML avec l'historique complet.
        
        .PARAMETER CustomerName
        Nom de la societe cliente.
        
        .PARAMETER OutputDirectory
        Dossier de sortie (par defaut : Logs/Clients).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CustomerName,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory
    )

    try {
        $root = Get-CdRootDirectory
        
        if (-not $OutputDirectory) {
            $OutputDirectory = Join-Path $root 'Logs\Clients'
        }

        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }

        # Chercher tous les fichiers XML d'audit pour ce client
        $logsDir = Join-Path $root 'Logs'
        $auditFiles = Get-ChildItem -Path $logsDir -Filter "CleanDiskAudit_*.xml" -ErrorAction SilentlyContinue

        # Filtrer les audits pour ce client
        $clientSessions = @()

        foreach ($file in $auditFiles) {
            try {
                [xml]$xmlContent = Get-Content -Path $file.FullName -Encoding UTF8

                # Structure XML : <CleanDiskAudit>/<Disk> (un ou plusieurs)
                $diskNodes = @($xmlContent.CleanDiskAudit.Disk)

                if ($diskNodes.Count -eq 0) { continue }

                # Filtrer par client
                $clientDisks = @($diskNodes | Where-Object { $_.CustomerName -eq $CustomerName })

                if ($clientDisks.Count -gt 0) {
                    $firstDisk = $clientDisks[0]

                    # Parser la date
                    $sessionDate = $null
                    $dateStr = $firstDisk.StartTime
                    if ($dateStr) {
                        $formats = @("MM/dd/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd HH:mm:ss")
                        foreach ($fmt in $formats) {
                            try {
                                $testDate = [datetime]::ParseExact($dateStr, $fmt, $null)
                                if ($testDate -le (Get-Date).AddDays(1) -and $testDate -ge (Get-Date).AddYears(-2)) {
                                    $sessionDate = $testDate
                                    break
                                }
                            }
                            catch { continue }
                        }
                        if (-not $sessionDate) {
                            try { $sessionDate = [datetime]::Parse($dateStr) } catch { $sessionDate = $file.LastWriteTime }
                        }
                    }
                    else {
                        $sessionDate = $file.LastWriteTime
                    }

                    $clientSessions += [PSCustomObject]@{
                        Date = $sessionDate
                        DateFormatted = $sessionDate.ToString("dd/MM/yyyy HH:mm")
                        DiskCount = $clientDisks.Count
                        Technicien = $firstDisk.TechnicianName
                        Site = $firstDisk.SiteName
                        Ville = $firstDisk.City
                        Disks = $clientDisks
                        XmlFile = $file.FullName
                    }
                }
            }
            catch {
                Write-Warning "[New-CdClientHistory] Erreur lecture $($file.Name) : $_"
            }
        }

        if ($clientSessions.Count -eq 0) {
            Write-Warning "[New-CdClientHistory] Aucune session trouvee pour le client : $CustomerName"
            return $null
        }

        # Trier par date decroissante (plus recent en premier)
        $clientSessions = $clientSessions | Sort-Object -Property Date -Descending

        # Calculer statistiques globales
        $totalDisks = ($clientSessions | Measure-Object -Property DiskCount -Sum).Sum
        $firstSession = ($clientSessions | Sort-Object -Property Date | Select-Object -First 1).DateFormatted
        $lastSession = ($clientSessions | Sort-Object -Property Date -Descending | Select-Object -First 1).DateFormatted

        # Generer HTML
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Historique Client - $CustomerName</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .header {
            border-bottom: 3px solid #667eea;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        
        .header h1 {
            color: #2c3e50;
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #7f8c8d;
            font-size: 16px;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        
        .stat-value {
            font-size: 36px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .stat-label {
            font-size: 14px;
            opacity: 0.9;
        }
        
        .session {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
        }
        
        .session-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .session-date {
            font-size: 18px;
            font-weight: bold;
            color: #2c3e50;
        }
        
        .session-info {
            font-size: 14px;
            color: #7f8c8d;
        }
        
        .disks-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        
        .disks-table th {
            background: #34495e;
            color: white;
            padding: 10px;
            text-align: left;
            font-size: 14px;
        }
        
        .disks-table td {
            padding: 8px 10px;
            border-bottom: 1px solid #ecf0f1;
            font-size: 13px;
        }
        
        .disks-table tr:hover {
            background: #f1f3f4;
        }
        
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #ecf0f1;
            text-align: center;
            color: #7f8c8d;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Historique Client</h1>
            <p><strong>$CustomerName</strong></p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($clientSessions.Count)</div>
                <div class="stat-label">Sessions</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$totalDisks</div>
                <div class="stat-label">Disques effaces</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$firstSession</div>
                <div class="stat-label">Premiere session</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$lastSession</div>
                <div class="stat-label">Derniere session</div>
            </div>
        </div>
        
        <h2 style="color: #2c3e50; margin-bottom: 20px;">📅 Sessions d'effacement</h2>
"@

        # Ajouter chaque session
        foreach ($session in $clientSessions) {
            $html += @"
        <div class="session">
            <div class="session-header">
                <div class="session-date">Session du $($session.DateFormatted)</div>
                <div class="session-info">
                    $($session.DiskCount) disque(s) | Site: $($session.Site) | Ville: $($session.Ville) | Technicien: $($session.Technicien)
                </div>
            </div>
            
            <table class="disks-table">
                <thead>
                    <tr>
                        <th>N°</th>
                        <th>Modele</th>
                        <th>Numero de Serie</th>
                        <th>Taille</th>
                        <th>Duree</th>
                    </tr>
                </thead>
                <tbody>
"@

            $diskIndex = 1
            foreach ($disk in $session.Disks) {
                $html += @"
                    <tr>
                        <td>$diskIndex</td>
                        <td>$($disk.Model)</td>
                        <td>$($disk.Serial)</td>
                        <td>$($disk.SizeGB) Go</td>
                        <td>$($disk.DurationSeconds) sec</td>
                    </tr>
"@
                $diskIndex++
            }

            $html += @"
                </tbody>
            </table>
        </div>
"@
        }

        $html += @"
        
        <div class="footer">
            <p>Genere le $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') - LOGICIA INFORMATIQUE</p>
            <p>Ce rapport compile l'ensemble des sessions d'effacement pour ce client</p>
        </div>
    </div>
</body>
</html>
"@

        # Sauvegarder HTML avec encodage UTF8 sans BOM
        $safeCustomer = $CustomerName -replace '[^a-zA-Z0-9]', '_'
        $htmlFileName = "Historique_${safeCustomer}.html"
        $htmlPath = Join-Path $OutputDirectory $htmlFileName

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($htmlPath, $html, $utf8NoBom)

        Write-Verbose "[New-CdClientHistory] Historique genere : $htmlPath"
        return $htmlPath
    }
    catch {
        Write-Error "[New-CdClientHistory] Erreur : $_"
        return $null
    }
}
