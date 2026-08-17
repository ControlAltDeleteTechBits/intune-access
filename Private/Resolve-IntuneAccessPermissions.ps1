function Resolve-IntuneAccessPermissions {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowEmptyCollection()] [object[]] $RoleAssignment
    )

    $grants = [System.Collections.Generic.List[object]]::new()
    foreach ($assignment in @($RoleAssignment)) {
        foreach ($action in @(Get-IntuneAccessProperty $assignment 'Permissions' @())) {
            $metadata = ConvertFrom-IntuneAccessActionName -Action $action
            $grants.Add([PSCustomObject] @{
                RawAction            = $action
                Resource             = $metadata.Resource
                Operation            = $metadata.Operation
                Applicability        = [string] (Get-IntuneAccessProperty $assignment 'Applicability' 'NotEvaluated')
                RoleAssignmentId     = [string] (Get-IntuneAccessProperty $assignment 'Id')
                RoleAssignmentName   = [string] (Get-IntuneAccessProperty $assignment 'Name')
                RoleDefinitionId     = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $assignment 'RoleDefinition') 'Id')
                RoleDefinitionName   = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $assignment 'RoleDefinition') 'DisplayName')
                AdminGroupEvidence   = @(Get-IntuneAccessProperty $assignment 'AdminGroupEvidence' @())
                ScopeType            = [string] (Get-IntuneAccessProperty $assignment 'ScopeType')
                ScopeGroupIds        = @(Get-IntuneAccessProperty (Get-IntuneAccessProperty $assignment 'RawIds') 'ScopeGroupIds' @())
                ScopeTagIds          = @(Get-IntuneAccessProperty (Get-IntuneAccessProperty $assignment 'RawIds') 'ScopeTagIds' @())
            })
        }
    }

    return @($grants | Group-Object -Property RawAction | ForEach-Object {
        $sources = @($_.Group)
        $allowed = @($sources | Where-Object Applicability -EQ 'Confirmed').Count -gt 0
        [PSCustomObject] @{
            PSTypeName    = 'IntuneAccess.EffectivePermission'
            RawAction     = $_.Name
            Resource      = $sources[0].Resource
            Operation     = $sources[0].Operation
            State         = if ($allowed) { 'Allowed' } else { 'NotEvaluated' }
            SourceCount   = $sources.Count
            IsDuplicate   = $sources.Count -gt 1
            GrantedBy     = $sources
        }
    } | Sort-Object -Property Resource, Operation)
}
