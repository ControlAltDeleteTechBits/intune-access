function Get-IntuneAccessScopeTags {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $null = Assert-IntuneAccessConnection -RequiredScope 'DeviceManagementRBAC.Read.All'
    $tags = @(Invoke-IntuneAccessGraphRequest -Uri 'deviceManagement/roleScopeTags' -ApiVersion beta)

    return @($tags | ForEach-Object {
        [PSCustomObject] @{
            Id               = [string] (Get-IntuneAccessProperty $_ 'id')
            DisplayName      = [string] (Get-IntuneAccessProperty $_ 'displayName')
            Description      = [string] (Get-IntuneAccessProperty $_ 'description')
            IsBuiltIn        = [bool] (Get-IntuneAccessProperty $_ 'isBuiltIn' $false)
            SourceApiVersion = 'beta'
        }
    })
}
