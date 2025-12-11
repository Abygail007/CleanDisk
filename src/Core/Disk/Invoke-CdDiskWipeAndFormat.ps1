function Invoke-CdDiskWipeAndFormat {
    <#
        .SYNOPSIS
        Efface et formate un disque selon un mode choisi.

        .DESCRIPTION
        - WipeMode 'Fast'   : Clear-Disk + GPT + partition + format NTFS rapide
        - WipeMode 'Secure' : Clear-Disk + GPT + partition + format NTFS complet (-Full)

        Si PreEncryptWithBitLocker est active, le disque est d'abord chiffre avec
        BitLocker (donnees EXISTANTES), puis efface. Cela garantit que les donnees
        sont irrecuperables meme avec des outils de forensics.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # Numero du disque a effacer (OBLIGATOIRE)
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber,

        # Etiquette du volume apres formatage (vide par defaut)
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$VolumeLabel = "",

        # Mode d'effacement
        [ValidateSet('Fast', 'Secure')]
        [string]$WipeMode = 'Fast',

        # Option : pre-chiffrement BitLocker avant effacement
        [switch]$PreEncryptWithBitLocker,

        # Option : NE PAS creer de partition apres le wipe (defaut: on cree)
        [switch]$NoPartition,

        # Callback pour la progression BitLocker (0-100)
        [Parameter(Mandatory = $false)]
        [scriptblock]$BitLockerProgressCallback
    )

    # UTILISER DIRECTEMENT LE PARAMETRE - PAS DE VARIABLE INTERMEDIAIRE
    $diskNumber = $DiskNumber

    Write-Verbose "[Invoke-CdDiskWipeAndFormat] DiskNumber recu = $diskNumber"

    # Desactiver les popups Windows "Inserer un disque" pendant l'operation
    $ErrorModeType = @"
