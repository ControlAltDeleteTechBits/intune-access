function Get-IntuneAccessDeviceMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [guid] $EntraDeviceId
    )

    $null = Assert-IntuneAccessConnection -RequiredScope 'Device.Read.All'
    $filter = [uri]::EscapeDataString("deviceId eq '$($EntraDeviceId.Guid)'")
    $devices = @(Invoke-IntuneAccessGraphRequest -Uri "devices?`$filter=$filter&`$select=id,deviceId,displayName")
    if ($devices.Count -ne 1) {
        return [PSCustomObject] @{
            State       = 'NotEvaluated'
            Device      = $null
            GroupIds    = @()
            Groups      = @()
            Explanation = "Expected one Microsoft Entra device for deviceId '$($EntraDeviceId.Guid)' but found $($devices.Count)."
        }
    }

    $device = $devices[0]
    $objectId = [string] (Get-IntuneAccessProperty $device 'id')
    $groups = @(Invoke-IntuneAccessGraphRequest -Uri "devices/$objectId/transitiveMemberOf/microsoft.graph.group?`$select=id,displayName")
    return [PSCustomObject] @{
        State       = 'Evaluated'
        Device      = $device
        GroupIds    = @($groups | ForEach-Object { [string] (Get-IntuneAccessProperty $_ 'id') })
        Groups      = $groups
        Explanation = 'Microsoft Entra device and transitive group memberships were resolved.'
    }
}
