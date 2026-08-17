function Get-IntuneAccessAllowedActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $RoleDefinition
    )

    $actions = [System.Collections.Generic.List[string]]::new()
    foreach ($permission in @(Get-IntuneAccessProperty $RoleDefinition 'RolePermissions' @())) {
        foreach ($resourceAction in @(Get-IntuneAccessProperty $permission 'resourceActions' @())) {
            foreach ($action in @(Get-IntuneAccessProperty $resourceAction 'allowedResourceActions' @())) {
                if (-not [string]::IsNullOrWhiteSpace([string] $action) -and $action -notin $actions) {
                    $actions.Add([string] $action)
                }
            }
        }
    }
    return $actions.ToArray()
}
