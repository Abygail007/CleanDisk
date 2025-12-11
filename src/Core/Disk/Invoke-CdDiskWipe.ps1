function Invoke-CdDiskWipe {
    <#
        .SYNOPSIS
        Efface (wipe) un disque en mode Fast ou Secure.

        .PARAMETER DiskNumber
        Numero du disque a effacer.

        .PARAMETER WipeMode
        Mode d'effacement : "Fast" (par defaut) ou "Secure" (reecriture complete).
        
        .PARAMETER PassCount
        Nombre de passes pour le mode Secure (defaut: 3).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$DiskNumber,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Fast', 'Secure')]
        [string]$WipeMode = 'Fast',
        
        [Parameter(Mandatory = $false)]
        [int]$PassCount = 3
    )

    Write-Verbose "[Invoke-CdDiskWipe] Mode=$WipeMode pour disque #$DiskNumber"

    try {
        # Verification disque systeme
        $disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
        if ($disk.IsSystem -or $disk.IsBoot) {
            throw "Le disque $DiskNumber est un disque systeme ou de demarrage. Operation annulee."
        }

        # S'assurer qu'il est en ligne et en ecriture
        if ($disk.IsOffline) {
            Set-Disk -Number $DiskNumber -IsOffline:$false -ErrorAction Stop
        }
        if ($disk.IsReadOnly) {
            Set-Disk -Number $DiskNumber -IsReadOnly:$false -ErrorAction Stop
        }

        # IMPORTANT : retirer toutes les lettres de lecteur avant l'effacement
        try {
            $partitions = Get-Partition -DiskNumber $DiskNumber -ErrorAction SilentlyContinue
            if ($partitions) {
                foreach ($part in $partitions) {
                    if ($part.DriveLetter) {
                        $accessPath = ("{0}:" -f $part.DriveLetter)
                        Write-Verbose "[Invoke-CdDiskWipe] Suppression de l'acces $accessPath avant Clear-Disk..."
                        Remove-PartitionAccessPath -DiskNumber $DiskNumber `
                                                   -PartitionNumber $part.PartitionNumber `
                                                   -AccessPath $accessPath `
                                                   -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        catch {
            Write-Verbose "[Invoke-CdDiskWipe] Impossible de retirer les lettres de lecteur : $_"
        }

        if ($WipeMode -eq 'Fast') {
            # Mode Fast : effacement rapide
            Write-Verbose "[Invoke-CdDiskWipe] Mode Fast : Clear-Disk uniquement"
            Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
            Write-Verbose "[Invoke-CdDiskWipe] Clear-Disk termine (Fast)."
            return $true
        }
        else {
            # Mode Secure : reecriture complete avec cipher.exe
            Write-Verbose "[Invoke-CdDiskWipe] Mode Secure : reecriture complete en $PassCount passes"
            
            # Etape 1 : Clear-Disk pour reinitialiser
            Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
            
            # Etape 2 : Creer une partition temporaire pour cipher.exe
            Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction SilentlyContinue
            
            $partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -ErrorAction Stop
            $volume = $partition | Get-Volume -ErrorAction SilentlyContinue
            
            # Assigner une lettre de lecteur
            if (-not $partition.DriveLetter) {
                $partition | Add-PartitionAccessPath -AssignDriveLetter -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds 2
                $partition = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $partition.PartitionNumber
            }
            
            $driveLetter = $partition.DriveLetter
            
            if (-not $driveLetter) {
                throw "Impossible d'assigner une lettre de lecteur"
            }
            
            # Formater rapidement
            Write-Verbose "[Invoke-CdDiskWipe] Formatage partition temporaire ($($driveLetter):)"
            Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel "TEMP_WIPE" -Confirm:$false -Force -ErrorAction Stop | Out-Null
            
            # Etape 3 : Reecriture avec cipher.exe (methode DoD 5220.22-M)
            # cipher.exe /w ecrase l'espace libre avec 3 passes (0x00, 0xFF, random)
            Write-Verbose "[Invoke-CdDiskWipe] Lancement cipher.exe pour $PassCount passes..."
            
            $cipherExe = Join-Path $env:SystemRoot 'System32\cipher.exe'
            $cipherPath = "$($driveLetter):\"
            
            for ($pass = 1; $pass -le $PassCount; $pass++) {
                Write-Verbose "[Invoke-CdDiskWipe] Passe $pass/$PassCount : reecriture complete..."
                
                $process = Start-Process -FilePath $cipherExe `
                                        -ArgumentList "/w:$cipherPath" `
                                        -NoNewWindow `
                                        -Wait `
                                        -PassThru `
                                        -ErrorAction Stop
                
                if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 1) {
                    Write-Warning "[Invoke-CdDiskWipe] cipher.exe passe $pass : code retour $($process.ExitCode)"
                }
            }
            
            # Etape 4 : Nettoyage final - supprimer la partition temporaire
            Write-Verbose "[Invoke-CdDiskWipe] Nettoyage final..."
            Remove-Partition -DriveLetter $driveLetter -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
            
            Write-Verbose "[Invoke-CdDiskWipe] Effacement Secure termine ($PassCount passes)."
            return $true
        }
    }
    catch {
        Write-Error "[Invoke-CdDiskWipe] Erreur : $_"
        return $false
    }
}
