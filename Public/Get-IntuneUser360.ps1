function Get-IntuneUser360 {
    <#
    .SYNOPSIS
    Gets a read-only Intune evidence view for one managed user.
    .DESCRIPTION
    Correlates the user's Intune managed devices with supported configuration,
    compliance, application, script and remediation outcome records.
    .PARAMETER UserPrincipalName
    Exact user principal name returned by Intune managed-device or outcome data.
    .EXAMPLE
    Get-IntuneUser360 -UserPrincipalName 'alex.wilber@contoso.com'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()] [string] $UserPrincipalName
    )

    $workloadInventory = Get-IntuneAccessWorkloadAssignments
    $operational = Get-IntuneAccessOperationalEvidence -Workload $workloadInventory.Workloads
    $userMatches = @($operational.ManagedUsers | Where-Object UserPrincipalName -EQ $UserPrincipalName)
    if ($userMatches.Count -eq 0) {
        throw "No matching Intune managed user was returned."
    }

    $user = $userMatches[0]
    $devices = @($operational.ManagedDevices | Where-Object UserPrincipalName -EQ $user.UserPrincipalName)
    $deviceIds = @($devices.Id)
    $userOutcomes = @($operational.DeploymentOutcomes | Where-Object { $_.UserPrincipalName -eq $user.UserPrincipalName -or $_.DeviceId -in $deviceIds })
    $workloadIds = @($userOutcomes.WorkloadId | Select-Object -Unique)

    [PSCustomObject] @{
        PSTypeName            = 'IntuneAccess.User360'
        User                  = $user
        ManagedDevices        = $devices
        DeploymentOutcomes    = $userOutcomes
        Workloads             = @($workloadInventory.Workloads | Where-Object Id -In $workloadIds)
        ConfiguredAssignments = @($workloadInventory.Assignments | Where-Object WorkloadId -In $workloadIds)
        ErrorCount            = @($userOutcomes | Where-Object Category -EQ 'Error').Count
        PendingCount          = @($userOutcomes | Where-Object Category -EQ 'Pending').Count
        CollectionStatus      = $operational.CollectionStatus
        Warnings              = @($workloadInventory.Warnings) + @($operational.Warnings)
        ReadOnly              = $true
        GeneratedAt           = [DateTimeOffset]::Now
        ToolVersion           = $script:IntuneAccessVersion
    }
}
