function Enter-CdNoSleep {
    <#
        .SYNOPSIS
        Empêche la mise en veille du système pendant les opérations longues.

        .DESCRIPTION
        Utilise SetThreadExecutionState pour maintenir le système actif.
        À appeler au début d'une opération longue (wipe/format).
    #>
    [CmdletBinding()]
    param()

    try {
        # Définir le type P/Invoke si nécessaire
        if (-not ('Pwr.Es' -as [type])) {
            Add-Type -Namespace Pwr -Name Es -MemberDefinition @"
    [System.Flags]
    public enum EXECUTION_STATE : uint {
        ES_SYSTEM_REQUIRED   = 0x00000001,
        ES_DISPLAY_REQUIRED  = 0x00000002,
        ES_AWAYMODE_REQUIRED = 0x00000040,
        ES_CONTINUOUS        = 0x80000000
    }
    [System.Runtime.InteropServices.DllImport("kernel32.dll")]
    public static extern EXECUTION_STATE SetThreadExecutionState(EXECUTION_STATE esFlags);
"@
        }

        # Activer la protection anti-veille
        [void][Pwr.Es]::SetThreadExecutionState(
            [Pwr.Es+EXECUTION_STATE]::ES_CONTINUOUS -bor 
            [Pwr.Es+EXECUTION_STATE]::ES_SYSTEM_REQUIRED -bor 
            [Pwr.Es+EXECUTION_STATE]::ES_DISPLAY_REQUIRED
        )

        Write-Verbose "[Enter-CdNoSleep] Protection anti-veille activée."
    }
    catch {
        Write-Warning "[Enter-CdNoSleep] Impossible d'activer la protection anti-veille : $_"
    }
}
