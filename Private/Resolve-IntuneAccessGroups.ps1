function Resolve-IntuneAccessGroups {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowEmptyCollection()] [string[]] $GroupId
    )

    if (@($GroupId).Count -eq 0) {
        return @()
    }

    $null = Assert-IntuneAccessConnection -RequiredScope 'GroupMember.Read.All'
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($id in @($GroupId | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        try {
            $escaped = [uri]::EscapeDataString($id)
            $group = @(Invoke-IntuneAccessGraphRequest -Uri "groups/$($escaped)?`$select=id,displayName,description,securityEnabled" -SingleObject)[0]
            $result.Add([PSCustomObject] @{
                Id              = [string] (Get-IntuneAccessProperty $group 'id')
                DisplayName     = [string] (Get-IntuneAccessProperty $group 'displayName')
                Description     = [string] (Get-IntuneAccessProperty $group 'description')
                SecurityEnabled = Get-IntuneAccessProperty $group 'securityEnabled'
                ResolutionState = 'Resolved'
            })
        }
        catch {
            Write-Warning "Group '$id' could not be resolved. The raw ID is retained. $($_.Exception.Message)"
            $result.Add([PSCustomObject] @{
                Id              = $id
                DisplayName     = '[Unresolved group]'
                Description     = $null
                SecurityEnabled = $null
                ResolutionState = 'Unresolved'
            })
        }
    }

    return $result.ToArray()
}
