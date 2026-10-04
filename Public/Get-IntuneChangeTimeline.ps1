function Get-IntuneChangeTimeline {
    <#
    .SYNOPSIS
    Shows what changed in Intune and what happened on devices afterwards, in one timeline.
    .DESCRIPTION
    Merges Intune audit events (who changed what, when), configuration differences between two local
    snapshots, and changes in reported device results. Check-in and inventory refreshes are counted
    but not listed. When a device reports a failure on the same workload soon after a change, the
    change is marked as correlated in time. Correlation is not proof of cause. Read only.
    .PARAMETER ReferenceSnapshotPath
    Earlier local snapshot. Use with DifferenceSnapshotPath for an offline comparison.
    .PARAMETER DifferenceSnapshotPath
    Later local snapshot.
    .PARAMETER CorrelationHours
    How long after a change a reported failure on the same workload is marked as correlated. Default 72.
    .EXAMPLE
    Get-IntuneChangeTimeline
    .EXAMPLE
    (Get-IntuneChangeTimeline -ReferenceSnapshotPath .\monday.json -DifferenceSnapshotPath .\tuesday.json).Entries |
        Format-Table Time, Kind, Title, Target, Actor
    #>
    [CmdletBinding(DefaultParameterSetName = 'Live')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Snapshot')] [ValidateNotNullOrEmpty()] [string] $ReferenceSnapshotPath,
        [Parameter(Mandatory, ParameterSetName = 'Snapshot')] [ValidateNotNullOrEmpty()] [string] $DifferenceSnapshotPath,
        [ValidateRange(1, 720)] [int] $CorrelationHours = 72
    )

    if ($PSCmdlet.ParameterSetName -eq 'Snapshot') {
        $comparison = Compare-IntuneAccessSnapshot -ReferencePath $ReferenceSnapshotPath -DifferencePath $DifferenceSnapshotPath
        $current = Read-IntuneAccessSnapshotFile -Path $DifferenceSnapshotPath
        return Get-IntuneAccessChangeTimeline -AuditEvent @(Get-IntuneAccessProperty $current.Data 'AuditEvents' @()) -SnapshotComparison $comparison -DeploymentOutcome @(Get-IntuneAccessProperty $current.Data 'DeploymentOutcomes' @()) -Workload @(Get-IntuneAccessProperty $current.Data 'WorkloadObjects' @()) -AsOf ([DateTimeOffset] $comparison.DifferenceAt) -CorrelationHours $CorrelationHours
    }

    $collection = Get-IntuneAccessInsightCollection -IncludeOperationalEvidence -IncludeAuditEvidence
    Get-IntuneAccessChangeTimeline -AuditEvent @($collection.AuditEvents) -DeploymentOutcome @($collection.DeploymentOutcomes) -Workload @($collection.WorkloadObjects) -CorrelationHours $CorrelationHours
}
