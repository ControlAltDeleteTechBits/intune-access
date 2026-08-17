function Get-IntuneScopedPermissionImpact {
    <#
    .SYNOPSIS
    Compares legacy merged and Scoped permissions outcomes for an administrator.
    .DESCRIPTION
    Models both documented Intune permission behaviours from assignment evidence.
    The tenant mode is never detected or inferred. If TenantMode is Unknown, both
    models are returned and EffectiveState remains NotEvaluated.
    .PARAMETER InputObject
    An object returned by Get-IntuneAdminAccess.
    .PARAMETER UserPrincipalName
    Runs the administrator analysis for this user principal name.
    .PARAMETER UserId
    Runs the administrator analysis for this Microsoft Entra object ID.
    .PARAMETER TenantMode
    The mode to use for EffectiveState. The default is Unknown.
    .EXAMPLE
    Get-IntuneAdminAccess -UserPrincipalName 'admin@contoso.com' |
        Get-IntuneScopedPermissionImpact
    .EXAMPLE
    Get-IntuneScopedPermissionImpact -UserPrincipalName 'admin@contoso.com' -TenantMode Scoped
    #>
    [CmdletBinding(DefaultParameterSetName = 'Input')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Input')] [object] $InputObject,
        [Parameter(Mandatory, ParameterSetName = 'ByUpn')] [ValidateNotNullOrEmpty()] [string] $UserPrincipalName,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [guid] $UserId,
        [ValidateSet('Unknown', 'LegacyMerged', 'Scoped')] [string] $TenantMode = 'Unknown'
    )

    process {
        $access = switch ($PSCmdlet.ParameterSetName) {
            'ByUpn' { Get-IntuneAdminAccess -UserPrincipalName $UserPrincipalName }
            'ById' { Get-IntuneAdminAccess -UserId $UserId }
            default { $InputObject }
        }
        if ('IntuneAccess.AdminAccess' -notin $access.PSObject.TypeNames) {
            throw 'InputObject must be a result returned by Get-IntuneAdminAccess.'
        }

        $rows = @(Resolve-IntuneScopedPermissionImpact -RoleAssignment @($access.RoleAssignments) -TenantMode $TenantMode)
        $warnings = [System.Collections.Generic.List[string]]::new()
        if ($TenantMode -eq 'Unknown') {
            $warnings.Add('The active tenant mode was not supplied. EffectiveState remains NotEvaluated; review LegacyState and ScopedState separately.')
        }
        if (@($rows | Where-Object Change -EQ 'NotEvaluated').Count -gt 0) {
            $warnings.Add('One or more comparisons contain incomplete assignment, membership or scope-tag evidence.')
        }

        [PSCustomObject] @{
            PSTypeName       = 'IntuneAccess.ScopedPermissionImpact'
            User             = $access.User
            Tenant           = $access.Tenant
            TenantMode       = $TenantMode
            Rows             = $rows
            Summary          = [PSCustomObject] @{
                PermissionContexts = $rows.Count
                Reductions         = @($rows | Where-Object Change -EQ 'PermissionReduction').Count
                Unchanged          = @($rows | Where-Object Change -EQ 'NoChange').Count
                NotEvaluated       = @($rows | Where-Object Change -EQ 'NotEvaluated').Count
            }
            Warnings         = $warnings.ToArray()
            SourceAccess     = $access
            GeneratedAt      = [DateTimeOffset]::Now
            ToolVersion      = $script:IntuneAccessVersion
        }
    }
}
