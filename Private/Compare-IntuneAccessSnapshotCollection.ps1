function Get-IntuneAccessSnapshotRecordKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [object] $Record,
        [Parameter(Mandatory)] [string] $EntityType
    )

    switch ($EntityType) {
        'Administrator' { return [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $Record 'User') 'Id') }
        'Membership' { return "$([string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $Record 'User') 'Id'))|$([string] (Get-IntuneAccessProperty $Record 'GroupId'))" }
        'Permission' { return [string] (Get-IntuneAccessProperty $Record 'RawAction') }
        'DeploymentOutcome' { return "$([string] (Get-IntuneAccessProperty $Record 'WorkloadId'))|$([string] (Get-IntuneAccessProperty $Record 'Id'))" }
        default { return [string] (Get-IntuneAccessProperty $Record 'Id') }
    }
}

function Get-IntuneAccessSnapshotRecordName {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [object] $Record)

    foreach ($propertyName in @('Name', 'DisplayName', 'WorkloadName', 'DeviceName', 'UserPrincipalName', 'RawAction', 'Id')) {
        $value = [string] (Get-IntuneAccessProperty $Record $propertyName '')
        if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
    }
    $user = Get-IntuneAccessProperty $Record 'User'
    if ($null -ne $user) {
        return [string] (Get-IntuneAccessProperty $user 'UserPrincipalName' (Get-IntuneAccessProperty $user 'DisplayName' 'Administrator'))
    }
    'Unnamed record'
}

function Compare-IntuneAccessSnapshotCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Before,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $After,
        [Parameter(Mandatory)] [string] $EntityType
    )

    $beforeByKey = @{}
    $afterByKey = @{}
    foreach ($record in $Before) {
        if ($null -eq $record) { continue }
        $key = Get-IntuneAccessSnapshotRecordKey -Record $record -EntityType $EntityType
        if (-not [string]::IsNullOrWhiteSpace($key)) { $beforeByKey[$key] = $record }
    }
    foreach ($record in $After) {
        if ($null -eq $record) { continue }
        $key = Get-IntuneAccessSnapshotRecordKey -Record $record -EntityType $EntityType
        if (-not [string]::IsNullOrWhiteSpace($key)) { $afterByKey[$key] = $record }
    }

    $changes = [Collections.Generic.List[object]]::new()
    foreach ($key in @($beforeByKey.Keys + $afterByKey.Keys | Sort-Object -Unique)) {
        $hasBefore = $beforeByKey.ContainsKey($key)
        $hasAfter = $afterByKey.ContainsKey($key)
        $beforeRecord = if ($hasBefore) { $beforeByKey[$key] } else { $null }
        $afterRecord = if ($hasAfter) { $afterByKey[$key] } else { $null }
        $changeType = if (-not $hasBefore) { 'Added' } elseif (-not $hasAfter) { 'Removed' } else { 'Modified' }
        $changedProperties = @()

        if ($hasBefore -and $hasAfter) {
            $propertyNames = @($beforeRecord.PSObject.Properties.Name + $afterRecord.PSObject.Properties.Name | Sort-Object -Unique)
            $changedProperties = @($propertyNames | Where-Object {
                $beforeValue = Get-IntuneAccessProperty $beforeRecord $_
                $afterValue = Get-IntuneAccessProperty $afterRecord $_
                ($beforeValue | ConvertTo-Json -Depth 30 -Compress) -cne ($afterValue | ConvertTo-Json -Depth 30 -Compress)
            })
            if ($changedProperties.Count -eq 0) { continue }
        }

        $displayRecord = if ($hasAfter) { $afterRecord } else { $beforeRecord }
        $changes.Add([PSCustomObject] @{
            PSTypeName        = 'IntuneAccess.SnapshotChange'
            EntityType       = $EntityType
            ChangeType       = $changeType
            Id               = $key
            Name             = Get-IntuneAccessSnapshotRecordName -Record $displayRecord
            ChangedProperties = $changedProperties
            Before           = $beforeRecord
            After            = $afterRecord
        })
    }
    $changes.ToArray()
}

function Add-IntuneAccessSnapshotImpact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Change,
        [Parameter(Mandatory)] [object] $SnapshotData
    )

    $record = if ($null -ne $Change.After) { $Change.After } else { $Change.Before }
    $impactState = 'NotEvaluated'
    $impactSummary = 'The potentially affected population cannot be proved from the snapshot.'
    $potentialUsers = $null
    $potentialDevices = $null

    if ($Change.EntityType -eq 'WorkloadAssignment') {
        $targetType = [string] (Get-IntuneAccessProperty $record 'TargetType')
        switch ($targetType) {
            { $_ -in @('All users', 'All licensed users', 'AllUsers') } {
                $impactState = 'BroadTarget'
                $potentialUsers = @(Get-IntuneAccessProperty $SnapshotData 'ManagedUsers' @()).Count
                $impactSummary = "All users target; $potentialUsers managed user records were present in the newer snapshot."
            }
            { $_ -in @('All devices', 'AllDevices') } {
                $impactState = 'BroadTarget'
                $potentialDevices = @(Get-IntuneAccessProperty $SnapshotData 'ManagedDevices' @()).Count
                $impactSummary = "All devices target; $potentialDevices managed device records were present in the newer snapshot."
            }
            default {
                $targetId = [string] (Get-IntuneAccessProperty $record 'TargetId')
                $impactSummary = "Target $targetType $targetId changed; group membership and filter evaluation are not asserted by this snapshot."
            }
        }
    }
    elseif ($Change.EntityType -eq 'RoleAssignment') {
        $impactSummary = 'Administrative access may have changed for members of the connected Admin Groups.'
    }
    elseif ($Change.EntityType -eq 'ScopeTag') {
        $scopeTagId = [string] (Get-IntuneAccessProperty $record 'Id')
        $workloads = @(Get-IntuneAccessProperty $SnapshotData 'WorkloadObjects' @() | Where-Object { $scopeTagId -in @(Get-IntuneAccessProperty $_ 'ScopeTagIds' @()) })
        $impactState = if ($workloads.Count -gt 0) { 'ObservedRelationship' } else { 'NotEvaluated' }
        $impactSummary = "$($workloads.Count) collected workloads reference this Scope Tag."
    }

    $Change | Add-Member -NotePropertyName ImpactState -NotePropertyValue $impactState -Force
    $Change | Add-Member -NotePropertyName ImpactSummary -NotePropertyValue $impactSummary -Force
    $Change | Add-Member -NotePropertyName PotentialUserCount -NotePropertyValue $potentialUsers -Force
    $Change | Add-Member -NotePropertyName PotentialDeviceCount -NotePropertyValue $potentialDevices -Force
    $Change
}
