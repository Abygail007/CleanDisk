function Show-CdEditSerialWindow {
    <#
        .SYNOPSIS
        Affiche une fenêtre pour éditer manuellement les Serial Numbers des disques.
        
        .PARAMETER DiskRecords
        Liste des enregistrements de disques à éditer.
        
        .OUTPUTS
        Tableau d'objets avec les Serial Numbers mis à jour, ou $null si annulé.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$DiskRecords
    )

    # Chargement des assemblies WPF
    try {
        Add-Type -AssemblyName PresentationCore       -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationFramework  -ErrorAction SilentlyContinue
        Add-Type -AssemblyName WindowsBase            -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "[Show-CdEditSerialWindow] Impossible de charger les assemblies WPF : $_"
        return $null
    }

    if (-not $global:CdSrcPath) {
        $root             = Get-CdRootDirectory
        $global:CdSrcPath = Join-Path $root 'src'
    }

    $xamlPath = Join-Path $global:CdSrcPath 'UI\Edit-SerialNumbers.xaml'

    if (-not (Test-Path -LiteralPath $xamlPath)) {
        Write-Error "Fichier XAML introuvable : $xamlPath"
        return $null
    }

    $xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8

    $stringReader = New-Object System.IO.StringReader $xaml
    $xmlReader    = [System.Xml.XmlReader]::Create($stringReader)

    $window = [Windows.Markup.XamlReader]::Load($xmlReader)

    # Récupération des contrôles
    $dgSerialNumbers = $window.FindName('DgSerialNumbers')
    $btnCancel       = $window.FindName('BtnCancel')
    $btnValidate     = $window.FindName('BtnValidate')

    # Préparer les données
    $editableList = @()
    foreach ($record in $DiskRecords) {
        # Créer un objet avec propriétés modifiables
        $obj = New-Object PSObject -Property @{
            Number = $record.DiskNumber
            Model  = $record.Model
            SizeGB = "$($record.SizeGB) Go"
            Serial = if ($record.Serial) { $record.Serial } else { "" }
        }
        
        # Ajouter les propriétés comme notifyPropertyChanged (pour binding)
        $obj.PSObject.TypeNames.Insert(0, 'System.ComponentModel.INotifyPropertyChanged')
        
        $editableList += $obj
    }

    $dgSerialNumbers.ItemsSource = $editableList

    # Variable pour stocker le résultat
    $script:result = $null

    # Événement : Annuler
    $btnCancel.Add_Click({
        $script:result = $null
        $window.DialogResult = $false
        $window.Close()
    })

    # Événement : Valider
    $btnValidate.Add_Click({
        # Récupérer les données modifiées
        $updatedRecords = @()
        
        for ($i = 0; $i -lt $DiskRecords.Count; $i++) {
            $original = $DiskRecords[$i]
            $edited   = $editableList[$i]
            
            # Créer une copie de l'enregistrement original avec le S/N mis à jour
            $updated = $original.PSObject.Copy()
            $updated.Serial = $edited.Serial.Trim()
            
            $updatedRecords += $updated
        }
        
        $script:result = $updatedRecords
        $window.DialogResult = $true
        $window.Close()
    })

    # Affichage de la fenêtre (modal)
    $dialogResult = $window.ShowDialog()

    if ($dialogResult -eq $true) {
        return $script:result
    }
    else {
        return $null
    }
}
