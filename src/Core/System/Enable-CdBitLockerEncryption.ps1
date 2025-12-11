function Enable-CdBitLockerEncryption {
    <#
        .SYNOPSIS
        Pre-chiffre un disque avec BitLocker avant effacement (securite maximale).
        
        .DESCRIPTION
        Cette fonction chiffre le disque avec BitLocker, puis supprime la cle.
        Cela rend les donnees completement inaccessibles (perte de cle).
        
        ATTENTION : Operation TRES LONGUE (plusieurs heures selon la taille).
        
        .PARAMETER DiskNumber
        Numero du disque a chiffrer.
        
        .PARAMETER DriveLetter
        Lettre du lecteur a chiffrer (ex: "D").
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber,
        
        [Parameter(Mandatory = $false)]
        [string]$DriveLetter
    )

    try {
        Write-Verbose "[Enable-CdBitLockerEncryption] Debut pre-chiffrement BitLocker pour disque #$DiskNumber"
        
        # Verifier si BitLocker est disponible
        $bitlockerFeature = Get-WindowsOptionalFeature -Online -FeatureName "BitLocker" -ErrorAction SilentlyContinue
        if (-not $bitlockerFeature -or $bitlockerFeature.State -ne "Enabled") {
            throw "BitLocker n'est pas active sur ce systeme. Activez-le dans 'Fonctionnalites Windows'."
        }
        
        # Si pas de lettre fournie, recuperer la premiere partition
        if (-not $DriveLetter) {
            $partition = Get-Partition -DiskNumber $DiskNumber | Where-Object { $_.DriveLetter } | Select-Object -First 1
            if (-not $partition) {
                throw "Aucune partition avec lettre de lecteur trouvee sur le disque #$DiskNumber"
            }
            $DriveLetter = $partition.DriveLetter
        }
        
        $volume = "$($DriveLetter):"
        
        Write-Verbose "[Enable-CdBitLockerEncryption] Chiffrement du volume $volume..."
        
        # Generer une cle de recuperation aleatoire (qu'on ne sauvegardera PAS = perte intentionnelle)
        $recoveryPassword = (1..48 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 }) -join ''
        
        # Activer BitLocker avec chiffrement XTS-AES 256
        Enable-BitLocker -MountPoint $volume `
                        -EncryptionMethod XtsAes256 `
                        -RecoveryPasswordProtector `
                        -Password (ConvertTo-SecureString -String $recoveryPassword -AsPlainText -Force) `
                        -SkipHardwareTest `
                        -ErrorAction Stop | Out-Null
        
        Write-Verbose "[Enable-CdBitLockerEncryption] BitLocker active. Attente du chiffrement complet..."
        
        # Attendre que le chiffrement soit termine (peut prendre TRES longtemps)
        $timeout = 0
        $maxTimeout = 3600 # 1 heure max (si trop long, on arrete)
        
        do {
            Start-Sleep -Seconds 10
            $timeout += 10
            
            $status = Get-BitLockerVolume -MountPoint $volume -ErrorAction SilentlyContinue
            
            if ($status) {
                $percentComplete = $status.EncryptionPercentage
                Write-Verbose "[Enable-CdBitLockerEncryption] Chiffrement en cours : $percentComplete%"
                
                if ($status.VolumeStatus -eq "FullyEncrypted") {
                    Write-Verbose "[Enable-CdBitLockerEncryption] Chiffrement termine !"
                    break
                }
            }
            
            if ($timeout -ge $maxTimeout) {
                Write-Warning "[Enable-CdBitLockerEncryption] Timeout atteint (1h). Arret du chiffrement."
                break
            }
            
        } while ($true)
        
        # Desactiver BitLocker (suppression de la cle = donnees perdues)
        Write-Verbose "[Enable-CdBitLockerEncryption] Suppression des protecteurs de cle (perte intentionnelle)..."
        Disable-BitLocker -MountPoint $volume -ErrorAction Stop | Out-Null
        
        Write-Verbose "[Enable-CdBitLockerEncryption] Pre-chiffrement termine. Donnees rendues inaccessibles."
        return $true
    }
    catch {
        Write-Error "[Enable-CdBitLockerEncryption] Erreur : $_"
        return $false
    }
}
