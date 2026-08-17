function Get-IntuneRoleAssignment {
    <#
    .SYNOPSIS
    Returns a readable view of Intune RBAC role assignments.
    .PARAMETER Name
    Filters assignments by exact display name.
    .PARAMETER Id
    Filters assignments by assignment ID.
    .EXAMPLE
    Get-IntuneRoleAssignment
    .EXAMPLE
    Get-IntuneRoleAssignment -Name 'UK Helpdesk'
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')] [ValidateNotNullOrEmpty()] [string] $Name,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [guid] $Id
    )

    $definitions = @(Get-IntuneAccessRoleDefinitions)
    $assignments = @(Get-IntuneAccessRoleAssignments -RoleDefinition $definitions -ResolveNames)

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $assignments = @($assignments | Where-Object Name -EQ $Name)
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
        $assignments = @($assignments | Where-Object Id -EQ $Id.Guid)
    }

    if ($PSCmdlet.ParameterSetName -ne 'All' -and $assignments.Count -eq 0) {
        $identity = if ($PSCmdlet.ParameterSetName -eq 'ByName') { $Name } else { $Id.Guid }
        throw "No Intune RBAC role assignment matched '$identity'."
    }

    return $assignments
}
