function Exit-CdNoSleep {
    <#
        .SYNOPSIS
        Réactive la mise en veille normale du système.

        .DESCRIPTION
        À appeler à la fin d'une opération longue pour restaurer le comportement normal.
    #>
    [CmdletBinding()]
    param()

    try {
        if ('Pwr.Es' -as [type]) {
            [void][Pwr.Es]::SetThreadExecutionState([Pwr.Es+EXECUTION_STATE]::ES_CONTINUOUS)
            Write-Verbose "[Exit-CdNoSleep] Protection anti-veille désactivée."
        }
    }
    catch {
        Write-Warning "[Exit-CdNoSleep] Impossible de désactiver la protection anti-veille : $_"
    }
}
