function Enable-CdBitLockerEncryption {
    <#
        .SYNOPSIS
        Pre-chiffre un disque avec BitLocker avant effacement (securite maximale).

        .DESCRIPTION
        Cette fonction chiffre le disque EXISTANT avec BitLocker (les donnees actuelles).
        Cela rend les donnees completement inaccessibles avant l'effacement.

        IMPORTANT : NE PAS faire de Clear-Disk avant ! Le but est de chiffrer les donnees existantes.

        ATTENTION : Operation TRES LONGUE (plusieurs heures selon la taille).

        .PARAMETER DiskNumber
        Numero du disque a chiffrer.

        .PARAMETER DriveLetter
        Lettre du lecteur a chiffrer (ex: "D").

        .PARAMETER ProgressCallback
        Scriptblock appele avec le pourcentage de progression (0-100).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber,

        [Parameter(Mandatory = $false)]
        [string]$DriveLetter,

        [Parameter(Mandatory = $false)]
        [scriptblock]$ProgressCallback
    )

    # Fonction helper pour obtenir le pourcentage via manage-bde (plus fiable)
    function Get-BitLockerProgressFromManageBde {
        param([string]$Volume)

        try {
            $output = & manage-bde -status $Volume 2>&1
            $outputText = $output -join "`n"

            # Chercher "Pourcentage de chiffrement" ou "Percentage Encrypted"
            if ($outputText -match "Pourcentage.*?:\s*(\d+)[,.]?\d*\s*%") {
                return [int]$Matches[1]
            }
            elseif ($outputText -match "Percentage Encrypted.*?:\s*(\d+)[,.]?\d*\s*%") {
                return [int]$Matches[1]
            }
            elseif ($outputText -match "(\d+)[,.]?\d*\s*%") {
                return [int]$Matches[1]
            }

            return -1
        }
        catch {
            return -1
        }
    }

    # Fonction helper pour verifier si le chiffrement est termine
    function Test-BitLockerEncryptionComplete {
        param([string]$Volume)

        try {
            $output = & manage-bde -status $Volume 2>&1
            $outputText = $output -join "`n"

            # Chercher "Entierement chiffre" ou "Fully Encrypted"
            if ($outputText -match "Entierement chiffre|Fully Encrypted|100[,.]?\d*\s*%") {
                return $true
            }

            return $false
        }
        catch {
            return $false
        }
    }

    try {
        Write-Verbose "[Enable-CdBitLockerEncryption] Debut pre-chiffrement BitLocker pour disque #$DiskNumber"

        # Verifier si BitLocker est disponible
        $bitlockerFeature = Get-WindowsOptionalFeature -Online -FeatureName "BitLocker" -ErrorAction SilentlyContinue
        if (-not $bitlockerFeature -or $bitlockerFeature.State -ne "Enabled") {
            throw "BitLocker n'est pas active sur ce systeme. Activez-le dans 'Fonctionnalites Windows'."
        }

        # Si pas de lettre fournie, recuperer la premiere partition avec une lettre
        if (-not $DriveLetter) {
            $partition = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue |
                         Where-Object { $_.DriveLetter } |
                         Select-Object -First 1

            if (-not $partition) {
                # Essayer d'assigner une lettre temporaire
                Write-Verbose "[Enable-CdBitLockerEncryption] Aucune lettre trouvee, tentative d'assignation..."
                $allPartitions = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue |
                                 Where-Object { $_.Type -ne 'Reserved' -and $_.Size -gt 100MB }

                if ($allPartitions) {
                    $targetPartition = $allPartitions | Select-Object -First 1
                    $availableLetters = [char[]](69..90) | Where-Object { -not (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue) }

                    if ($availableLetters) {
                        $tempLetter = $availableLetters[0]
                        Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $targetPartition.PartitionNumber -AccessPath "$($tempLetter):" -ErrorAction Stop
                        $DriveLetter = $tempLetter
                        Write-Verbose "[Enable-CdBitLockerEncryption] Lettre $DriveLetter assignee temporairement"
                    }
                    else {
                        throw "Aucune lettre de lecteur disponible"
                    }
                }
                else {
                    throw "Aucune partition utilisable trouvee sur le disque #$DiskNumber"
                }
            }
            else {
                $DriveLetter = $partition.DriveLetter
            }
        }

        $volume = "$($DriveLetter):"

        Write-Verbose "[Enable-CdBitLockerEncryption] Chiffrement du volume $volume (donnees existantes)..."

        # Verifier que le volume existe et est accessible
        if (-not (Test-Path $volume)) {
            throw "Le volume $volume n'existe pas ou n'est pas accessible"
        }

        # Verifier si BitLocker est deja actif sur ce volume
        $existingBL = Get-BitLockerVolume -MountPoint $volume -ErrorAction SilentlyContinue
        if ($existingBL -and $existingBL.ProtectionStatus -eq "On") {
            Write-Warning "[Enable-CdBitLockerEncryption] BitLocker est deja actif sur $volume"
            return $true
        }

        # Generer un mot de passe aleatoire fort (20 caracteres)
        $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%'
        $randomPassword = -join (1..20 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
        $securePassword = ConvertTo-SecureString -String $randomPassword -AsPlainText -Force

        # Verifier l'espace utilise sur le volume pour optimiser le chiffrement
        # Si le disque est presque vide, utiliser UsedSpaceOnly (beaucoup plus rapide)
        $useUsedSpaceOnly = $false
        try {
            $volInfo = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
            if ($volInfo) {
                $usedSpaceGB = [math]::Round(($volInfo.Size - $volInfo.SizeRemaining) / 1GB, 2)
                $totalSpaceGB = [math]::Round($volInfo.Size / 1GB, 2)
                $usedPercent = if ($totalSpaceGB -gt 0) { [math]::Round(($usedSpaceGB / $totalSpaceGB) * 100, 1) } else { 0 }

                Write-Verbose "[Enable-CdBitLockerEncryption] Volume $volume : $usedSpaceGB Go utilises sur $totalSpaceGB Go ($usedPercent%)"

                # Si moins de 5% utilise ou moins de 1 Go, utiliser UsedSpaceOnly
                if ($usedPercent -lt 5 -or $usedSpaceGB -lt 1) {
                    $useUsedSpaceOnly = $true
                    Write-Verbose "[Enable-CdBitLockerEncryption] Disque presque vide - utilisation de UsedSpaceOnly (rapide)"
                }
            }
        }
        catch {
            Write-Verbose "[Enable-CdBitLockerEncryption] Impossible de determiner l'espace utilise : $_"
        }

        Write-Verbose "[Enable-CdBitLockerEncryption] Activation de BitLocker sur $volume (UsedSpaceOnly=$useUsedSpaceOnly)..."

        # Activer BitLocker avec mot de passe
        if ($useUsedSpaceOnly) {
            # Disque vide/presque vide : chiffrer uniquement l'espace utilise (rapide)
            Enable-BitLocker -MountPoint $volume `
                            -EncryptionMethod XtsAes256 `
                            -PasswordProtector `
                            -Password $securePassword `
                            -UsedSpaceOnly `
                            -SkipHardwareTest `
                            -ErrorAction Stop | Out-Null
        }
        else {
            # Disque avec donnees : chiffrer tout le disque (securise)
            Enable-BitLocker -MountPoint $volume `
                            -EncryptionMethod XtsAes256 `
                            -PasswordProtector `
                            -Password $securePassword `
                            -SkipHardwareTest `
                            -ErrorAction Stop | Out-Null
        }

        Write-Verbose "[Enable-CdBitLockerEncryption] BitLocker active. Attente du chiffrement complet..."

        # Attendre que le chiffrement soit termine (peut prendre TRES longtemps)
        $timeout = 0
        $maxTimeout = 14400 # 4 heures max (disques de grande capacite)
        $lastPercent = -1

        # Appeler le callback avec 0% au debut
        if ($ProgressCallback) {
            & $ProgressCallback 0
        }

        do {
            Start-Sleep -Seconds 5
            $timeout += 5

            # Utiliser manage-bde pour obtenir la progression (plus fiable)
            $percentComplete = Get-BitLockerProgressFromManageBde -Volume $volume

            if ($percentComplete -ge 0 -and $percentComplete -ne $lastPercent) {
                $lastPercent = $percentComplete
                Write-Verbose "[Enable-CdBitLockerEncryption] Chiffrement en cours : $percentComplete%"

                # Appeler le callback de progression
                if ($ProgressCallback) {
                    & $ProgressCallback $percentComplete
                }
            }

            # Verifier si termine
            if (Test-BitLockerEncryptionComplete -Volume $volume) {
                Write-Verbose "[Enable-CdBitLockerEncryption] Chiffrement termine (100%)!"
                if ($ProgressCallback) {
                    & $ProgressCallback 100
                }
                break
            }

            if ($timeout -ge $maxTimeout) {
                Write-Warning "[Enable-CdBitLockerEncryption] Timeout atteint (4h). Le chiffrement continue en arriere-plan."
                break
            }

        } while ($true)

        # NE PAS desactiver BitLocker - on garde le disque chiffre
        # Le wipe suivant va de toute facon detruire les donnees
        # Mais sans la cle (mot de passe jetable), elles sont irrecuperables

        Write-Verbose "[Enable-CdBitLockerEncryption] Pre-chiffrement termine. Donnees chiffrees et cle perdue."
        return $true
    }
    catch {
        Write-Error "[Enable-CdBitLockerEncryption] Erreur : $_"
        return $false
    }
}
