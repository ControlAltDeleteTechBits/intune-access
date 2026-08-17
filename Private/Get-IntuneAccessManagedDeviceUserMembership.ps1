function Get-IntuneAccessManagedDeviceUserMembership {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()] [AllowEmptyString()] [string] $UserId
    )

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        return [PSCustomObject] @{
            State       = 'NotApplicable'
            UserId      = $null
            GroupIds    = @()
            Groups      = @()
            Explanation = 'The managed device has no associated Microsoft Entra user.'
        }
    }

    $parsedUserId = [guid]::Empty
    if (-not [guid]::TryParse($UserId, [ref] $parsedUserId)) {
        return [PSCustomObject] @{
            State       = 'NotEvaluated'
            UserId      = $UserId
            GroupIds    = @()
            Groups      = @()
            Explanation = 'The managed device returned an associated user ID that is not a GUID.'
        }
    }

    try {
        $memberships = @(Get-IntuneAccessGroupMembership -UserId $parsedUserId)
        return [PSCustomObject] @{
            State       = 'Evaluated'
            UserId      = $parsedUserId.Guid
            GroupIds    = @($memberships | ForEach-Object { [string] $_.Id })
            Groups      = $memberships
            Explanation = 'The associated user and transitive Microsoft Entra group memberships were resolved.'
        }
    }
    catch {
        return [PSCustomObject] @{
            State       = 'NotEvaluated'
            UserId      = $parsedUserId.Guid
            GroupIds    = @()
            Groups      = @()
            Explanation = "The associated user's group memberships could not be resolved. $($_.Exception.Message)"
        }
    }
}
