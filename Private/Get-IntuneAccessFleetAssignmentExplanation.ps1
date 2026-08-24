function Get-IntuneAccessFleetAssignmentExplanation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $ManagedDevice,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Workload,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Assignment,
        [AllowEmptyCollection()] [object[]] $DeploymentOutcome = @(),
        [ValidateRange(1, 10000)] [int] $MaximumDevices = 250
    )

    $records = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $selectedDevices = @($ManagedDevice | Select-Object -First $MaximumDevices)
    foreach ($device in $selectedDevices) {
        $parsedEntraDeviceId = [guid]::Empty
        $deviceMembership = if ([guid]::TryParse([string] $device.EntraDeviceId, [ref] $parsedEntraDeviceId)) {
            try { Get-IntuneAccessDeviceMembership -EntraDeviceId $parsedEntraDeviceId } catch { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @(); Explanation = $_.Exception.Message } }
        }
        else { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @(); Explanation = 'No valid Microsoft Entra device ID was returned.' } }
        $userMembership = Get-IntuneAccessManagedDeviceUserMembership -UserId $device.UserId
        foreach ($record in @(Resolve-IntuneAccessDeviceAssignment -Device $device -Workload $Workload -Assignment $Assignment -DeviceMembership $deviceMembership -UserMembership $userMembership -DeploymentOutcome $DeploymentOutcome)) { $records.Add($record) }
    }
    if ($ManagedDevice.Count -gt $MaximumDevices) { $warnings.Add("Fleet assignment explanation was limited to $MaximumDevices of $($ManagedDevice.Count) devices. Use Get-IntuneDeviceAssignmentExplanation for an exact device outside this collection.") }
    [PSCustomObject] @{
        PSTypeName = 'IntuneAccess.FleetAssignmentExplanation'; Explanations = $records.ToArray()
        CollectionStatus = [PSCustomObject] @{ State = if ($ManagedDevice.Count -gt $MaximumDevices) { 'Partial' } else { 'Available' }; DeviceCount = $selectedDevices.Count; TotalDeviceCount = $ManagedDevice.Count; RecordCount = $records.Count }
        Warnings = $warnings.ToArray(); GeneratedAt = [DateTimeOffset]::Now; ToolVersion = $script:IntuneAccessVersion
    }
}
