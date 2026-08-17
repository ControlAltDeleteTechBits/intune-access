function Get-IntuneAccessRoleDefinitions {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $null = Assert-IntuneAccessConnection -RequiredScope 'DeviceManagementRBAC.Read.All'
    $definitions = @(Invoke-IntuneAccessGraphRequest -Uri 'deviceManagement/roleDefinitions')

    return @($definitions | ForEach-Object {
        $missingValue = [object]::new()
        $permissionValue = Get-IntuneAccessProperty $_ 'rolePermissions' $missingValue
        $isBuiltInValue = Get-IntuneAccessProperty $_ 'isBuiltIn' $missingValue
        [PSCustomObject] @{
            PSTypeName      = 'IntuneAccess.RoleDefinition'
            Id              = [string] (Get-IntuneAccessProperty $_ 'id')
            DisplayName     = [string] (Get-IntuneAccessProperty $_ 'displayName')
            Description     = [string] (Get-IntuneAccessProperty $_ 'description')
            IsBuiltIn       = if ([object]::ReferenceEquals($isBuiltInValue, $missingValue)) { $null } else { [bool] $isBuiltInValue }
            RolePermissions = if ([object]::ReferenceEquals($permissionValue, $missingValue)) { @() } else { @($permissionValue) }
            PermissionDataState = if ([object]::ReferenceEquals($permissionValue, $missingValue)) { 'Missing' } else { 'Available' }
            SourceApiVersion = 'v1.0'
        }
    })
}
