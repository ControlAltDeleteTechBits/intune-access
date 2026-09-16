function Compare-IntuneAccessSnapshot {
    <#
    .SYNOPSIS
    Compares two local IntuneAccess tenant snapshots.
    .PARAMETER ReferencePath
    Earlier snapshot JSON file.
    .PARAMETER DifferencePath
    Later snapshot JSON file.
    .PARAMETER AuditEvent
    Optional Intune audit events used to correlate changes by exact resource ID.
    .EXAMPLE
    Compare-IntuneAccessSnapshot -ReferencePath '.\baseline.snapshot.json' -DifferencePath '.\current.snapshot.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ReferencePath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $DifferencePath,
        [AllowEmptyCollection()] [object[]] $AuditEvent
    )

    $referenceResolved = (Resolve-Path -LiteralPath $ReferencePath -ErrorAction Stop).Path
    $differenceResolved = (Resolve-Path -LiteralPath $DifferencePath -ErrorAction Stop).Path
    $reference = ConvertFrom-IntuneAccessSnapshotJson -Json (Get-Content -LiteralPath $referenceResolved -Raw)
    $difference = ConvertFrom-IntuneAccessSnapshotJson -Json (Get-Content -LiteralPath $differenceResolved -Raw)
    foreach ($snapshot in @($reference, $difference)) {
        $schemaVersion = [string] (Get-IntuneAccessProperty $snapshot 'SchemaVersion')
        if ($schemaVersion -notin @('1.0', '2.0') -or
            [string] (Get-IntuneAccessProperty $snapshot 'Schema') -ne "https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-$schemaVersion.json" -or
            $null -eq (Get-IntuneAccessProperty $snapshot 'Data')) {
            throw 'Both files must be supported IntuneAccess snapshot schema version 1.0 or 2.0.'
        }
        $expectedHash = [string] (Get-IntuneAccessProperty $snapshot 'IntegritySha256')
        $actualHash = Get-IntuneAccessSnapshotHash -Value ((Get-IntuneAccessProperty $snapshot 'Data') | ConvertTo-Json -Depth 40 -Compress)
        if ($expectedHash -ne $actualHash) { throw 'Snapshot integrity validation failed. The file may have been edited or truncated.' }
    }
    if ([string] (Get-IntuneAccessProperty $reference 'IdentityMode') -ne [string] (Get-IntuneAccessProperty $difference 'IdentityMode')) {
        throw 'Snapshots must use the same identity mode before they can be compared.'
    }
    $referenceTenant = [string] (Get-IntuneAccessProperty $reference.Tenant 'Id' '')
    $differenceTenant = [string] (Get-IntuneAccessProperty $difference.Tenant 'Id' '')
    if ([string]::IsNullOrWhiteSpace($referenceTenant) -or $referenceTenant -cne $differenceTenant) {
        throw 'Snapshots must identify the same tenant. Missing or different tenant IDs cannot be compared.'
    }
    if ([DateTimeOffset] $difference.ExportedAt -le [DateTimeOffset] $reference.ExportedAt) {
        throw 'The difference snapshot must be later than the reference snapshot.'
    }

    $collectionMap = [ordered] @{
        Administrators      = 'Administrator'
        AdminGroups         = 'AdminGroup'
        RoleAssignments     = 'RoleAssignment'
        RoleDefinitions     = 'RoleDefinition'
        ScopeGroups         = 'ScopeGroup'
        ScopeTags           = 'ScopeTag'
        Permissions         = 'Permission'
        Memberships         = 'Membership'
        WorkloadObjects     = 'Workload'
        WorkloadAssignments = 'WorkloadAssignment'
        WorkloadGroups      = 'WorkloadGroup'
        AssignmentFilters   = 'AssignmentFilter'
        PolicySettings      = 'PolicySetting'
        PolicyConflictFindings = 'PolicyConflictFinding'
        ManagedDevices      = 'ManagedDevice'
        DeviceInventory     = 'DeviceInventoryRecord'
        DeviceFindings      = 'DeviceFinding'
        DeviceAssignmentExplanations = 'DeviceAssignmentExplanation'
        AutopilotTimelines  = 'AutopilotTimeline'
        DetectedApplications = 'DetectedApplication'
        DeviceApplicationEvidence = 'DeviceApplicationEvidence'
        UpdateComplianceInvestigations = 'UpdateComplianceInvestigation'
        EstateFindings      = 'EstateFinding'
    }
    $changes = [Collections.Generic.List[object]]::new()
    foreach ($entry in $collectionMap.GetEnumerator()) {
        $before = @(Get-IntuneAccessProperty $reference.Data $entry.Key @())
        $after = @(Get-IntuneAccessProperty $difference.Data $entry.Key @())
        foreach ($change in @(Compare-IntuneAccessSnapshotCollection -Before $before -After $after -EntityType $entry.Value)) {
            $changes.Add((Add-IntuneAccessSnapshotImpact -Change $change -SnapshotData $difference.Data))
        }
    }

    if (-not $PSBoundParameters.ContainsKey('AuditEvent')) {
        $AuditEvent = @(Get-IntuneAccessProperty $difference.Data 'AuditEvents' @())
    }
    foreach ($change in $changes) {
        $candidateIds = [Collections.Generic.List[string]]::new()
        foreach ($candidate in @(([string] $change.Id) -split '::|\|')) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) { $candidateIds.Add($candidate) }
        }
        foreach ($record in @($change.Before, $change.After)) {
            if ($null -eq $record) { continue }
            foreach ($propertyName in @('Id', 'WorkloadId', 'FirstPolicyId', 'SecondPolicyId', 'RoleDefinitionId', 'GroupId')) {
                $candidate = [string] (Get-IntuneAccessProperty $record $propertyName '')
                if (-not [string]::IsNullOrWhiteSpace($candidate)) { $candidateIds.Add($candidate) }
            }
        }
        $relatedAuditEvents = @($AuditEvent | Where-Object {
            $resourceIds = @(Get-IntuneAccessProperty $_ 'ResourceIds' @())
            @($resourceIds | Where-Object { $_ -in $candidateIds }).Count -gt 0
        })
        $change | Add-Member -NotePropertyName AuditEvents -NotePropertyValue $relatedAuditEvents -Force
        $change | Add-Member -NotePropertyName AuditEvidenceState -NotePropertyValue $(if ($relatedAuditEvents.Count) { 'ObservedRelatedEvent' } else { 'NoMatchingEventReturned' }) -Force
    }

    $result = [PSCustomObject] @{
        PSTypeName       = 'IntuneAccess.SnapshotComparison'
        ReferencePath    = $referenceResolved
        DifferencePath   = $differenceResolved
        ReferenceAt      = [DateTimeOffset] $reference.ExportedAt
        DifferenceAt     = [DateTimeOffset] $difference.ExportedAt
        IdentityMode     = [string] $difference.IdentityMode
        Tenant           = $difference.Tenant
        Changes          = @($changes | Sort-Object EntityType, Name, ChangeType)
        FindingVerification = @(Compare-IntuneAccessFindingEvidence -Before $reference.Data -After $difference.Data -BeforeAt ([DateTimeOffset] $reference.ExportedAt) -AfterAt ([DateTimeOffset] $difference.ExportedAt))
        ActionCentre = Get-IntuneAccessActionCentre -Collection $difference.Data -PreviousOutcome @(Get-IntuneAccessProperty $reference.Data 'DeploymentOutcomes' @()) -AsOf ([DateTimeOffset] $difference.ExportedAt)
        AddedCount       = @($changes | Where-Object ChangeType -EQ 'Added').Count
        RemovedCount     = @($changes | Where-Object ChangeType -EQ 'Removed').Count
        ModifiedCount    = @($changes | Where-Object ChangeType -EQ 'Modified').Count
        BroadImpactCount = @($changes | Where-Object ImpactState -EQ 'BroadTarget').Count
        ReadOnly         = $true
        GeneratedAt      = [DateTimeOffset]::Now
        ToolVersion      = $script:IntuneAccessVersion
    }
    $result.PSObject.TypeNames.Insert(0, 'IntuneAccess.SnapshotComparison')
    $result
}
