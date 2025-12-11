function Invoke-CdDiskEject {
    <#
        .SYNOPSIS
        Éjecte proprement un disque USB/externe sans le mettre Offline.

        .DESCRIPTION
        Utilise les API Windows (IOCTL_STORAGE_EJECT_MEDIA + CM_Request_Device_EjectW)
        pour éjecter physiquement un disque de manière sécurisée.

        .PARAMETER DiskNumber
        Numéro du disque à éjecter (Get-Disk -Number X).

        .EXAMPLE
        Invoke-CdDiskEject -DiskNumber 1
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber
    )

    # Définir les types P/Invoke si nécessaire
    if (-not ('NativePnp' -as [type])) {
        try {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class NativePnp {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern IntPtr CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode,
        IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool DeviceIoControl(IntPtr hDevice, uint dwIoControlCode,
        IntPtr lpInBuffer, int nInBufferSize, IntPtr lpOutBuffer, int nOutBufferSize,
        out int lpBytesReturned, IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("CfgMgr32.dll", CharSet=CharSet.Unicode)]
    public static extern int CM_Locate_DevNodeW(out IntPtr pdnDevInst, string pDeviceID, int ulFlags);

    [DllImport("CfgMgr32.dll", CharSet=CharSet.Unicode)]
    public static extern int CM_Request_Device_EjectW(IntPtr dnDevInst, out int pVetoType, StringBuilder pszVetoName, int ulNameLength, int ulFlags);

    [DllImport("CfgMgr32.dll", CharSet=CharSet.Unicode)]
    public static extern int CM_Get_Parent(out IntPtr pdnDevInst, IntPtr dnDevInst, int ulFlags);

    [DllImport("CfgMgr32.dll", CharSet=CharSet.Unicode)]
    public static extern int CM_Get_Device_IDW(IntPtr dnDevInst, StringBuilder Buffer, int BufferLen, int ulFlags);
}
"@
        }
        catch {
            Write-Warning "[Invoke-CdDiskEject] Impossible de charger les types P/Invoke : $_"
            return $false
        }
    }

    # Constantes
    $FILE_SHARE_READ  = 0x00000001
    $FILE_SHARE_WRITE = 0x00000002
    $GENERIC_READ     = 0x80000000
    $GENERIC_WRITE    = 0x40000000
    $OPEN_EXISTING    = 3
    $IOCTL_STORAGE_EJECT_MEDIA = 0x2D4808
    $CR_SUCCESS = 0

    try {
        $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop

        # Démonter tous les volumes du disque
        $volumes = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue
        foreach ($vol in $volumes) {
            if ($vol.DriveLetter) {
                try {
                    $driveLetter = $vol.DriveLetter
                    $null = (New-Object -ComObject Shell.Application).NameSpace(17).ParseName("${driveLetter}:").InvokeVerb('Eject')
                    Start-Sleep -Milliseconds 500
                }
                catch {
                    Write-Verbose "[Invoke-CdDiskEject] Impossible de démonter le volume $($vol.DriveLetter) : $_"
                }
            }
        }

        # Ouvrir le disque physique
        $diskPath = "\\.\PhysicalDrive$DiskNumber"
        $handle = [NativePnp]::CreateFile(
            $diskPath,
            ($GENERIC_READ -bor $GENERIC_WRITE),
            ($FILE_SHARE_READ -bor $FILE_SHARE_WRITE),
            [IntPtr]::Zero,
            $OPEN_EXISTING,
            0,
            [IntPtr]::Zero
        )

        if ($handle -eq [IntPtr]::Zero -or $handle.ToInt64() -eq -1) {
            Write-Warning "[Invoke-CdDiskEject] Impossible d'ouvrir $diskPath"
            return $false
        }

        # Envoyer IOCTL_STORAGE_EJECT_MEDIA
        $bytesReturned = 0
        $ioResult = [NativePnp]::DeviceIoControl(
            $handle,
            $IOCTL_STORAGE_EJECT_MEDIA,
            [IntPtr]::Zero, 0,
            [IntPtr]::Zero, 0,
            [ref]$bytesReturned,
            [IntPtr]::Zero
        )

        [NativePnp]::CloseHandle($handle) | Out-Null

        if (-not $ioResult) {
            Write-Verbose "[Invoke-CdDiskEject] IOCTL_STORAGE_EJECT_MEDIA a échoué, tentative via CM_Request_Device_EjectW..."
        }

        # Récupérer le Device Instance Path du disque
        $devInstId = (Get-Disk -Number $DiskNumber -ErrorAction Stop | Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop).PNPDeviceID
        if (-not $devInstId) {
            Write-Warning "[Invoke-CdDiskEject] Impossible de récupérer le PNPDeviceID du disque $DiskNumber"
            return $false
        }

        # Localiser le DevNode
        $devNode = [IntPtr]::Zero
        $ret = [NativePnp]::CM_Locate_DevNodeW([ref]$devNode, $devInstId, 0)
        if ($ret -ne $CR_SUCCESS -or $devNode -eq [IntPtr]::Zero) {
            Write-Warning "[Invoke-CdDiskEject] Impossible de localiser le DevNode pour $devInstId"
            return $false
        }

        # Remonter au parent (contrôleur USB)
        $parentNode = [IntPtr]::Zero
        $ret = [NativePnp]::CM_Get_Parent([ref]$parentNode, $devNode, 0)
        if ($ret -ne $CR_SUCCESS -or $parentNode -eq [IntPtr]::Zero) {
            Write-Warning "[Invoke-CdDiskEject] Impossible de récupérer le parent du DevNode"
            return $false
        }

        # Demander l'éjection du parent
        $vetoType = 0
        $vetoName = New-Object System.Text.StringBuilder 260
        $ret = [NativePnp]::CM_Request_Device_EjectW($parentNode, [ref]$vetoType, $vetoName, 260, 0)

        if ($ret -eq $CR_SUCCESS) {
            Write-Verbose "[Invoke-CdDiskEject] Disque $DiskNumber éjecté avec succès."
            return $true
        }
        else {
            $vetoMsg = if ($vetoName.Length -gt 0) { $vetoName.ToString() } else { "Raison inconnue" }
            Write-Warning "[Invoke-CdDiskEject] Éjection refusée : $vetoMsg (code $vetoType)"
            return $false
        }
    }
    catch {
        Write-Warning "[Invoke-CdDiskEject] Erreur lors de l'éjection du disque $DiskNumber : $_"
        return $false
    }
}
