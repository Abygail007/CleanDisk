function Invoke-CdDiskPartitionAndFormat {
    <#
        .SYNOPSIS
        Initialise un disque en GPT, crée une partition et formate en NTFS.

        .PARAMETER DiskNumber
        Numéro du disque.

        .PARAMETER VolumeLabel
        Nom du volume (label NTFS).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber,

        [string]$VolumeLabel = "DATA"
    )

    $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop

    if ($disk.IsSystem -or $disk.IsBoot) {
        throw "Le disque $DiskNumber est un disque système ou de démarrage. Opération annulée."
    }

    # Si le disque est encore RAW après Clear-Disk, on l'initialise en GPT
    if ($disk.PartitionStyle -eq 'RAW') {
        $disk = Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -PassThru -ErrorAction Stop
    }

    # Création d'une partition qui prend tout l'espace avec lettre auto
    $partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
    $driveLetter = $partition.DriveLetter

    if (-not $driveLetter) {
        throw "Impossible de récupérer une lettre de lecteur pour le disque $DiskNumber."
    }

    # Formatage en NTFS
    $volume = Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel $VolumeLabel -Confirm:$false -ErrorAction Stop

    # On retourne uniquement la lettre, pas l'objet complet
    return $volume.DriveLetter
}
