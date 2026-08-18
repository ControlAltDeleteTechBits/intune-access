function Get-IntuneAccessAdminGroupUsers {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Group
    )

    if (@($Group).Count -eq 0) {
        return @()
    }

    $null = Assert-IntuneAccessConnection -RequiredScope @('User.Read.All', 'GroupMember.Read.All')
    $memberships = [System.Collections.Generic.List[object]]::new()

    foreach ($adminGroup in @($Group)) {
        $groupId = [string] (Get-IntuneAccessProperty $adminGroup 'Id')
        if ([string]::IsNullOrWhiteSpace($groupId) -or
            (Get-IntuneAccessProperty $adminGroup 'ResolutionState' 'Resolved') -eq 'Unresolved') {
            continue
        }

        $escapedGroupId = [uri]::EscapeDataString($groupId)
        $select = '?$select=id,displayName,userPrincipalName,accountEnabled,userType'
        $directUsers = @(Invoke-IntuneAccessGraphRequest -Uri "groups/$escapedGroupId/members/microsoft.graph.user$select")
        $transitiveUsers = @(Invoke-IntuneAccessGraphRequest -Uri "groups/$escapedGroupId/transitiveMembers/microsoft.graph.user$select")
        $directIds = @($directUsers | ForEach-Object { [string] (Get-IntuneAccessProperty $_ 'id') })

        foreach ($user in $transitiveUsers) {
            $userId = [string] (Get-IntuneAccessProperty $user 'id')
            if ([string]::IsNullOrWhiteSpace($userId)) {
                continue
            }

            $memberships.Add([PSCustomObject] @{
                PSTypeName       = 'IntuneAccess.AdminGroupMembership'
                GroupId          = $groupId
                GroupName        = [string] (Get-IntuneAccessProperty $adminGroup 'DisplayName' '[Unnamed Admin Group]')
                MembershipType   = if ($userId -in $directIds) { 'Direct' } else { 'Nested' }
                User             = [PSCustomObject] @{
                    Id                = $userId
                    DisplayName       = [string] (Get-IntuneAccessProperty $user 'displayName')
                    UserPrincipalName = [string] (Get-IntuneAccessProperty $user 'userPrincipalName')
                    AccountEnabled    = Get-IntuneAccessProperty $user 'accountEnabled'
                    UserType          = [string] (Get-IntuneAccessProperty $user 'userType')
                }
            })
        }
    }

    return @($memberships | Sort-Object -Property @{ Expression = { $_.User.UserPrincipalName } }, GroupName)
}
