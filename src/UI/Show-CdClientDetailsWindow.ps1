function Show-CdClientDetailsWindow {
    <#
        .SYNOPSIS
        Affiche la fenetre de details d'un client avec son historique.

        .PARAMETER CustomerName
        Nom du client a afficher.

        .PARAMETER ParentWindow
        Fenetre parente pour le mode modal.

        .OUTPUTS
        Hashtable avec StartNewSession=$true si l'utilisateur veut demarrer une nouvelle session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CustomerName,

        [Parameter(Mandatory = $false)]
        $ParentWindow = $null
    )

    $result = @{
        StartNewSession = $false
        CustomerInfo = $null
    }

    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue

        $root = Get-CdRootDirectory
        $xamlPath = Join-Path $root 'src\UI\ClientDetailsWindow.xaml'

        if (-not (Test-Path $xamlPath)) {
            Write-Error "Fichier XAML introuvable : $xamlPath"
            return $result
        }

        [xml]$xaml = Get-Content -Path $xamlPath -Encoding UTF8
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        # Recuperer les controles
        $txtClientName = $window.FindName("TxtClientName")
        $txtClientSite = $window.FindName("TxtClientSite")
        $txtClientCity = $window.FindName("TxtClientCity")
        $txtTotalDisks = $window.FindName("TxtTotalDisks")
        $dgClientHistory = $window.FindName("DgClientHistory")
        $btnNewSession = $window.FindName("BtnNewSession")
        $btnOpenReports = $window.FindName("BtnOpenReports")
        $btnViewHistory = $window.FindName("BtnViewHistory")
        $btnClose = $window.FindName("BtnClose")

        # Charger les donnees du client
        $logsPath = Join-Path $root 'Logs'
        $auditFiles = Get-ChildItem -Path $logsPath -Filter "CleanDiskAudit_*.xml" -ErrorAction SilentlyContinue

        $clientSessions = @()
        $totalDisks = 0
        $lastSite = ""
        $lastCity = ""

        foreach ($file in $auditFiles) {
            try {
                [xml]$xmlContent = Get-Content -Path $file.FullName -Encoding UTF8 -ErrorAction Stop
                $diskNodes = @($xmlContent.CleanDiskAudit.Disk)

                foreach ($disk in $diskNodes) {
                    if ($disk.CustomerName -eq $CustomerName) {
                        $totalDisks++

                        # Garder le dernier site/ville connu
                        if ($disk.SiteName) { $lastSite = $disk.SiteName }
                        if ($disk.City) { $lastCity = $disk.City }

                        # Parser la date - PowerShell ecrit au format MM/dd/yyyy HH:mm:ss
                        $sessionDate = $null
                        $dateStr = $disk.StartTime
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
                            DateStr = $sessionDate.ToString("dd/MM/yyyy HH:mm")
                            Technicien = $disk.TechnicianName
                            WipeMode = $disk.WipeMode
                            DiskCount = 1
                            Model = $disk.Model
                            Serial = $disk.Serial
                            SizeGB = $disk.SizeGB
                            Result = $disk.Result
                            XmlFile = $file.FullName
                        }
                    }
                }
            }
            catch {
                Write-Verbose "[Show-CdClientDetailsWindow] Erreur lecture $($file.Name) : $_"
            }
        }

        # Mettre a jour l'interface
        $txtClientName.Text = $CustomerName
        $txtClientSite.Text = if ($lastSite) { $lastSite } else { "-" }
        $txtClientCity.Text = if ($lastCity) { $lastCity } else { "-" }
        $txtTotalDisks.Text = $totalDisks.ToString()

        # Trier par date decroissante
        $sortedSessions = @($clientSessions | Sort-Object -Property Date -Descending)
        $dgClientHistory.ItemsSource = $sortedSessions

        # Stocker les infos client pour la reprise de session
        $clientInfo = @{
            Societe = $CustomerName
            Site = $lastSite
            Ville = $lastCity
        }

        # Evenement : Nouvelle session
        $btnNewSession.Add_Click({
            $result.StartNewSession = $true
            $result.CustomerInfo = $clientInfo
            $window.DialogResult = $true
            $window.Close()
        }.GetNewClosure())

        # Evenement : Ouvrir dossier rapports
        $btnOpenReports.Add_Click({
            try {
                $logsPath = Join-Path (Get-CdRootDirectory) 'Logs'
                if (Test-Path $logsPath) {
                    Start-Process explorer.exe -ArgumentList $logsPath
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Impossible d'ouvrir le dossier : $_", "Erreur", "OK", "Error")
            }
        })

        # Evenement : Voir historique complet (ouvrir le dashboard HTML)
        $btnViewHistory.Add_Click({
            try {
                $dashboardPath = Join-Path (Get-CdRootDirectory) 'Logs\Dashboard_CleanDisk.html'
                if (Test-Path $dashboardPath) {
                    Start-Process $dashboardPath
                }
                else {
                    # Generer le dashboard s'il n'existe pas
                    $newDashboard = New-CdDashboard
                    if ($newDashboard -and (Test-Path $newDashboard)) {
                        Start-Process $newDashboard
                    }
                    else {
                        [System.Windows.MessageBox]::Show("Dashboard non disponible.", "Information", "OK", "Information")
                    }
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Erreur : $_", "Erreur", "OK", "Error")
            }
        })

        # Evenement : Fermer
        $btnClose.Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })

        # Double-clic sur une ligne pour ouvrir le fichier XML
        $dgClientHistory.Add_MouseDoubleClick({
            param($sender, $e)
            try {
                $selectedItem = $dgClientHistory.SelectedItem
                if ($selectedItem -and $selectedItem.XmlFile) {
                    $xmlFile = $selectedItem.XmlFile
                    # Chercher le rapport HTML correspondant
                    $htmlFile = $xmlFile -replace 'CleanDiskAudit_', 'Rapport_Interne_' -replace '\.xml$', '.html'
                    if (Test-Path $htmlFile) {
                        Start-Process $htmlFile
                    }
                    elseif (Test-Path $xmlFile) {
                        Start-Process notepad.exe -ArgumentList $xmlFile
                    }
                }
            }
            catch {
                Write-Verbose "[Show-CdClientDetailsWindow] Erreur double-clic : $_"
            }
        })

        # Afficher la fenetre
        if ($ParentWindow) {
            $window.Owner = $ParentWindow
        }

        $null = $window.ShowDialog()

        return $result
    }
    catch {
        Write-Error "[Show-CdClientDetailsWindow] Erreur : $_"
        return $result
    }
}
