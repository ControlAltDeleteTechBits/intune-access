function Compare-IntuneAdminAccess {
    <#
    .SYNOPSIS
    Compares two Intune administrator access results.
    .DESCRIPTION
    Compares assignments, permissions, Admin Groups, Scope Groups and Scope Tags.
    A shared permission is marked DifferentEvidence when its granting assignments differ.
    .PARAMETER ReferenceObject
    The reference result returned by Get-IntuneAdminAccess.
    .PARAMETER DifferenceObject
    The result to compare with the reference result.
    .PARAMETER ReferenceUser
    The reference administrator's user principal name.
    .PARAMETER DifferenceUser
    The comparison administrator's user principal name.
    .PARAMETER IncludeUnchanged
    Includes records that are identical in both results.
    .EXAMPLE
    Compare-IntuneAdminAccess -ReferenceUser 'senior@contoso.com' -DifferenceUser 'helpdesk@contoso.com'
    .EXAMPLE
    Compare-IntuneAdminAccess -ReferenceObject $senior -DifferenceObject $helpdesk
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByUser')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByObject')] [object] $ReferenceObject,
        [Parameter(Mandatory, ParameterSetName = 'ByObject')] [object] $DifferenceObject,
        [Parameter(Mandatory, ParameterSetName = 'ByUser')] [ValidateNotNullOrEmpty()] [string] $ReferenceUser,
        [Parameter(Mandatory, ParameterSetName = 'ByUser')] [ValidateNotNullOrEmpty()] [string] $DifferenceUser,
        [switch] $IncludeUnchanged
    )

    $reference = if ($PSCmdlet.ParameterSetName -eq 'ByUser') {
        Get-IntuneAdminAccess -UserPrincipalName $ReferenceUser
    }
    else { $ReferenceObject }
    $difference = if ($PSCmdlet.ParameterSetName -eq 'ByUser') {
        Get-IntuneAdminAccess -UserPrincipalName $DifferenceUser
    }
    else { $DifferenceObject }

    foreach ($accessResult in @($reference, $difference)) {
        if ('IntuneAccess.AdminAccess' -notin $accessResult.PSObject.TypeNames) {
            throw 'ReferenceObject and DifferenceObject must be results returned by Get-IntuneAdminAccess.'
        }
    }

    $changes = [System.Collections.Generic.List[object]]::new()
    $collections = @(
        [PSCustomObject] @{ Category = 'RoleAssignment'; Reference = @($reference.RoleAssignments); Difference = @($difference.RoleAssignments); Key = 'Id'; Display = 'Name' }
        [PSCustomObject] @{ Category = 'AdminGroup'; Reference = @($reference.AdminGroups); Difference = @($difference.AdminGroups); Key = 'Id'; Display = 'DisplayName' }
        [PSCustomObject] @{ Category = 'ScopeGroup'; Reference = @($reference.ScopeGroups); Difference = @($difference.ScopeGroups); Key = 'Id'; Display = 'DisplayName' }
        [PSCustomObject] @{ Category = 'ScopeTag'; Reference = @($reference.ScopeTags); Difference = @($difference.ScopeTags); Key = 'Id'; Display = 'DisplayName' }
    )

    foreach ($collection in $collections) {
        $referenceMap = @{}
        $differenceMap = @{}
        foreach ($item in $collection.Reference) {
            $key = [string] (Get-IntuneAccessProperty $item $collection.Key)
            if (-not [string]::IsNullOrWhiteSpace($key)) { $referenceMap[$key] = $item }
        }
        foreach ($item in $collection.Difference) {
            $key = [string] (Get-IntuneAccessProperty $item $collection.Key)
            if (-not [string]::IsNullOrWhiteSpace($key)) { $differenceMap[$key] = $item }
        }
        foreach ($key in @($referenceMap.Keys + $differenceMap.Keys | Select-Object -Unique | Sort-Object)) {
            $status = if (-not $differenceMap.ContainsKey($key)) { 'ReferenceOnly' }
                elseif (-not $referenceMap.ContainsKey($key)) { 'DifferenceOnly' }
                else { 'Unchanged' }
            if ($status -eq 'Unchanged' -and -not $IncludeUnchanged) { continue }
            $item = if ($referenceMap.ContainsKey($key)) { $referenceMap[$key] } else { $differenceMap[$key] }
            $changes.Add([PSCustomObject] @{
                Category        = $collection.Category
                Key             = $key
                DisplayName     = [string] (Get-IntuneAccessProperty $item $collection.Display $key)
                Status          = $status
                ReferenceValue  = if ($referenceMap.ContainsKey($key)) { $referenceMap[$key] } else { $null }
                DifferenceValue = if ($differenceMap.ContainsKey($key)) { $differenceMap[$key] } else { $null }
            })
        }
    }

    $referencePermissions = @{}
    $differencePermissions = @{}
    foreach ($permission in @($reference.EffectivePermissions)) { $referencePermissions[[string] $permission.RawAction] = $permission }
    foreach ($permission in @($difference.EffectivePermissions)) { $differencePermissions[[string] $permission.RawAction] = $permission }
    foreach ($key in @($referencePermissions.Keys + $differencePermissions.Keys | Select-Object -Unique | Sort-Object)) {
        if (-not $differencePermissions.ContainsKey($key)) {
            $status = 'ReferenceOnly'
        }
        elseif (-not $referencePermissions.ContainsKey($key)) {
            $status = 'DifferenceOnly'
        }
        else {
            $referenceSources = @($referencePermissions[$key].GrantedBy | ForEach-Object RoleAssignmentId | Sort-Object -Unique)
            $differenceSources = @($differencePermissions[$key].GrantedBy | ForEach-Object RoleAssignmentId | Sort-Object -Unique)
            $status = if (($referenceSources -join '|') -eq ($differenceSources -join '|')) { 'Unchanged' } else { 'DifferentEvidence' }
        }
        if ($status -eq 'Unchanged' -and -not $IncludeUnchanged) { continue }
        $permission = if ($referencePermissions.ContainsKey($key)) { $referencePermissions[$key] } else { $differencePermissions[$key] }
        $changes.Add([PSCustomObject] @{
            Category        = 'Permission'
            Key             = $key
            DisplayName     = "$($permission.Resource) / $($permission.Operation)"
            Status          = $status
            ReferenceValue  = if ($referencePermissions.ContainsKey($key)) { $referencePermissions[$key] } else { $null }
            DifferenceValue = if ($differencePermissions.ContainsKey($key)) { $differencePermissions[$key] } else { $null }
        })
    }

    $changeArray = @($changes | Sort-Object Category, DisplayName)
    [PSCustomObject] @{
        PSTypeName       = 'IntuneAccess.AdminAccessComparison'
        ReferenceUser    = $reference.User
        DifferenceUser   = $difference.User
        Changes          = $changeArray
        Summary          = [PSCustomObject] @{
            TotalChanges      = @($changeArray | Where-Object Status -NE 'Unchanged').Count
            ReferenceOnly     = @($changeArray | Where-Object Status -EQ 'ReferenceOnly').Count
            DifferenceOnly    = @($changeArray | Where-Object Status -EQ 'DifferenceOnly').Count
            DifferentEvidence = @($changeArray | Where-Object Status -EQ 'DifferentEvidence').Count
            Unchanged         = @($changeArray | Where-Object Status -EQ 'Unchanged').Count
        }
        ReferenceAccess  = $reference
        DifferenceAccess = $difference
        GeneratedAt      = [DateTimeOffset]::Now
        ToolVersion      = $script:IntuneAccessVersion
    }
}
