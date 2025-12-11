function Get-CdDiskSerial {
    <#
        .SYNOPSIS
        Récupère le numéro de série d'un disque physique (même via adaptateur USB).

        .DESCRIPTION
        Essaye plusieurs méthodes pour récupérer le vrai S/N du disque :
        1. WMI/CIM (Win32_DiskDrive) - fonctionne pour disques internes
        2. Get-PhysicalDisk - fallback
        3. SMART attributes - pour disques via adaptateurs USB (si supporté)
        
        Retourne une chaîne vide si toutes les méthodes échouent.

        .PARAMETER DiskNumber
        Numéro du disque (Get-Disk -Number X).

        .EXAMPLE
        Get-CdDiskSerial -DiskNumber 1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber
    )

    $serialNumber = ""

    try {
        # === MÉTHODE 1 : WMI/CIM (Win32_DiskDrive) ===
        $cimDisk = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue | 
            Where-Object { $_.DeviceID -eq "\\.\PHYSICALDRIVE$DiskNumber" }

        if ($cimDisk -and $cimDisk.SerialNumber) {
            $serial = $cimDisk.SerialNumber.Trim()
            if ($serial -and $serial -ne "") {
                Write-Verbose "[Get-CdDiskSerial] S/N trouvé via WMI : $serial"
                return $serial
            }
        }

        # === MÉTHODE 2 : Get-PhysicalDisk ===
        $physDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | 
            Where-Object { $_.DeviceId -eq $DiskNumber }

        if ($physDisk -and $physDisk.SerialNumber) {
            $serial = $physDisk.SerialNumber.Trim()
            if ($serial -and $serial -ne "") {
                Write-Verbose "[Get-CdDiskSerial] S/N trouvé via Get-PhysicalDisk : $serial"
                return $serial
            }
        }

        # === MÉTHODE 3 : SMART attributes (pour adaptateurs USB) ===
        # Certains adaptateurs USB supportent le pass-through SMART
        Write-Verbose "[Get-CdDiskSerial] Tentative de récupération via SMART attributes..."
        
        try {
            # Utilise Get-StorageReliabilityCounter (Windows 10+)
            $smartData = Get-PhysicalDisk -DeviceNumber $DiskNumber -ErrorAction SilentlyContinue | 
                Get-StorageReliabilityCounter -ErrorAction SilentlyContinue

            if ($smartData) {
                # Certaines infos SMART peuvent contenir le S/N réel
                # (dépend de l'adaptateur et du driver)
                Write-Verbose "[Get-CdDiskSerial] Données SMART disponibles, mais S/N non extrait (nécessite analyse manuelle)"
            }
        }
        catch {
            Write-Verbose "[Get-CdDiskSerial] SMART non disponible : $_"
        }

        # === MÉTHODE 4 : Essai via WMI MSStorageDriver_ATAPISmartData ===
        # (fonctionne parfois pour disques SATA via USB)
        try {
            $smartWmi = Get-WmiObject -Namespace "root\wmi" `
                                      -Class "MSStorageDriver_ATAPISmartData" `
                                      -ErrorAction SilentlyContinue | 
                Where-Object { $_.InstanceName -like "*PHYSICALDRIVE$DiskNumber*" }

            if ($smartWmi -and $smartWmi.VendorSpecific) {
                # Le S/N est parfois dans les octets 20-39 (format ATA IDENTIFY)
                # Mais il faut le décoder manuellement (complexe)
                Write-Verbose "[Get-CdDiskSerial] Données SMART WMI disponibles, mais décodage S/N non implémenté"
            }
        }
        catch {
            Write-Verbose "[Get-CdDiskSerial] SMART WMI non disponible : $_"
        }

        # Si toutes les méthodes échouent, retourner chaîne vide
        Write-Verbose "[Get-CdDiskSerial] Aucun S/N trouvé pour le disque $DiskNumber"
        return ""
    }
    catch {
        Write-Verbose "[Get-CdDiskSerial] Erreur lors de la récupération du S/N du disque $DiskNumber : $_"
        return ""
    }
}

function Get-CdDiskSerialAdvanced {
    <#
        .SYNOPSIS
        Version avancée utilisant smartctl.exe (smartmontools) si disponible.

        .DESCRIPTION
        Si smartctl.exe est présent dans Tools/, utilise-le pour récupérer
        le vrai S/N du disque même via adaptateur USB.

        INSTALLATION smartctl :
        1. Télécharge smartmontools : https://www.smartmontools.org/
        2. Extrais smartctl.exe dans le dossier Tools/ du projet
        3. Cette fonction l'utilisera automatiquement

        .PARAMETER DiskNumber
        Numéro du disque.

        .EXAMPLE
        Get-CdDiskSerialAdvanced -DiskNumber 1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber
    )

    # D'abord essayer la méthode standard
    $serial = Get-CdDiskSerial -DiskNumber $DiskNumber

    if ($serial -and $serial -ne "") {
        return $serial
    }

    # Si échec, essayer avec smartctl (si disponible)
    $smartctlPath = $null
    
    # Chercher dans Tools/
    if ($global:CdRootPath) {
        $smartctlPath = Join-Path $global:CdRootPath "Tools\smartctl.exe"
    }

    if (-not $smartctlPath -or -not (Test-Path $smartctlPath)) {
        # Chercher dans PATH système
        $smartctlPath = (Get-Command smartctl.exe -ErrorAction SilentlyContinue).Source
    }

    if (-not $smartctlPath) {
        Write-Verbose "[Get-CdDiskSerialAdvanced] smartctl.exe non trouvé, S/N indisponible"
        return ""
    }

    try {
        Write-Verbose "[Get-CdDiskSerialAdvanced] Tentative avec smartctl.exe..."
        
        # Exécuter smartctl -i /dev/pdX
        $result = & $smartctlPath -i "/dev/pd$DiskNumber" 2>&1
        
        # Parser la sortie pour trouver "Serial Number:"
        $serialLine = $result | Where-Object { $_ -match "Serial Number:\s*(.+)" }
        
        if ($serialLine -and $Matches[1]) {
            $smartSerial = $Matches[1].Trim()
            Write-Verbose "[Get-CdDiskSerialAdvanced] S/N trouvé via smartctl : $smartSerial"
            return $smartSerial
        }
    }
    catch {
        Write-Verbose "[Get-CdDiskSerialAdvanced] Erreur smartctl : $_"
    }

    return ""
}
