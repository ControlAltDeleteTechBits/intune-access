function Get-IntuneAccessGroupMembership {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] [guid] $UserId
    )

    $null = Assert-IntuneAccessConnection -RequiredScope @('User.Read.All', 'GroupMember.Read.All')
    $select = '?$select=id,displayName,description,securityEnabled'
    $directGroups = @(Invoke-IntuneAccessGraphRequest -Uri "users/$($UserId.Guid)/memberOf/microsoft.graph.group$select")
    $transitiveGroups = @(Invoke-IntuneAccessGraphRequest -Uri "users/$($UserId.Guid)/transitiveMemberOf/microsoft.graph.group$select")
    $directIds = @($directGroups | ForEach-Object { [string] (Get-IntuneAccessProperty $_ 'id') })

    return @($transitiveGroups | ForEach-Object {
        $id = [string] (Get-IntuneAccessProperty $_ 'id')
        [PSCustomObject] @{
            Id              = $id
            DisplayName     = [string] (Get-IntuneAccessProperty $_ 'displayName')
            Description     = [string] (Get-IntuneAccessProperty $_ 'description')
            SecurityEnabled = Get-IntuneAccessProperty $_ 'securityEnabled'
            MembershipType  = if ($id -in $directIds) { 'Direct' } else { 'Nested' }
        }
    })
}
