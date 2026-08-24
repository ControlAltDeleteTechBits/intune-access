function Get-IntuneDevice360 {
    <#
    .SYNOPSIS
    Gets a read-only Intune evidence view for one managed device.
    .DESCRIPTION
    Correlates managed-device identity with supported configuration, compliance,
    application, script and remediation outcome records. Missing outcome data is
    not treated as success, failure or proof that a workload was assigned.
    .PARAMETER DeviceName
    Exact Intune managed-device name.
    .PARAMETER ManagedDeviceId
    Exact Intune managed-device ID.
    .EXAMPLE
    Get-IntuneDevice360 -DeviceName 'LAPTOP-0234'
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()] [string] $DeviceName,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()] [string] $ManagedDeviceId
    )

    $workloadInventory = Get-IntuneAccessWorkloadAssignments
    $operational = Get-IntuneAccessOperationalEvidence -Workload $workloadInventory.Workloads
    $deviceMatches = if ($PSCmdlet.ParameterSetName -eq 'ById') {
        @($operational.ManagedDevices | Where-Object Id -EQ $ManagedDeviceId)
    }
    else {
        @($operational.ManagedDevices | Where-Object DeviceName -EQ $DeviceName)
    }

    if ($deviceMatches.Count -eq 0) {
        throw "No matching Intune managed device was returned."
    }
    if ($deviceMatches.Count -gt 1) {
        throw "More than one Intune managed device matched. Use -ManagedDeviceId to select an exact object."
    }

    $device = $deviceMatches[0]
    $deviceOutcomes = @($operational.DeploymentOutcomes | Where-Object DeviceId -EQ $device.Id)
    $workloadIds = @($deviceOutcomes.WorkloadId | Select-Object -Unique)
    $intelligence = Get-IntuneAccessDeviceIntelligence -ManagedDevice @($device)
    $parsedEntraDeviceId = [guid]::Empty
    $deviceMembership = if ([guid]::TryParse([string] (Get-IntuneAccessProperty $device 'EntraDeviceId'), [ref] $parsedEntraDeviceId)) { Get-IntuneAccessDeviceMembership -EntraDeviceId $parsedEntraDeviceId } else { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @(); Explanation = 'No valid Microsoft Entra device ID was returned.' } }
    $userMembership = Get-IntuneAccessManagedDeviceUserMembership -UserId ([string] (Get-IntuneAccessProperty $device 'UserId'))
    $assignmentExplanations = Resolve-IntuneAccessDeviceAssignment -Device $device -Workload $workloadInventory.Workloads -Assignment $workloadInventory.Assignments -DeviceMembership $deviceMembership -UserMembership $userMembership -DeploymentOutcome $deviceOutcomes
    $applicationEvidence = Get-IntuneAccessApplicationEvidence -Workload $workloadInventory.Workloads -Assignment $workloadInventory.Assignments -ManagedDevice @($device) -DeploymentOutcome $deviceOutcomes
    $updateCompliance = Get-IntuneAccessUpdateComplianceEvidence -Workload $workloadInventory.Workloads -Assignment $workloadInventory.Assignments -ManagedDevice @($device) -DeploymentOutcome $deviceOutcomes

    [PSCustomObject] @{
        PSTypeName            = 'IntuneAccess.Device360'
        Device                = $device
        User                  = $operational.ManagedUsers | Where-Object UserPrincipalName -EQ ([string] (Get-IntuneAccessProperty $device 'UserPrincipalName')) | Select-Object -First 1
        DeploymentOutcomes    = $deviceOutcomes
        Workloads             = @($workloadInventory.Workloads | Where-Object Id -In $workloadIds)
        ConfiguredAssignments = @($workloadInventory.Assignments | Where-Object WorkloadId -In $workloadIds)
        ErrorCount            = @($deviceOutcomes | Where-Object Category -EQ 'Error').Count
        PendingCount          = @($deviceOutcomes | Where-Object Category -EQ 'Pending').Count
        Inventory             = @($intelligence.Inventory | Select-Object -First 1)
        HygieneFindings       = @($intelligence.Findings)
        AssignmentExplanations = @($assignmentExplanations)
        ApplicationEvidence  = @($applicationEvidence.DeviceApplicationEvidence)
        UpdateComplianceInvestigations = @($updateCompliance.Investigations)
        CollectionStatus      = $operational.CollectionStatus
        Warnings              = @($workloadInventory.Warnings) + @($operational.Warnings)
        ReadOnly              = $true
        GeneratedAt           = [DateTimeOffset]::Now
        ToolVersion           = $script:IntuneAccessVersion
    }
}
