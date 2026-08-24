function Get-IntuneUpdateCompliance {
    <#
    .SYNOPSIS
    Investigates update targeting, OS evidence and compliance reporting for Intune devices.
    .DESCRIPTION
    Correlates supported update and compliance workload configuration with managed-device state and returned outcomes. Missing targeting, reporting delay, stale evidence, returned failure and unavailable evidence remain distinct.
    .PARAMETER DeviceName
    Optional exact managed-device name.
    .EXAMPLE
    Get-IntuneUpdateCompliance -DeviceName 'LAPTOP-0234'
    #>
    [CmdletBinding()]
    param([ValidateNotNullOrEmpty()] [string] $DeviceName)

    $inventory = Get-IntuneAccessWorkloadAssignments
    $operational = Get-IntuneAccessOperationalEvidence -Workload $inventory.Workloads
    $devices = if ([string]::IsNullOrWhiteSpace($DeviceName)) { @($operational.ManagedDevices) } else { @($operational.ManagedDevices | Where-Object DeviceName -EQ $DeviceName) }
    if (-not [string]::IsNullOrWhiteSpace($DeviceName) -and $devices.Count -eq 0) { throw 'No matching Intune managed device was returned.' }
    Get-IntuneAccessUpdateComplianceEvidence -Workload $inventory.Workloads -Assignment $inventory.Assignments -ManagedDevice $devices -DeploymentOutcome $operational.DeploymentOutcomes
}