using System;
using System.Runtime.InteropServices;
public class ErrorMode {
    [DllImport("kernel32.dll")]
    public static extern uint SetErrorMode(uint uMode);
    public const uint SEM_FAILCRITICALERRORS = 0x0001;
    public const uint SEM_NOGPFAULTERRORBOX = 0x0002;
    public const uint SEM_NOOPENFILEERRORBOX = 0x8000;
}
"@
    try {
        Add-Type -TypeDefinition $ErrorModeType -ErrorAction SilentlyContinue
    } catch { }

    # Sauvegarder le mode d'erreur actuel et desactiver les popups
    $oldErrorMode = $null
    try {
        $oldErrorMode = [ErrorMode]::SetErrorMode([ErrorMode]::SEM_FAILCRITICALERRORS -bor [ErrorMode]::SEM_NOOPENFILEERRORBOX)
    } catch {
        Write-Verbose "[Invoke-CdDiskWipeAndFormat] Impossible de desactiver les popups Windows"
    }

    # Recuperer les infos du disque via Get-Disk
    $model  = "Inconnu"
    $sizeGB = 0
    $bus    = "Inconnu"

    try {
        $msftDiskInfo = Get-Disk -Number $diskNumber -ErrorAction Stop
        if ($msftDiskInfo.FriendlyName) {
            $model = $msftDiskInfo.FriendlyName
        }
        if ($msftDiskInfo.Size -ne $null) {
            $sizeGB = [math]::Round($msftDiskInfo.Size / 1GB, 1)
        }
        if ($msftDiskInfo.BusType) {
            $bus = $msftDiskInfo.BusType
        }
    }
    catch {
        Write-Warning "[Invoke-CdDiskWipeAndFormat] Impossible de recuperer les infos du disque $diskNumber : $_"
    }

    # Récupérer le numéro de série avant effacement
    $serialNumber = ""
    try {
        if (Get-Command Get-CdDiskSerial -ErrorAction SilentlyContinue) {
            $serialNumber = Get-CdDiskSerial -DiskNumber $diskNumber
        }
    }
    catch {
        Write-Verbose "Impossible de récupérer le S/N du disque $diskNumber"
    }

    $startTime = Get-Date
    $endTime   = $null
    $duration  = $null
    $driveLetter = ""
    $result      = "Failed"
    $errorMessage = ""

    $preEncryptFlag = $false
    if ($PreEncryptWithBitLocker.IsPresent) {
        $preEncryptFlag = $true
    }

    if (-not $PSCmdlet.ShouldProcess("Disque $diskNumber ($model, $sizeGB Go)", "Effacement $WipeMode")) {
        return
    }

    # Activer la protection anti-veille
    try {
        if (Get-Command Enter-CdNoSleep -ErrorAction SilentlyContinue) {
            Enter-CdNoSleep
        }
    }
    catch {
        Write-Verbose "Protection anti-veille non disponible"
    }

    try {
        # SECURITE CRITIQUE : Verifier que ce n'est pas le disque contenant C:
        $cPartition = Get-Partition -DriveLetter 'C' -ErrorAction SilentlyContinue
        if ($cPartition -and $cPartition.DiskNumber -eq $diskNumber) {
            throw "SECURITE : Le disque $diskNumber contient le lecteur C: (Windows). Effacement INTERDIT."
        }

        # S'assurer que le disque n'est ni offline ni en read-only
        $msftDisk = Get-Disk -Number $diskNumber -ErrorAction Stop

        if ($msftDisk.IsBoot -or $msftDisk.IsSystem) {
            throw "Par securite, un disque marque comme systeme ou de boot ne peut pas etre efface (DiskNumber = $diskNumber)."
        }

        if ($msftDisk.IsOffline) {
            Set-Disk -Number $diskNumber -IsOffline:$false -ErrorAction Stop
        }
        if ($msftDisk.IsReadOnly) {
            Set-Disk -Number $diskNumber -IsReadOnly:$false -ErrorAction Stop
        }

        # Pre-chiffrement BitLocker si demande - AVANT de retirer les lettres de lecteur
        # IMPORTANT : On chiffre les donnees EXISTANTES, pas un disque vide !
        if ($preEncryptFlag) {
            Write-Verbose "[Invoke-CdDiskWipeAndFormat] Pre-chiffrement BitLocker demande (donnees existantes)..."

            # S'assurer qu'il y a une lettre de lecteur pour BitLocker
            $blDriveLetter = $null
            $partitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue |
                          Where-Object { $_.DriveLetter }

            if ($partitions) {
                $blDriveLetter = ($partitions | Select-Object -First 1).DriveLetter
                Write-Verbose "[Invoke-CdDiskWipeAndFormat] Lettre de lecteur existante : $blDriveLetter"
            }
            else {
                # Essayer d'assigner une lettre temporaire pour BitLocker
                $allPartitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue |
                                 Where-Object { $_.Type -ne 'Reserved' -and $_.Size -gt 100MB }

                if ($allPartitions) {
                    $targetPartition = $allPartitions | Select-Object -First 1
                    $availableLetters = [char[]](69..90) | Where-Object { -not (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue) }

                    if ($availableLetters) {
                        $blDriveLetter = $availableLetters[0]
                        Add-PartitionAccessPath -DiskNumber $diskNumber `
                                               -PartitionNumber $targetPartition.PartitionNumber `
                                               -AccessPath "$($blDriveLetter):" `
                                               -ErrorAction SilentlyContinue
                        Write-Verbose "[Invoke-CdDiskWipeAndFormat] Lettre temporaire assignee : $blDriveLetter"
                    }
                }
            }

            if ($blDriveLetter) {
                if (Get-Command Enable-CdBitLockerEncryption -ErrorAction SilentlyContinue) {
                    # Passer le callback de progression si fourni
                    $blParams = @{
                        DiskNumber  = $diskNumber
                        DriveLetter = $blDriveLetter
                    }

                    if ($BitLockerProgressCallback) {
                        $blParams['ProgressCallback'] = $BitLockerProgressCallback
                    }

                    $blResult = Enable-CdBitLockerEncryption @blParams

                    if (-not $blResult) {
                        Write-Warning "[Invoke-CdDiskWipeAndFormat] Echec du pre-chiffrement BitLocker. Continuation sans."
                    }
                    else {
                        Write-Verbose "[Invoke-CdDiskWipeAndFormat] Pre-chiffrement BitLocker termine avec succes."
                    }
                }
                else {
                    Write-Warning "[Invoke-CdDiskWipeAndFormat] Fonction Enable-CdBitLockerEncryption non disponible."
                }
            }
            else {
                Write-Warning "[Invoke-CdDiskWipeAndFormat] Aucune partition trouvee pour BitLocker. Continuation sans chiffrement."
            }
        }

        # APRES BitLocker : retirer toutes les lettres de lecteur avant l'effacement
        try {
            $partitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
            if ($partitions) {
                foreach ($part in $partitions) {
                    if ($part.DriveLetter) {
                        $accessPath = ("{0}:" -f $part.DriveLetter)
                        Write-Verbose "[Invoke-CdDiskWipeAndFormat] Suppression de l'acces $accessPath avant Clear-Disk..."
                        Remove-PartitionAccessPath -DiskNumber $diskNumber `
                                                   -PartitionNumber $part.PartitionNumber `
                                                   -AccessPath $accessPath `
                                                   -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        catch {
            Write-Verbose "[Invoke-CdDiskWipeAndFormat] Impossible de retirer les lettres de lecteur : $_"
        }

        # 1) Effacement du disque selon le mode choisi (Fast ou Secure)
        Write-Verbose "[Invoke-CdDiskWipeAndFormat] Lancement effacement mode $WipeMode..."
        $wipeResult = Invoke-CdDiskWipe -DiskNumber $diskNumber -WipeMode $WipeMode -ErrorAction Stop
        
        if (-not $wipeResult) {
            throw "Echec de l'effacement du disque #$diskNumber"
        }

        # 2) Creer partition et formater SI demande (par defaut oui, sauf si -NoPartition)
        if (-not $NoPartition.IsPresent) {
            # S'assurer que le disque est bien en GPT
            $diskAfterClear = Get-Disk -Number $diskNumber -ErrorAction Stop

            if ($diskAfterClear.PartitionStyle -eq 'RAW') {
                Initialize-Disk -Number $diskNumber -PartitionStyle GPT -ErrorAction Stop
            }
            elseif ($diskAfterClear.PartitionStyle -ne 'GPT') {
                Set-Disk -Number $diskNumber -PartitionStyle GPT -ErrorAction Stop
            }

            # Mettre le disque OFFLINE pour empecher Windows Explorer de le detecter
            Set-Disk -Number $diskNumber -IsOffline $true -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 200

            # Remettre online pour creer la partition
            Set-Disk -Number $diskNumber -IsOffline $false -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 200

            # Nouvelle partition SANS lettre de lecteur (pour eviter le popup Windows Shell)
            $partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -ErrorAction Stop

            # Formater la partition
            $formatParams = @{
                Partition   = $partition
                FileSystem  = 'NTFS'
                Confirm     = $false
                ErrorAction = 'Stop'
            }

            if (-not [string]::IsNullOrWhiteSpace($VolumeLabel)) {
                $formatParams['NewFileSystemLabel'] = $VolumeLabel
            }

            $vol = Format-Volume @formatParams

            # NE PAS assigner de lettre de lecteur automatiquement
            # Cela evite les popups Windows "D:\ n'est pas accessible"
            # L'utilisateur peut assigner une lettre manuellement via le bouton a l'etape 5
            $driveLetter = ""
            Write-Verbose "[Invoke-CdDiskWipeAndFormat] Partition creee et formatee SANS lettre de lecteur (evite popup)"
        }
        else {
            # Mode sans partition - le disque reste vierge apres le wipe
            $driveLetter = ""
            Write-Verbose "[Invoke-CdDiskWipeAndFormat] Option -NoPartition : pas de partition creee"
        }

        $endTime  = Get-Date
        $duration = [int]([math]::Round(($endTime - $startTime).TotalSeconds, 0))
        $result   = "Success"
        $errorMessage = ""
    }
    catch {
        $endTime  = Get-Date
        $duration = [int]([math]::Round(($endTime - $startTime).TotalSeconds, 0))
        $result   = "Failed"
        $errorMessage = $_.Exception.Message
    }
    finally {
        # Restaurer le mode d'erreur Windows (re-activer les popups)
        try {
            if ($oldErrorMode -ne $null) {
                [ErrorMode]::SetErrorMode($oldErrorMode) | Out-Null
            }
        }
        catch {
            Write-Verbose "[Invoke-CdDiskWipeAndFormat] Impossible de restaurer le mode d'erreur Windows"
        }

        # Désactiver la protection anti-veille
        try {
            if (Get-Command Exit-CdNoSleep -ErrorAction SilentlyContinue) {
                Exit-CdNoSleep
            }
        }
        catch {
            Write-Verbose "Impossible de désactiver la protection anti-veille"
        }
    }

    # Journalisation dans l'audit CleanDisk
    try {
        # Construction de l'enregistrement complet (compatible avec l'ancien XML)
        $record = [pscustomobject]@{
            DiskNumber              = $diskNumber
            Model                   = $model
            SizeGB                  = $sizeGB
            Bus                     = $bus
            Serial                  = $serialNumber
            WipeMode                = $WipeMode
            PreEncryptWithBitLocker = $preEncryptFlag
            StartTime               = $startTime
            EndTime                 = $endTime
            DurationSeconds         = $duration
            DriveLetter             = $driveLetter
            ComputerName            = $env:COMPUTERNAME
            UserName                = $env:USERNAME
            Result                  = $result
            ErrorMessage            = $errorMessage

            # Contexte de session (pour le certificat)
            CustomerName            = $global:CdCustomerName
            SiteName                = $global:CdSiteName
            City                    = $global:CdCity
            TechnicianName          = $global:CdTechnicianName
            SessionId               = $global:CdSessionId
        }

        if (Get-Command Add-CdDiskAuditRecord -ErrorAction SilentlyContinue) {
            Add-CdDiskAuditRecord -Record $record
        }

        # On renvoie aussi le record à l'appelant (GUI)
        return $record
    }
    catch {
        Write-Warning ("Impossible d'ajouter l'entrée d'audit pour le disque {0} : {1}" -f $diskNumber, $_.Exception.Message)
    }
}
