function Get-IntuneDeliveryChain {
    <#
    .SYNOPSIS
    Explains why an Intune policy, app, script or update did or did not apply to a device.
    .DESCRIPTION
    Builds an ordered evidence chain for each workload on a device: check-in, assignment, targeting,
    exclusion, assignment filter, intent and the result Intune reported. The verdict comes from the
    first link that fails or where the evidence stops, and includes a suggested next check.
    Error codes are explained only where Microsoft publishes a meaning. Read only.
    .PARAMETER DeviceName
    Exact Intune managed-device name.
    .PARAMETER WorkloadName
    Optional workload name filter. Wildcards are supported.
    .PARAMETER SnapshotPath
    Use a local IntuneAccess snapshot instead of a live Microsoft Graph collection.
    .PARAMETER ProblemsOnly
    Return only chains that did not end in a reported success.
    .EXAMPLE
    Get-IntuneDeliveryChain -DeviceName 'LAPTOP-0234' -WorkloadName '*VPN*'
    .EXAMPLE
    Get-IntuneDeliveryChain -DeviceName 'LAPTOP-0234' -ProblemsOnly | Format-Table WorkloadName, Verdict, Summary
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $DeviceName,
        [ValidateNotNullOrEmpty()] [string] $WorkloadName = '*',
        [ValidateNotNullOrEmpty()] [string] $SnapshotPath,
        [switch] $ProblemsOnly
    )

    if ($PSBoundParameters.ContainsKey('SnapshotPath')) {
        $collection = Get-IntuneAccessInsightCollection -SnapshotPath $SnapshotPath
        $explanations = @(Get-IntuneAccessProperty $collection 'DeviceAssignmentExplanations' @() | Where-Object DeviceName -EQ $DeviceName)
        $devices = @(Get-IntuneAccessProperty $collection 'ManagedDevices' @() | Where-Object DeviceName -EQ $DeviceName)
        $status = @(Get-IntuneAccessProperty $collection 'OutcomeCollectionStatus' @())
        $asOf = [DateTimeOffset] (Get-IntuneAccessProperty $collection 'GeneratedAt' ([DateTimeOffset]::UtcNow))
        if ($explanations.Count -eq 0) { throw "The snapshot contains no assignment explanations for '$DeviceName'. Explanations are included when the snapshot was taken with device intelligence enabled." }
    }
    else {
        $inventory = Get-IntuneAccessWorkloadAssignments
        $operational = Get-IntuneAccessOperationalEvidence -Workload $inventory.Workloads
        $devices = @($operational.ManagedDevices | Where-Object DeviceName -EQ $DeviceName)
        if ($devices.Count -ne 1) { throw "Expected one matching Intune managed device but found $($devices.Count)." }
        $parsedEntraDeviceId = [guid]::Empty
        $deviceMembership = if ([guid]::TryParse([string] $devices[0].EntraDeviceId, [ref] $parsedEntraDeviceId)) { Get-IntuneAccessDeviceMembership -EntraDeviceId $parsedEntraDeviceId } else { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @() } }
        $userMembership = Get-IntuneAccessManagedDeviceUserMembership -UserId $devices[0].UserId
        $explanations = @(Resolve-IntuneAccessDeviceAssignment -Device $devices[0] -Workload @($inventory.Workloads) -Assignment @($inventory.Assignments) -DeviceMembership $deviceMembership -UserMembership $userMembership -DeploymentOutcome @($operational.DeploymentOutcomes))
        $status = @($operational.CollectionStatus)
        $asOf = [DateTimeOffset]::UtcNow
    }

    $device = if ($devices.Count) { $devices[0] } else { $null }
    foreach ($explanation in @($explanations | Where-Object { $_.WorkloadName -like $WorkloadName })) {
        $chain = Get-IntuneAccessDeliveryChain -Explanation $explanation -Device $device -OutcomeCollectionStatus $status -AsOf $asOf
        if ($ProblemsOnly -and $chain.Verdict -eq 'Applied') { continue }
        $chain
    }
}
