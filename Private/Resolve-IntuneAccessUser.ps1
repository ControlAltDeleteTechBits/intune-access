function Resolve-IntuneAccessUser {
    [CmdletBinding(DefaultParameterSetName = 'ByUpn')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByUpn')] [string] $UserPrincipalName,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [guid] $UserId
    )

    $null = Assert-IntuneAccessConnection -RequiredScope 'User.Read.All'
    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $escaped = [uri]::EscapeDataString($UserId.Guid)
        $users = @(Invoke-IntuneAccessGraphRequest -Uri "users/$($escaped)?`$select=id,displayName,userPrincipalName,accountEnabled,userType" -SingleObject)
    }
    else {
        $escapedUpn = [uri]::EscapeDataString($UserPrincipalName)
        $users = @(Invoke-IntuneAccessGraphRequest -Uri "users/$($escapedUpn)?`$select=id,displayName,userPrincipalName,accountEnabled,userType" -SingleObject)
    }

    if ($users.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string] (Get-IntuneAccessProperty $users[0] 'id'))) {
        $identity = if ($PSCmdlet.ParameterSetName -eq 'ById') { $UserId.Guid } else { $UserPrincipalName }
        throw "The target user '$identity' was not found or could not be resolved uniquely."
    }

    return [PSCustomObject] @{
        Id                = [string] (Get-IntuneAccessProperty $users[0] 'id')
        DisplayName       = [string] (Get-IntuneAccessProperty $users[0] 'displayName')
        UserPrincipalName = [string] (Get-IntuneAccessProperty $users[0] 'userPrincipalName')
        AccountEnabled    = Get-IntuneAccessProperty $users[0] 'accountEnabled'
        UserType          = [string] (Get-IntuneAccessProperty $users[0] 'userType')
    }
}
