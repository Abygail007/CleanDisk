function Show-CdMainWindow {
    <#
        .SYNOPSIS
        Affiche la fenetre principale CleanDisk avec workflow complet.
        Demarre sur le Dashboard puis enchaine les etapes.
    #>
    [CmdletBinding()]
    param()

    # Chargement des assemblies WPF
    try {
        Add-Type -AssemblyName PresentationCore       -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationFramework  -ErrorAction SilentlyContinue
        Add-Type -AssemblyName WindowsBase            -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "[Show-CdMainWindow] Impossible de charger les assemblies WPF : $_"
        return
    }

    # Creer une classe .NET pour le binding WPF (resout le probleme de PSCustomObject)
    $diskItemClass = @"
using System.ComponentModel;
public class DiskItem : INotifyPropertyChanged
{
    private bool _selected;
    private int _number;
    private string _model;
    private string _sizeGB;
    private string _usedGB;
    private string _driveLetter;
    private string _bus;
    private string _bitLockerStatus;
    private string _status;

    public event PropertyChangedEventHandler PropertyChanged;

    public bool Selected
    {
        get { return _selected; }
        set { _selected = value; OnPropertyChanged("Selected"); }
    }
    public int Number
    {
        get { return _number; }
        set { _number = value; OnPropertyChanged("Number"); }
    }
    public string Model
    {
        get { return _model; }
        set { _model = value; OnPropertyChanged("Model"); }
    }
    public string SizeGB
    {
        get { return _sizeGB; }
        set { _sizeGB = value; OnPropertyChanged("SizeGB"); }
    }
    public string UsedGB
    {
        get { return _usedGB; }
        set { _usedGB = value; OnPropertyChanged("UsedGB"); }
    }
    public string DriveLetter
    {
        get { return _driveLetter; }
        set { _driveLetter = value; OnPropertyChanged("DriveLetter"); }
    }
    public string Bus
    {
        get { return _bus; }
        set { _bus = value; OnPropertyChanged("Bus"); }
    }
    public string BitLockerStatus
    {
        get { return _bitLockerStatus; }
        set { _bitLockerStatus = value; OnPropertyChanged("BitLockerStatus"); }
    }
    public string Status
    {
        get { return _status; }
        set { _status = value; OnPropertyChanged("Status"); }
    }

    protected void OnPropertyChanged(string name)
    {
        if (PropertyChanged != null)
            PropertyChanged(this, new PropertyChangedEventArgs(name));
    }
}
"@

    try {
        Add-Type -TypeDefinition $diskItemClass -ErrorAction SilentlyContinue
    }
    catch {
        # La classe existe deja, pas de probleme
    }

    # Charger le XAML (mode portable ou fichier)
    $xaml = $null

    # Mode portable : XAML embarque
    if ($script:IsPortableMode -and $script:EmbeddedXAML) {
        $xaml = $script:EmbeddedXAML
    }
    else {
        # Mode normal : lire depuis fichier
        if (-not $global:CdSrcPath) {
            $root             = Get-CdRootDirectory
            $global:CdSrcPath = Join-Path $root 'src'
        }

        $xamlPath = Join-Path $global:CdSrcPath 'UI\CleanDisk.xaml'

        if (-not (Test-Path -LiteralPath $xamlPath)) {
            Write-Error "Fichier XAML introuvable : $xamlPath"
            return
        }

        $xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
    }

    $stringReader = New-Object System.IO.StringReader $xaml
    $xmlReader    = [System.Xml.XmlReader]::Create($stringReader)

    $window = [Windows.Markup.XamlReader]::Load($xmlReader)

    # ========================================
    # RECUPERATION DES CONTROLES
    # ========================================

    # En-tete
    $txtStepTitle       = $window.FindName('TxtStepTitle')
    $txtStepDescription = $window.FindName('TxtStepDescription')

    # Etape 0 - Dashboard
    $step0Panel         = $window.FindName('Step0Panel')
    $txtStatDisks       = $window.FindName('TxtStatDisks')
    $txtStatClients     = $window.FindName('TxtStatClients')
    $txtStatSessions    = $window.FindName('TxtStatSessions')
    $txtStatSuccess     = $window.FindName('TxtStatSuccess')
    $dgRecentActivity   = $window.FindName('DgRecentActivity')

    # Etape 1 - Selection disques
    $step1Panel       = $window.FindName('Step1Panel')
    $dgDisks          = $window.FindName('DgDisks')
    $btnSelectAll     = $window.FindName('BtnSelectAll')
    $btnDeselectAll   = $window.FindName('BtnDeselectAll')

    # Etape 2 - Infos client
    $step2Panel       = $window.FindName('Step2Panel')
    $cbSociete        = $window.FindName('CbSociete')
    $txtSite          = $window.FindName('TxtSite')
    $txtVille         = $window.FindName('TxtVille')
    $cbTechnicien     = $window.FindName('CbTechnicien')

    # Etape 3 - Options
    $step3Panel          = $window.FindName('Step3Panel')
    $rbFast              = $window.FindName('RbFast')
    $rbSecure            = $window.FindName('RbSecure')
    $chkBitLocker        = $window.FindName('ChkBitLocker')
    $chkCreatePartition  = $window.FindName('ChkCreatePartition')
    $txtVolumeLabel      = $window.FindName('TxtVolumeLabel')

    # Etape 3.5 - Resume
    $stepSummaryPanel     = $window.FindName('StepSummaryPanel')
    $txtSummarySociete    = $window.FindName('TxtSummarySociete')
    $txtSummarySite       = $window.FindName('TxtSummarySite')
    $txtSummaryVille      = $window.FindName('TxtSummaryVille')
    $txtSummaryTechnicien = $window.FindName('TxtSummaryTechnicien')
    $txtSummaryMode       = $window.FindName('TxtSummaryMode')
    $txtSummaryBitLocker  = $window.FindName('TxtSummaryBitLocker')
    $txtSummaryLabel      = $window.FindName('TxtSummaryLabel')
    $txtSummaryDiskCount  = $window.FindName('TxtSummaryDiskCount')
    $dgSummaryDisks       = $window.FindName('DgSummaryDisks')

    # Etape 4 - Execution
    $step4Panel       = $window.FindName('Step4Panel')
    $txtProgressInfo  = $window.FindName('TxtProgressInfo')
    $pbProgress       = $window.FindName('PbProgress')
    $txtCurrentDisk   = $window.FindName('TxtCurrentDisk')
    $txtLogs          = $window.FindName('TxtLogs')

    # Etape 5 - Post-actions
    $step5Panel       = $window.FindName('Step5Panel')
    $dgPostActions    = $window.FindName('DgPostActions')
    $btnAssignLetters = $window.FindName('BtnAssignLetters')
    $btnEjectAll      = $window.FindName('BtnEjectAll')

    # Etape 6 - Finalisation
    $step6Panel           = $window.FindName('Step6Panel')
    $txtCertificatePath   = $window.FindName('TxtCertificatePath')
    $txtRapportPath       = $window.FindName('TxtRapportPath')
    $btnOpenLogsFolder    = $window.FindName('BtnOpenLogsFolder')
    $btnRestartSameClient = $window.FindName('BtnRestartSameClient')
    $btnRestartNewClient  = $window.FindName('BtnRestartNewClient')
    $btnFinish            = $window.FindName('BtnFinish')

    # Navigation
    $btnPrevious = $window.FindName('BtnPrevious')
    $btnNext     = $window.FindName('BtnNext')
    $btnCancel   = $window.FindName('BtnCancel')

    # ========================================
    # VARIABLES GLOBALES DU WORKFLOW
    # ========================================

    $script:currentStep = 0
    $script:selectedDisks = @()
    $script:processedDisks = @()
    $script:customerInfo = @{
        Societe    = ""
        Site       = ""
        Ville      = ""
        Technicien = ""
    }
    $script:options = @{
        WipeMode        = "Fast"
        BitLocker       = $false
        VolumeLabel     = ""
        CreatePartition = $true
    }
    $script:profiles = @()
    $script:technicians = @()

    # ========================================
    # FONCTIONS INTERNES
    # ========================================

    function Update-StepDisplay {
        param([int]$Step)

        $script:currentStep = $Step

        # Masquer tous les panels
        $step0Panel.Visibility = "Collapsed"
        $step1Panel.Visibility = "Collapsed"
        $step2Panel.Visibility = "Collapsed"
        $step3Panel.Visibility = "Collapsed"
        $stepSummaryPanel.Visibility = "Collapsed"
        $step4Panel.Visibility = "Collapsed"
        $step5Panel.Visibility = "Collapsed"
        $step6Panel.Visibility = "Collapsed"

        # Afficher le panel actif et mettre a jour les titres
        switch ($Step) {
            0 {
                $step0Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Dashboard - Vue d'ensemble"
                $txtStepDescription.Text = "Statistiques et activite recente"
                $btnPrevious.IsEnabled = $false
                $btnNext.IsEnabled = $true
                $btnNext.Content = "Commencer"
            }
            1 {
                $step1Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Etape 1/6 - Selection des disques"
                $txtStepDescription.Text = "Cochez les disques a effacer (hors disque systeme)"
                $btnPrevious.IsEnabled = $true
                $btnNext.IsEnabled = $true
                $btnNext.Content = "Suivant"
            }
            2 {
                $step2Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Etape 2/6 - Informations client"
                $txtStepDescription.Text = "Renseignez les informations pour le certificat"
                $btnPrevious.IsEnabled = $true
                $btnNext.IsEnabled = $true
                $btnNext.Content = "Suivant"
            }
            3 {
                $step3Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Etape 3/6 - Options d'effacement"
                $txtStepDescription.Text = "Choisissez le mode d'effacement et les options"
                $btnPrevious.IsEnabled = $true
                $btnNext.IsEnabled = $true
                $btnNext.Content = "Suivant"
            }
            35 {
                # Etape Resume (3.5)
                $stepSummaryPanel.Visibility = "Visible"
                $txtStepTitle.Text = "Verification - Resume avant effacement"
                $txtStepDescription.Text = "Verifiez attentivement les informations ci-dessous"
                $btnPrevious.IsEnabled = $true
                $btnNext.IsEnabled = $true
                $btnNext.Content = "Lancer l'effacement"
            }
            4 {
                $step4Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Etape 4/6 - Effacement en cours"
                $txtStepDescription.Text = "Ne pas eteindre l'ordinateur pendant l'operation"
                $btnPrevious.IsEnabled = $false
                $btnNext.IsEnabled = $false
            }
            5 {
                $step5Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Etape 5/6 - Post-actions"
                $txtStepDescription.Text = "Creation de partitions et ejection des disques"
                $btnPrevious.IsEnabled = $false
                $btnNext.IsEnabled = $true
                $btnNext.Content = "Suivant"
            }
            6 {
                $step6Panel.Visibility = "Visible"
                $txtStepTitle.Text = "Etape 6/6 - Finalisation"
                $txtStepDescription.Text = "Operation terminee avec succes"
                $btnPrevious.IsEnabled = $false
                $btnNext.IsEnabled = $false
            }
        }
    }

    function Load-DashboardStats {
        try {
            $root = Get-CdRootDirectory
            $logsPath = Join-Path $root 'Logs'

            if (-not (Test-Path -LiteralPath $logsPath)) {
                $txtStatDisks.Text = "0"
                $txtStatClients.Text = "0"
                $txtStatSessions.Text = "0"
                $txtStatSuccess.Text = "100%"
                $dgRecentActivity.ItemsSource = @()
                return
            }

            $auditFiles = Get-ChildItem -Path $logsPath -Filter "CleanDiskAudit_*.xml" -ErrorAction SilentlyContinue

            if ($auditFiles.Count -eq 0) {
                $txtStatDisks.Text = "0"
                $txtStatClients.Text = "0"
                $txtStatSessions.Text = "0"
                $txtStatSuccess.Text = "100%"
                $dgRecentActivity.ItemsSource = @()
                return
            }

            $allSessions = @()
            $totalDisks = 0
            $successDisks = 0
            $customers = @()
            $cutoffDate = (Get-Date).AddDays(-7)

            foreach ($file in $auditFiles) {
                try {
                    [xml]$xmlContent = Get-Content -Path $file.FullName -Encoding UTF8 -ErrorAction Stop

                    # Structure XML : <CleanDiskAudit>/<Disk> (un ou plusieurs)
                    $diskNodes = @($xmlContent.CleanDiskAudit.Disk)

                    if ($diskNodes.Count -eq 0) {
                        continue
                    }

                    # Prendre le premier disque pour les infos de session
                    $firstDisk = $diskNodes[0]

                    # Parser la date - PowerShell ecrit au format MM/dd/yyyy HH:mm:ss
                    $sessionDate = $null
                    $dateStr = $firstDisk.StartTime

                    if ($dateStr) {
                        # Essayer d'abord le format PowerShell par defaut (MM/dd/yyyy)
                        $formats = @("MM/dd/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd HH:mm:ss")
                        foreach ($fmt in $formats) {
                            try {
                                $testDate = [datetime]::ParseExact($dateStr, $fmt, $null)
                                # Verifier que la date est raisonnable (pas dans le futur lointain, pas trop ancienne)
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

                    $diskCount = $diskNodes.Count
                    $totalDisks += $diskCount

                    # Compter les succes
                    foreach ($diskNode in $diskNodes) {
                        if ($diskNode.Result -eq "Success") {
                            $successDisks++
                        }
                    }

                    $customerName = $firstDisk.CustomerName
                    if ($customerName -and $customerName -notin $customers) {
                        $customers += $customerName
                    }

                    if ($sessionDate -ge $cutoffDate) {
                        $allSessions += [PSCustomObject]@{
                            Date       = $sessionDate
                            DateStr    = $sessionDate.ToString("dd/MM/yyyy HH:mm")
                            Customer   = $customerName
                            Technicien = $firstDisk.TechnicianName
                            DiskCount  = $diskCount
                            Site       = $firstDisk.SiteName
                        }
                    }
                }
                catch {
                    Write-Verbose "[Load-DashboardStats] Erreur lecture $($file.Name) : $_"
                }
            }

            $txtStatDisks.Text = $totalDisks.ToString()
            $txtStatClients.Text = $customers.Count.ToString()
            $txtStatSessions.Text = $auditFiles.Count.ToString()

            if ($totalDisks -gt 0) {
                $successRate = [math]::Round(($successDisks / $totalDisks) * 100, 1)
                $txtStatSuccess.Text = "$successRate%"
            }
            else {
                $txtStatSuccess.Text = "100%"
            }

            $recentSorted = @($allSessions | Sort-Object -Property Date -Descending | Select-Object -First 10)
            $dgRecentActivity.ItemsSource = $recentSorted
        }
        catch {
            Write-Warning "[Load-DashboardStats] Erreur : $_"
        }
    }

    function Load-DiskList {
        try {
            # Precacher toutes les partitions et volumes en une seule fois (BEAUCOUP plus rapide)
            $allPartitions = @{}
            $allVolumes = @{}
            $allBitLocker = @{}

            try {
                Get-Partition -ErrorAction SilentlyContinue | ForEach-Object {
                    if (-not $allPartitions.ContainsKey($_.DiskNumber)) {
                        $allPartitions[$_.DiskNumber] = @()
                    }
                    $allPartitions[$_.DiskNumber] += $_
                }
            } catch { }

            try {
                Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | ForEach-Object {
                    $allVolumes[$_.DriveLetter] = $_
                }
            } catch { }

            try {
                Get-BitLockerVolume -ErrorAction SilentlyContinue | ForEach-Object {
                    $letter = $_.MountPoint -replace ':\\?$', ''
                    if ($letter) {
                        $allBitLocker[$letter] = $_
                    }
                }
            } catch { }

            $disks = Get-CdDiskList

            # Utiliser une ObservableCollection avec la classe DiskItem
            $script:diskCollection = New-Object System.Collections.ObjectModel.ObservableCollection[DiskItem]

            foreach ($d in $disks) {
                $usedGB = "N/A"
                $driveLetter = ""
                $bitLockerStatus = "Non"

                # Utiliser les caches au lieu de requetes individuelles
                $partitions = $allPartitions[$d.Number]
                if ($partitions) {
                    foreach ($part in $partitions) {
                        if ($part.DriveLetter) {
                            $driveLetter = $part.DriveLetter
                            $vol = $allVolumes[$driveLetter]
                            if ($vol) {
                                $usedSizeGB = [math]::Round(($vol.Size - $vol.SizeRemaining) / 1GB, 1)
                                $usedGB = "$usedSizeGB"
                            }
                            break
                        }
                    }

                    if ($driveLetter) {
                        $blvInfo = $allBitLocker[$driveLetter]
                        if ($blvInfo -and $blvInfo.ProtectionStatus -eq 'On') {
                            $bitLockerStatus = "Oui"
                        }
                    }
                }

                # Creer un objet DiskItem avec le bon numero
                $diskItem = New-Object DiskItem
                $diskItem.Selected = $false
                $diskItem.Number = [int]$d.Number
                $diskItem.Model = $d.Model
                $diskItem.SizeGB = "$($d.SizeGB) Go"
                $diskItem.UsedGB = $usedGB
                $diskItem.DriveLetter = if ($driveLetter) { "$driveLetter`:" } else { "-" }
                $diskItem.Bus = $d.Bus
                $diskItem.BitLockerStatus = $bitLockerStatus
                $diskItem.Status = $d.Status

                $script:diskCollection.Add($diskItem)
            }

            $dgDisks.ItemsSource = $script:diskCollection
        }
        catch {
            [System.Windows.MessageBox]::Show(
                "Erreur lors du chargement de la liste des disques :`n$_",
                "CleanDisk",
                'OK',
                'Error'
            ) | Out-Null
        }
    }

    function Update-SummaryPage {
        # Remplir les infos client
        $txtSummarySociete.Text = if ($cbSociete.Text) { $cbSociete.Text } else { "-" }
        $txtSummarySite.Text = if ($txtSite.Text) { $txtSite.Text } else { "-" }
        $txtSummaryVille.Text = if ($txtVille.Text) { $txtVille.Text } else { "-" }
        $txtSummaryTechnicien.Text = if ($cbTechnicien.Text) { $cbTechnicien.Text } else { "-" }

        # Remplir les options
        $modeText = if ($rbSecure.IsChecked) { "Secure (effacement complet)" } else { "Fast (effacement rapide)" }
        $txtSummaryMode.Text = $modeText

        $txtSummaryBitLocker.Text = if ($chkBitLocker.IsChecked) { "Oui" } else { "Non" }

        $labelText = if ([string]::IsNullOrWhiteSpace($txtVolumeLabel.Text)) { "(aucune etiquette)" } else { $txtVolumeLabel.Text }
        $txtSummaryLabel.Text = $labelText

        # Remplir les disques depuis la collection avec copie explicite
        $selectedDisksForSummary = @()
        foreach ($item in $script:diskCollection) {
            if ($item.Selected -eq $true) {
                $selectedDisksForSummary += [PSCustomObject]@{
                    Number      = [int]$item.Number
                    Model       = $item.Model
                    SizeGB      = $item.SizeGB
                    Bus         = $item.Bus
                    DriveLetter = $item.DriveLetter
                }
            }
        }
        $count = $selectedDisksForSummary.Count
        $txtSummaryDiskCount.Text = "Disques a effacer ($count)"
        $dgSummaryDisks.ItemsSource = $selectedDisksForSummary
    }

    function Start-WipeProcess {
        # Recuperer les disques selectionnes depuis la collection avec verification stricte
        $script:selectedDisks = @()

        foreach ($item in $script:diskCollection) {
            if ($item.Selected -eq $true) {
                $diskNum = $item.Number

                # SECURITE ABSOLUE : Refuser le disque 0
                if ($diskNum -eq 0) {
                    [System.Windows.MessageBox]::Show(
                        "ERREUR CRITIQUE : Le systeme tente d'effacer le disque 0 (systeme).`nOperation ANNULEE pour securite.",
                        "CleanDisk - SECURITE",
                        'OK',
                        'Error'
                    ) | Out-Null
                    return $false
                }

                # Creer une copie avec le numero de disque verifie
                $diskCopy = [PSCustomObject]@{
                    Number         = [int]$diskNum
                    Model          = $item.Model
                    SizeGB         = $item.SizeGB
                    UsedGB         = $item.UsedGB
                    DriveLetter    = $item.DriveLetter
                    Bus            = $item.Bus
                    BitLockerStatus = $item.BitLockerStatus
                    Status         = $item.Status
                }
                $script:selectedDisks += $diskCopy
            }
        }

        if ($script:selectedDisks.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "Aucun disque selectionne.",
                "CleanDisk",
                'OK',
                'Warning'
            ) | Out-Null
            return $false
        }

        # La page resume suffit - pas de confirmation supplementaire

        # Sauvegarder les infos client
        $script:customerInfo.Societe    = $cbSociete.Text.Trim()
        $script:customerInfo.Site       = $txtSite.Text.Trim()
        $script:customerInfo.Ville      = $txtVille.Text.Trim()
        $script:customerInfo.Technicien = $cbTechnicien.Text.Trim()

        # Definir les infos de session globales
        if (Get-Command Set-CdSessionInfo -ErrorAction SilentlyContinue) {
            Set-CdSessionInfo -CustomerName $script:customerInfo.Societe `
                             -SiteName $script:customerInfo.Site `
                             -City $script:customerInfo.Ville `
                             -TechnicianName $script:customerInfo.Technicien
        }

        # Sauvegarder le profil client pour reutilisation
        if (Get-Command Save-CdClientProfile -ErrorAction SilentlyContinue) {
            Save-CdClientProfile -ClientInfo $script:customerInfo | Out-Null
        }

        # Sauvegarder le technicien pour reutilisation
        if (Get-Command Save-CdTechnicianProfile -ErrorAction SilentlyContinue) {
            Save-CdTechnicianProfile -NomComplet $script:customerInfo.Technicien | Out-Null
        }

        # Sauvegarder les options
        $script:options.WipeMode = if ($rbSecure.IsChecked) { "Secure" } else { "Fast" }
        $script:options.BitLocker = $chkBitLocker.IsChecked
        $script:options.VolumeLabel = $txtVolumeLabel.Text.Trim()
        $script:options.CreatePartition = $chkCreatePartition.IsChecked

        # Passer a l'etape 4
        Update-StepDisplay -Step 4

        # Reinitialiser les controles
        $pbProgress.Value = 0
        $txtLogs.Text = ""
        $script:processedDisks = @()

        # Lancer l'effacement de maniere synchrone (pour eviter les problemes de Runspace)
        $totalDisks   = @($script:selectedDisks).Count
        $currentIndex = 0

        # Liste de securite : uniquement les disques effacables
        $allowedDisks = @()
        if (Get-Command Get-CdDiskList -ErrorAction SilentlyContinue) {
            try {
                $allowedDisks = Get-CdDiskList
            }
            catch {
                $timestampWarning = Get-Date -Format "HH:mm:ss"
                $txtLogs.AppendText("[$timestampWarning] [WARNING] Impossible de recuperer la liste securisee des disques (Get-CdDiskList).`r`n")
            }
        }

        $timestamp = Get-Date -Format "HH:mm:ss"
        $txtLogs.AppendText("[$timestamp] Debut de l'operation d'effacement...`r`n")
        $txtLogs.AppendText("[$timestamp] $totalDisks disque(s) a traiter`r`n`r`n")

        foreach ($disk in $script:selectedDisks) {
            $currentIndex++
            $timestamp = Get-Date -Format "HH:mm:ss"

            # Verifier que Number existe et n'est pas null
            if ($null -eq $disk.Number -or $disk.Number -eq '') {
                $txtLogs.AppendText("[$timestamp] [ERREUR] Le disque n'a pas de numero valide ! Skip.`r`n")
                continue
            }

            $diskNumber = [int]$disk.Number

            # SECURITE : revalider que ce disque fait partie des disques effacables
            if ($allowedDisks -and @($allowedDisks | Where-Object { $_.Number -eq $diskNumber }).Count -eq 0) {
                $txtLogs.AppendText("[$timestamp] [SECURITE] Le disque #$diskNumber ne fait pas partie de la liste des disques effacables (Get-CdDiskList). Skip.`r`n")
                continue
            }

            # Mise a jour UI
            $txtProgressInfo.Text = "Effacement du disque $currentIndex sur $totalDisks..."
            $txtCurrentDisk.Text = "Disque #$diskNumber - $($disk.Model)"
            $pbProgress.Value = (($currentIndex - 1) / $totalDisks) * 100

            $timestamp = Get-Date -Format "HH:mm:ss"
            $txtLogs.AppendText("[$timestamp] Debut effacement disque #$diskNumber ($($disk.Model))...`r`n")
            $txtLogs.ScrollToEnd()

            # Forcer le rafraichissement de l'UI
            [System.Windows.Forms.Application]::DoEvents()

            try {
                # Appeler directement la fonction d'effacement avec parametres explicites
                $targetDiskNumber = [int]$diskNumber
                $targetWipeMode = $script:options.WipeMode
                $targetVolumeLabel = if ([string]::IsNullOrWhiteSpace($script:options.VolumeLabel)) { "" } else { $script:options.VolumeLabel }
                $targetBitLocker = [bool]$script:options.BitLocker

                $txtLogs.AppendText("[$timestamp] Appel Invoke-CdDiskWipeAndFormat -DiskNumber $targetDiskNumber -WipeMode $targetWipeMode`r`n")
                if ($targetBitLocker) {
                    $txtLogs.AppendText("[$timestamp] [BitLocker] Pre-chiffrement des donnees existantes active (peut prendre plusieurs heures)...`r`n")
                }
                $txtLogs.ScrollToEnd()
                [System.Windows.Forms.Application]::DoEvents()

                # Appel DIRECT sans splatting pour eviter tout probleme
                $noPartitionFlag = -not $script:options.CreatePartition

                # Creer le callback BitLocker pour afficher la progression
                $bitlockerCallback = {
                    param([int]$percent)
                    $ts = Get-Date -Format "HH:mm:ss"
                    $txtLogs.AppendText("[$ts] [BitLocker] Chiffrement en cours : $percent%`r`n")
                    $txtLogs.ScrollToEnd()
                    [System.Windows.Forms.Application]::DoEvents()
                }

                if ($targetBitLocker -and $noPartitionFlag) {
                    $result = Invoke-CdDiskWipeAndFormat -DiskNumber $targetDiskNumber -WipeMode $targetWipeMode -VolumeLabel $targetVolumeLabel -PreEncryptWithBitLocker -NoPartition -BitLockerProgressCallback $bitlockerCallback
                }
                elseif ($targetBitLocker) {
                    $result = Invoke-CdDiskWipeAndFormat -DiskNumber $targetDiskNumber -WipeMode $targetWipeMode -VolumeLabel $targetVolumeLabel -PreEncryptWithBitLocker -BitLockerProgressCallback $bitlockerCallback
                }
                elseif ($noPartitionFlag) {
                    $result = Invoke-CdDiskWipeAndFormat -DiskNumber $targetDiskNumber -WipeMode $targetWipeMode -VolumeLabel $targetVolumeLabel -NoPartition
                }
                else {
                    $result = Invoke-CdDiskWipeAndFormat -DiskNumber $targetDiskNumber -WipeMode $targetWipeMode -VolumeLabel $targetVolumeLabel
                }

                $script:processedDisks += $result

                $timestamp = Get-Date -Format "HH:mm:ss"
                if ($result.Result -eq "Success") {
                    $txtLogs.AppendText("[$timestamp] [OK] Disque #$diskNumber efface avec succes (duree: $($result.DurationSeconds)s)`r`n")
                }
                else {
                    $txtLogs.AppendText("[$timestamp] [ECHEC] Disque #$diskNumber : $($result.ErrorMessage)`r`n")
                }
                $txtLogs.AppendText("`r`n")
                $txtLogs.ScrollToEnd()
            }
            catch {
                if (Get-Command Write-CdErrorLog -ErrorAction SilentlyContinue) {
                    Write-CdErrorLog -ErrorObject $_ -Context "Effacement disque #$diskNumber"
                }

                $timestamp = Get-Date -Format "HH:mm:ss"
                $txtLogs.AppendText("[$timestamp] [ERREUR] Disque #$diskNumber : $_`r`n`r`n")
                $txtLogs.ScrollToEnd()

                # Ajouter un enregistrement d'echec
                $script:processedDisks += [PSCustomObject]@{
                    DiskNumber      = $diskNumber
                    Model           = $disk.Model
                    SizeGB          = $disk.SizeGB -replace ' Go', ''
                    Bus             = $disk.Bus
                    Serial          = ""
                    WipeMode        = $script:options.WipeMode
                    DurationSeconds = 0
                    Result          = "Failed"
                    ErrorMessage    = $_.ToString()
                }
            }

            # Forcer le rafraichissement de l'UI
            [System.Windows.Forms.Application]::DoEvents()
        }

        # Fin de l'effacement
        $pbProgress.Value = 100
        $txtProgressInfo.Text = "Effacement termine !"
        $timestamp = Get-Date -Format "HH:mm:ss"
        $txtLogs.AppendText("[$timestamp] === OPERATION TERMINEE ===`r`n")
        $txtLogs.ScrollToEnd()

        # Preparer la grille Post-Actions
        $postList = @()
        foreach ($r in $script:processedDisks) {
            $duration = "$($r.DurationSeconds)s"
            $resultText = if ($r.Result -eq "Success") { "[OK] Reussi" } else { "[ECHEC] Echec" }

            $postList += [PSCustomObject]@{
                Number   = $r.DiskNumber
                Model    = $r.Model
                Serial   = if ($r.Serial) { $r.Serial } else { "(vide)" }
                SizeGB   = "$($r.SizeGB) Go"
                Duration = $duration
                Result   = $resultText
            }
        }
        $dgPostActions.ItemsSource = $postList

        # Passer a l'etape 5
        Update-StepDisplay -Step 5

        return $true
    }

    # ========================================
    # EVENEMENTS - Navigation
    # ========================================

    $btnNext.Add_Click({
        $step = $script:currentStep

        if ($step -eq 0) {
            # Dashboard -> Selection disques
            Update-StepDisplay -Step 1
            Load-DiskList
        }
        elseif ($step -eq 1) {
            # Verifier qu'au moins un disque est selectionne
            $selectedCount = @($script:diskCollection | Where-Object { $_.Selected -eq $true }).Count
            if ($selectedCount -eq 0) {
                [System.Windows.MessageBox]::Show(
                    "Veuillez selectionner au moins un disque.",
                    "CleanDisk",
                    'OK',
                    'Warning'
                ) | Out-Null
                return
            }
            Update-StepDisplay -Step 2
        }
        elseif ($step -eq 2) {
            # Valider les infos client
            if ([string]::IsNullOrWhiteSpace($cbSociete.Text)) {
                [System.Windows.MessageBox]::Show(
                    "Veuillez renseigner la societe/client.",
                    "CleanDisk",
                    'OK',
                    'Warning'
                ) | Out-Null
                return
            }
            if ([string]::IsNullOrWhiteSpace($cbTechnicien.Text)) {
                [System.Windows.MessageBox]::Show(
                    "Veuillez renseigner le nom du technicien.",
                    "CleanDisk",
                    'OK',
                    'Warning'
                ) | Out-Null
                return
            }
            Update-StepDisplay -Step 3
        }
        elseif ($step -eq 3) {
            # Aller vers la page de resume
            Update-SummaryPage
            Update-StepDisplay -Step 35
        }
        elseif ($step -eq 35) {
            # Lancer l'effacement depuis la page de resume
            Start-WipeProcess
        }
        elseif ($step -eq 5) {
            # Generer les fichiers AVANT de passer a l'etape 6
            $window.Cursor = [System.Windows.Input.Cursors]::Wait

            try {
                # Ouvrir la fenetre d'edition des Serial Numbers
                if (Get-Command Show-CdEditSerialWindow -ErrorAction SilentlyContinue) {
                    $updatedRecords = Show-CdEditSerialWindow -DiskRecords $script:processedDisks

                    if ($null -ne $updatedRecords) {
                        $script:processedDisks = $updatedRecords
                    }
                }

                # Generer le certificat PDF client
                $script:generatedPdfPath = $null
                if (Get-Command New-CdCertificatePdf -ErrorAction SilentlyContinue) {
                    $script:generatedPdfPath = New-CdCertificatePdf -DiskRecords $script:processedDisks `
                                                                    -CustomerInfo $script:customerInfo
                }

                # Generer le rapport HTML interne
                $script:generatedHtmlPath = $null
                if (Get-Command New-CdInternalReport -ErrorAction SilentlyContinue) {
                    $script:generatedHtmlPath = New-CdInternalReport -DiskRecords $script:processedDisks `
                                                                     -CustomerInfo $script:customerInfo `
                                                                     -Options $script:options
                }

                # Generer/MAJ l'historique client et dashboard
                if (Get-Command New-CdClientHistory -ErrorAction SilentlyContinue) {
                    try { New-CdClientHistory -CustomerName $script:customerInfo.Societe | Out-Null } catch { }
                }
                if (Get-Command New-CdDashboard -ErrorAction SilentlyContinue) {
                    try { New-CdDashboard | Out-Null } catch { }
                }

                # Afficher les chemins sur la page Etape 6
                $txtCertificatePath.Text = if ($script:generatedPdfPath) { $script:generatedPdfPath } else { "(non genere)" }
                $txtRapportPath.Text = if ($script:generatedHtmlPath) { $script:generatedHtmlPath } else { "(non genere)" }
            }
            finally {
                $window.Cursor = [System.Windows.Input.Cursors]::Arrow
            }

            Update-StepDisplay -Step 6
        }
    })

    $btnPrevious.Add_Click({
        $step = $script:currentStep

        if ($step -eq 1) {
            Update-StepDisplay -Step 0
        }
        elseif ($step -eq 2) {
            Update-StepDisplay -Step 1
        }
        elseif ($step -eq 3) {
            Update-StepDisplay -Step 2
        }
        elseif ($step -eq 35) {
            Update-StepDisplay -Step 3
        }
    })

    $btnCancel.Add_Click({
        if ($script:currentStep -eq 4) {
            [System.Windows.MessageBox]::Show(
                "Impossible d'annuler pendant l'effacement.",
                "CleanDisk",
                'OK',
                'Warning'
            ) | Out-Null
            return
        }

        $choice = [System.Windows.MessageBox]::Show(
            "Etes-vous sur de vouloir quitter ?",
            "CleanDisk",
            'YesNo',
            'Question'
        )

        if ($choice -eq [System.Windows.MessageBoxResult]::Yes) {
            $window.Close()
        }
    })

    # ========================================
    # EVENEMENTS - Dashboard (Etape 0)
    # ========================================

    # Double-clic sur une ligne du dashboard pour ouvrir les details du client
    $dgRecentActivity.Add_MouseDoubleClick({
        param($sender, $e)

        try {
            $selectedItem = $dgRecentActivity.SelectedItem
            if ($selectedItem -and $selectedItem.Customer) {
                $customerName = $selectedItem.Customer

                # Afficher la fenetre de details client
                if (Get-Command Show-CdClientDetailsWindow -ErrorAction SilentlyContinue) {
                    $clientResult = Show-CdClientDetailsWindow -CustomerName $customerName -ParentWindow $window

                    if ($clientResult.StartNewSession -eq $true -and $clientResult.CustomerInfo) {
    # Pre-remplir les infos client (ils seront visibles a l'etape 2)
    $cbSociete.Text = $clientResult.CustomerInfo.Societe
    $txtSite.Text   = $clientResult.CustomerInfo.Site
    $txtVille.Text  = $clientResult.CustomerInfo.Ville

    # Charger la liste des disques
    Load-DiskList

    # Démarrer sur l'etape 1 = selection des disques
    Update-StepDisplay -Step 1
}

                }
            }
        }
        catch {
            Write-Verbose "[DgRecentActivity DoubleClick] Erreur : $_"
        }
    })

    # ========================================
    # EVENEMENTS - Etape 1
    # ========================================

    $btnSelectAll.Add_Click({
        foreach ($item in $script:diskCollection) {
            $item.Selected = $true
        }
        $dgDisks.Items.Refresh()
    })

    $btnDeselectAll.Add_Click({
        foreach ($item in $script:diskCollection) {
            $item.Selected = $false
        }
        $dgDisks.Items.Refresh()
    })

    # Evenement : Simple clic sur une ligne du DataGrid pour basculer la selection
    $dgDisks.Add_PreviewMouseLeftButtonUp({
        param($sender, $e)

        try {
            # Ignorer si on clique sur la checkbox elle-meme
            $source = $e.OriginalSource
            if ($source -is [System.Windows.Controls.Primitives.ToggleButton]) {
                return
            }

            $clickedItem = $dgDisks.SelectedItem
            if ($clickedItem -ne $null -and $clickedItem -is [DiskItem]) {
                $clickedItem.Selected = -not $clickedItem.Selected
                $dgDisks.Items.Refresh()
            }
        }
        catch {
            Write-Verbose "[DgDisks PreviewMouseLeftButtonUp] Erreur : $_"
        }
    })

    # ========================================
    # EVENEMENTS - Etape 2 (Clients et Techniciens)
    # ========================================

    function Load-ClientProfiles {
        try {
            $script:profiles = @()
            if (Get-Command Get-CdClientProfiles -ErrorAction SilentlyContinue) {
                $script:profiles = Get-CdClientProfiles
            }

            $cbSociete.Items.Clear()

            foreach ($profile in $script:profiles) {
                $cbSociete.Items.Add($profile.Societe) | Out-Null
            }

            Write-Verbose "[Load-ClientProfiles] $($script:profiles.Count) profils charges"
        }
        catch {
            Write-Warning "[Load-ClientProfiles] Erreur : $_"
        }
    }

    function Load-TechnicianProfiles {
        try {
            $script:technicians = @()
            if (Get-Command Get-CdTechnicianProfiles -ErrorAction SilentlyContinue) {
                $script:technicians = Get-CdTechnicianProfiles
            }

            $cbTechnicien.Items.Clear()

            foreach ($tech in $script:technicians) {
                $cbTechnicien.Items.Add($tech.NomComplet) | Out-Null
            }

            Write-Verbose "[Load-TechnicianProfiles] $($script:technicians.Count) techniciens charges"
        }
        catch {
            Write-Warning "[Load-TechnicianProfiles] Erreur : $_"
        }
    }

    # Charger les profils au demarrage
    Load-ClientProfiles
    Load-TechnicianProfiles

    # Evenement : Ouvrir la liste deroulante quand on clique dans la ComboBox Client
    $cbSociete.Add_GotFocus({
        $cbSociete.IsDropDownOpen = $true
    })

    # Evenement : Ouvrir la liste deroulante quand on clique dans la ComboBox Technicien
    $cbTechnicien.Add_GotFocus({
        $cbTechnicien.IsDropDownOpen = $true
    })

    # Evenement : Selection d'un client dans la ComboBox
    $cbSociete.Add_SelectionChanged({
        try {
            $selectedSociete = $cbSociete.SelectedItem

            if ($selectedSociete -and $script:profiles) {
                $matchingProfile = $script:profiles | Where-Object { $_.Societe -eq $selectedSociete } | Select-Object -First 1

                if ($matchingProfile) {
                    # Auto-remplir les champs SAUF le technicien
                    $txtSite.Text = $matchingProfile.Site
                    $txtVille.Text = $matchingProfile.Ville
                    # NE PAS remplir le technicien automatiquement
                    # $cbTechnicien.Text = ""

                    Write-Verbose "[ComboBox] Profil client charge : $($matchingProfile.Societe)"
                }
            }
        }
        catch {
            Write-Warning "[ComboBox SelectionChanged] Erreur : $_"
        }
    })

    # ========================================
    # EVENEMENTS - Etape 5
    # ========================================

    # Bouton pour assigner les lettres de lecteur aux disques traites
    $btnAssignLetters.Add_Click({
        try {
            $window.Cursor = [System.Windows.Input.Cursors]::Wait

            $assignCount = 0
            foreach ($r in $script:processedDisks) {
                if ($r.Result -eq "Success") {
                    try {
                        # Recuperer la partition du disque
                        $partition = Get-Partition -DiskNumber $r.DiskNumber -ErrorAction SilentlyContinue |
                                     Where-Object { $_.Type -eq 'Basic' } |
                                     Select-Object -First 1

                        if ($partition -and -not $partition.DriveLetter) {
                            # Assigner une lettre de lecteur
                            $partition | Add-PartitionAccessPath -AssignDriveLetter -ErrorAction Stop
                            $assignCount++
                        }
                        elseif ($partition -and $partition.DriveLetter) {
                            # Deja une lettre assignee
                            $assignCount++
                        }
                    }
                    catch {
                        Write-Verbose "[BtnAssignLetters] Erreur disque $($r.DiskNumber) : $_"
                    }
                }
            }

            [System.Windows.MessageBox]::Show(
                "$assignCount disque(s) avec lettre de lecteur assignee.",
                "CleanDisk",
                'OK',
                'Information'
            ) | Out-Null
        }
        finally {
            $window.Cursor = [System.Windows.Input.Cursors]::Arrow
        }
    })

    $btnEjectAll.Add_Click({
        try {
            $window.Cursor = [System.Windows.Input.Cursors]::Wait

            $ejectCount = 0
            foreach ($r in $script:processedDisks) {
                if ($r.Result -eq "Success") {
                    if (Get-Command Invoke-CdDiskEject -ErrorAction SilentlyContinue) {
                        $ejected = Invoke-CdDiskEject -DiskNumber $r.DiskNumber
                        if ($ejected) {
                            $ejectCount++
                        }
                    }
                }
            }

            [System.Windows.MessageBox]::Show(
                "$ejectCount disque(s) ejecte(s) avec succes.",
                "CleanDisk",
                'OK',
                'Information'
            ) | Out-Null
        }
        finally {
            $window.Cursor = [System.Windows.Input.Cursors]::Arrow
        }
    })

    # ========================================
    # EVENEMENTS - Etape 6
    # ========================================

    $btnRestartSameClient.Add_Click({
        # Reinitialiser uniquement la selection de disques, garder les infos client
        Update-StepDisplay -Step 1
        Load-DiskList
        $pbProgress.Value = 0
        $txtLogs.Text = ""
        $script:processedDisks = @()
    })

    $btnRestartNewClient.Add_Click({
        # Reinitialiser tout - nouveau client = retour au dashboard
        $cbSociete.Text = ""
        $txtSite.Text = ""
        $txtVille.Text = ""
        # Garder le technicien (c'est probablement le meme)
        $script:customerInfo = @{
            Societe    = ""
            Site       = ""
            Ville      = ""
            Technicien = $script:customerInfo.Technicien
        }
        $script:selectedDisks = @()
        $script:processedDisks = @()
        $pbProgress.Value = 0
        $txtLogs.Text = ""

        # Retour au dashboard pour voir l'activite recente
        Load-DashboardStats
        Update-StepDisplay -Step 0
    })

    # Bouton pour ouvrir le dossier des logs
    $btnOpenLogsFolder.Add_Click({
        try {
            $logsPath = $global:CdLogsPath
            if (-not $logsPath) {
                $logsPath = Join-Path (Get-CdRootDirectory) 'Logs'
            }
            if (Test-Path $logsPath) {
                Start-Process explorer.exe -ArgumentList $logsPath
            }
        }
        catch {
            Write-Warning "[BtnOpenLogsFolder] Erreur : $_"
        }
    })

    $btnFinish.Add_Click({
        # Fermer la fenetre
        $window.Close()
    })

    # ========================================
    # INITIALISATION ET AFFICHAGE
    # ========================================

    # Charger les stats du dashboard
    Load-DashboardStats

    # Afficher le Dashboard (Etape 0)
    Update-StepDisplay -Step 0

    # Valeurs par defaut - Volume label vide
    $txtVolumeLabel.Text = ""

    # Charger Windows.Forms pour DoEvents
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    }
    catch {
        Write-Verbose "System.Windows.Forms deja charge"
    }

    # Affichage de la fenetre
    $null = $window.ShowDialog()
}
