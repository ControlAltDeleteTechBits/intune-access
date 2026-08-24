function Get-IntuneDeviceAssignmentExplanation {
    <#
    .SYNOPSIS
    Explains why an Intune device was included, excluded, not targeted or not evaluated.
    .DESCRIPTION
    Evaluates supported broad targets, transitive device and associated-user group membership, exclusions and a conservative subset of assignment filters. Reported deployment outcomes remain separate from calculated assignment evidence.
    .PARAMETER DeviceName
    Exact Intune managed-device name.
    .PARAMETER ManagedDeviceId
    Exact Intune managed-device ID.
    .PARAMETER WorkloadId
    Optional exact policy, application, script or update workload ID.
    .EXAMPLE
    Get-IntuneDeviceAssignmentExplanation -DeviceName 'LAPTOP-0234'
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')] [ValidateNotNullOrEmpty()] [string] $DeviceName,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [ValidateNotNullOrEmpty()] [string] $ManagedDeviceId,
        [ValidateNotNullOrEmpty()] [string] $WorkloadId
    )

    $inventory = Get-IntuneAccessWorkloadAssignments
    $operational = Get-IntuneAccessOperationalEvidence -Workload $inventory.Workloads
    $deviceMatches = if ($PSCmdlet.ParameterSetName -eq 'ById') { @($operational.ManagedDevices | Where-Object Id -EQ $ManagedDeviceId) } else { @($operational.ManagedDevices | Where-Object DeviceName -EQ $DeviceName) }
    if ($deviceMatches.Count -ne 1) { throw "Expected one matching Intune managed device but found $($deviceMatches.Count)." }
    $device = $deviceMatches[0]
    $parsedEntraDeviceId = [guid]::Empty
    $hasValidEntraDeviceId = [guid]::TryParse([string] $device.EntraDeviceId, [ref] $parsedEntraDeviceId)
    $deviceMembership = if ($hasValidEntraDeviceId) { Get-IntuneAccessDeviceMembership -EntraDeviceId $parsedEntraDeviceId } else { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @(); Explanation = 'The Intune record did not contain a valid Microsoft Entra device ID.' } }
    $userMembership = Get-IntuneAccessManagedDeviceUserMembership -UserId $device.UserId
    $workloads = if ([string]::IsNullOrWhiteSpace($WorkloadId)) { @($inventory.Workloads) } else { @($inventory.Workloads | Where-Object Id -EQ $WorkloadId) }
    if ($workloads.Count -eq 0) { throw 'No matching workload was returned.' }
    Resolve-IntuneAccessDeviceAssignment -Device $device -Workload $workloads -Assignment $inventory.Assignments -DeviceMembership $deviceMembership -UserMembership $userMembership -DeploymentOutcome $operational.DeploymentOutcomes
}
