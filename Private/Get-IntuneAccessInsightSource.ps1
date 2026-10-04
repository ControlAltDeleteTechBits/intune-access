function Read-IntuneAccessSnapshotFile {
    <#
    Loads one IntuneAccess snapshot and validates its schema and integrity hash.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $snapshot = ConvertFrom-IntuneAccessSnapshotJson -Json (Get-Content -LiteralPath $resolved -Raw)
    $schemaVersion = [string] (Get-IntuneAccessProperty $snapshot 'SchemaVersion')
    if ($schemaVersion -notin @('1.0', '2.0') -or
        [string] (Get-IntuneAccessProperty $snapshot 'Schema') -ne "https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-$schemaVersion.json" -or
        $null -eq (Get-IntuneAccessProperty $snapshot 'Data')) {
        throw 'The file must be a supported IntuneAccess snapshot (schema version 1.0 or 2.0).'
    }
    $expectedHash = [string] (Get-IntuneAccessProperty $snapshot 'IntegritySha256')
    $actualHash = Get-IntuneAccessSnapshotHash -Value ((Get-IntuneAccessProperty $snapshot 'Data') | ConvertTo-Json -Depth 40 -Compress)
    if ($expectedHash -ne $actualHash) { throw 'Snapshot integrity validation failed. The file may have been edited or truncated.' }
    $snapshot
}

function Get-IntuneAccessInsightCollection {
    <#
    Returns the evidence collection used by the 5.0 insight commands: either a validated local
    snapshot or a fresh read-only collection from the current Microsoft Graph session.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [string] $SnapshotPath,
        [switch] $IncludeWorkloadAssignments,
        [switch] $IncludeOperationalEvidence,
        [switch] $IncludeAuditEvidence,
        [switch] $IncludeAssignmentExplanations
    )

    if (-not [string]::IsNullOrWhiteSpace($SnapshotPath)) {
        $snapshot = Read-IntuneAccessSnapshotFile -Path $SnapshotPath
        $data = $snapshot.Data
        $data | Add-Member -NotePropertyName Tenant -NotePropertyValue $snapshot.Tenant -Force
        $data | Add-Member -NotePropertyName EvidenceSource -NotePropertyValue "Snapshot $SnapshotPath" -Force
        $data | Add-Member -NotePropertyName GeneratedAt -NotePropertyValue (Get-IntuneAccessProperty $data 'CollectedAt' $snapshot.ExportedAt) -Force
        return $data
    }

    $collection = Get-IntuneAccessTenantRbac `
        -IncludeWorkloadAssignments:($IncludeWorkloadAssignments -or $IncludeOperationalEvidence -or $IncludeAssignmentExplanations) `
        -IncludeOperationalEvidence:($IncludeOperationalEvidence -or $IncludeAssignmentExplanations) `
        -IncludeDeviceIntelligence:$IncludeAssignmentExplanations `
        -IncludeAssignmentExplanations:$IncludeAssignmentExplanations `
        -IncludeAuditEvidence:$IncludeAuditEvidence
    $collection | Add-Member -NotePropertyName EvidenceSource -NotePropertyValue 'Live read-only collection' -Force
    $collection
}

function Add-IntuneAccessInsights {
    <#
    Adds the 5.0 insight datasets to a collected model before the report is generated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Collection,
        [AllowNull()] [object] $Assessment,
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow
    )

    $devices = @{}
    foreach ($device in @(Get-IntuneAccessProperty $Collection 'ManagedDevices' @())) { $devices[[string] $device.Id] = $device }
    $status = @(Get-IntuneAccessProperty $Collection 'OutcomeCollectionStatus' @())
    $chains = @(foreach ($explanation in @(Get-IntuneAccessProperty $Collection 'DeviceAssignmentExplanations' @())) {
        $device = if ($devices.ContainsKey([string] $explanation.DeviceId)) { $devices[[string] $explanation.DeviceId] } else { $null }
        Get-IntuneAccessDeliveryChain -Explanation $explanation -Device $device -OutcomeCollectionStatus $status -AsOf $AsOf
    })
    $timeline = Get-IntuneAccessChangeTimeline -AuditEvent @(Get-IntuneAccessProperty $Collection 'AuditEvents' @()) -SnapshotComparison (Get-IntuneAccessProperty $Collection 'SnapshotComparison') -DeploymentOutcome @(Get-IntuneAccessProperty $Collection 'DeploymentOutcomes' @()) -Workload @(Get-IntuneAccessProperty $Collection 'WorkloadObjects' @()) -AsOf $AsOf
    $Collection | Add-Member -NotePropertyName DeliveryChains -NotePropertyValue $chains -Force
    $Collection | Add-Member -NotePropertyName ChangeTimeline -NotePropertyValue $timeline -Force
    $Collection | Add-Member -NotePropertyName DependencyIndex -NotePropertyValue @(Get-IntuneAccessDependencyIndex -Collection $Collection) -Force
    $Collection | Add-Member -NotePropertyName PrivilegeUsage -NotePropertyValue (Get-IntuneAccessPrivilegeUsage -Collection $Collection) -Force
    $Collection | Add-Member -NotePropertyName ScopedReadiness -NotePropertyValue (Get-IntuneAccessScopedReadiness -Collection $Collection -Assessment $Assessment) -Force
    $Collection
}
