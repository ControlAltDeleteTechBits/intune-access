function Get-IntuneAccessTenant {
    [CmdletBinding()]
    param()

    $organisation = @(Invoke-IntuneAccessGraphRequest -Uri 'organization?$select=id,displayName,verifiedDomains')[0]
    $verifiedDomains = @(Get-IntuneAccessProperty $organisation 'verifiedDomains' @())
    $defaultDomain = $verifiedDomains | Where-Object { (Get-IntuneAccessProperty $_ 'isDefault' $false) -eq $true } | Select-Object -First 1

    return [PSCustomObject] @{
        Id            = [string] (Get-IntuneAccessProperty $organisation 'id')
        DisplayName   = [string] (Get-IntuneAccessProperty $organisation 'displayName')
        DefaultDomain = [string] (Get-IntuneAccessProperty $defaultDomain 'name')
    }
}
