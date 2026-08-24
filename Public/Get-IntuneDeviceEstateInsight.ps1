function Get-IntuneDeviceEstateInsight {
    <#
    .SYNOPSIS
    Builds prioritised, cross-device Intune estate findings.
    .DESCRIPTION
    Combines device hygiene, deployment, application, update, compliance and optional Autopilot evidence into ranked findings, cohorts, recurring patterns and share-safe pseudonymised data. Grouped evidence does not assert a common cause.
    .PARAMETER IncludeAutopilot
    Includes optional Microsoft Graph beta Autopilot and Enrolment Status Page evidence. The current connection must include the Autopilot feature.
    .PARAMETER ReferenceSnapshotPath
    Supplies the older local IntuneAccess snapshot for historical comparison. DifferenceSnapshotPath is also required.
    .PARAMETER DifferenceSnapshotPath
    Supplies the newer local IntuneAccess snapshot for historical comparison. ReferenceSnapshotPath is also required.
    .EXAMPLE
    Get-IntuneDeviceEstateInsight
    .EXAMPLE
    Get-IntuneDeviceEstateInsight -ReferenceSnapshotPath '.\before.json' -DifferenceSnapshotPath '.\after.json'
    #>
    [CmdletBinding()]
    param(
        [switch] $IncludeAutopilot,
        [string] $ReferenceSnapshotPath,
        [string] $DifferenceSnapshotPath
    )

    if ([string]::IsNullOrWhiteSpace($ReferenceSnapshotPath) -xor [string]::IsNullOrWhiteSpace($DifferenceSnapshotPath)) {
        throw 'ReferenceSnapshotPath and DifferenceSnapshotPath must be supplied together.'
    }

    $workload = Get-IntuneAccessWorkloadAssignments
    $operational = Get-IntuneAccessOperationalEvidence -Workload $workload.Workloads
    $device = Get-IntuneAccessDeviceIntelligence -ManagedDevice $operational.ManagedDevices
    $applications = Get-IntuneAccessApplicationEvidence -Workload $workload.Workloads -Assignment $workload.Assignments -ManagedDevice $operational.ManagedDevices -DeploymentOutcome $operational.DeploymentOutcomes
    $updates = Get-IntuneAccessUpdateComplianceEvidence -Workload $workload.Workloads -Assignment $workload.Assignments -ManagedDevice $operational.ManagedDevices -DeploymentOutcome $operational.DeploymentOutcomes
    $autopilot = if ($IncludeAutopilot) { Get-IntuneAccessAutopilotEvidence -ManagedDevice $operational.ManagedDevices } else { $null }
    $comparison = if (-not [string]::IsNullOrWhiteSpace($ReferenceSnapshotPath)) {
        Compare-IntuneAccessSnapshot -ReferencePath $ReferenceSnapshotPath -DifferencePath $DifferenceSnapshotPath
    }
    else { $null }
    Get-IntuneAccessEstateInsight -DeviceIntelligence $device -ApplicationEvidence $applications -UpdateComplianceEvidence $updates -AutopilotEvidence $autopilot -DeploymentOutcome $operational.DeploymentOutcomes -SnapshotComparison $comparison
}
