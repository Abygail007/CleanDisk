function Write-CdErrorLog {
    <#
        .SYNOPSIS
        Enregistre une erreur dans le fichier de log d'erreurs.
        
        .PARAMETER ErrorMessage
        Message d'erreur a enregistrer.
        
        .PARAMETER ErrorObject
        Objet d'erreur PowerShell complet.
        
        .PARAMETER Context
        Contexte de l'erreur (ex: "Effacement disque #1").
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage,
        
        [Parameter(Mandatory = $false)]
        $ErrorObject,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = "General"
    )

    try {
        $root = Get-CdRootDirectory
        $logsDir = Join-Path $root 'Logs'
        
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }
        
        $errorLogPath = Join-Path $logsDir 'CleanDisk_Errors.log'
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        $logEntry = "[$timestamp] [$Context]`n"
        
        if ($ErrorMessage) {
            $logEntry += "Message: $ErrorMessage`n"
        }
        
        if ($ErrorObject) {
            $logEntry += "Exception: $($ErrorObject.Exception.Message)`n"
            $logEntry += "Type: $($ErrorObject.Exception.GetType().FullName)`n"
            
            if ($ErrorObject.ScriptStackTrace) {
                $logEntry += "StackTrace: $($ErrorObject.ScriptStackTrace)`n"
            }
        }
        
        $logEntry += "----------------------------------------`n`n"
        
        # Ecrire dans le fichier (append)
        Add-Content -Path $errorLogPath -Value $logEntry -Encoding UTF8
        
        Write-Verbose "[Write-CdErrorLog] Erreur enregistree dans $errorLogPath"
    }
    catch {
        Write-Warning "[Write-CdErrorLog] Impossible d'ecrire le log d'erreur : $_"
    }
}
