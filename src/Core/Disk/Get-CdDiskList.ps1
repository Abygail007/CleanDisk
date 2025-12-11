function Get-CdDiskList {
    <#
        .SYNOPSIS
        Retourne la liste des disques effacables (hors disque systeme / boot).

        .DESCRIPTION
        Cette fonction ne touche a rien, elle ne fait que lister.
        On exclut tous les disques marques IsSystem ou IsBoot.
        On exclut aussi le disque contenant Windows (C:).
    #>
    [CmdletBinding()]
    param()

    try {
        # Trouver le disque qui contient C: (Windows)
        $systemDiskNumber = $null
        try {
            $cPartition = Get-Partition -DriveLetter 'C' -ErrorAction SilentlyContinue
            if ($cPartition) {
                $systemDiskNumber = $cPartition.DiskNumber
                Write-Verbose "[Get-CdDiskList] Disque systeme (C:) = Disk $systemDiskNumber"
            }
        }
        catch {
            Write-Verbose "[Get-CdDiskList] Impossible de determiner le disque C:"
        }

        $disks = Get-Disk -ErrorAction Stop |
            Where-Object {
                # Exclure si marque systeme ou boot
                -not $_.IsSystem -and
                -not $_.IsBoot -and
                # Exclure le disque contenant C:
                $_.Number -ne $systemDiskNumber
            } |
            Select-Object `
                @{Name='Number';      Expression = { $_.Number }},`
                @{Name='DiskNumber';  Expression = { $_.Number }},`
                @{Name='Model';       Expression = { $_.FriendlyName }},`
                @{Name='SizeGB';      Expression = { [math]::Round($_.Size / 1GB, 1) }},`
                @{Name='Bus';         Expression = { $_.BusType }},`
                @{Name='Status';      Expression = { $_.HealthStatus }}

        return @($disks | Sort-Object Number)
    }
    catch {
        Write-Warning ("[Get-CdDiskList] Erreur lors de la recuperation des disques : {0}" -f $_)
        return @()
    }
}
