function Invoke-CdWithRetry {
    <#
        .SYNOPSIS
        Execute une commande avec retry automatique en cas d'echec.
        
        .PARAMETER ScriptBlock
        Le bloc de script a executer.
        
        .PARAMETER MaxRetries
        Nombre maximum de tentatives (defaut: 3).
        
        .PARAMETER RetryDelaySeconds
        Delai en secondes entre chaque tentative (defaut: 5).
        
        .PARAMETER Description
        Description de l'operation pour les logs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "Operation"
    )

    $attempt = 0
    $lastError = $null
    
    while ($attempt -lt $MaxRetries) {
        $attempt++
        
        try {
            Write-Verbose "[Invoke-CdWithRetry] Tentative $attempt/$MaxRetries : $Description"
            
            # Executer le script
            $result = & $ScriptBlock
            
            Write-Verbose "[Invoke-CdWithRetry] Succes !"
            return $result
        }
        catch {
            $lastError = $_
            Write-Warning "[Invoke-CdWithRetry] Echec tentative $attempt/$MaxRetries : $_"
            
            if ($attempt -lt $MaxRetries) {
                Write-Verbose "[Invoke-CdWithRetry] Attente de $RetryDelaySeconds secondes avant nouvelle tentative..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    # Toutes les tentatives ont echoue
    Write-Error "[Invoke-CdWithRetry] Echec apres $MaxRetries tentatives : $lastError"
    throw $lastError
}
