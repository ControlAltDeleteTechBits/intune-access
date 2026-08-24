function Get-IntuneAccessUpdateComplianceEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Workload,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Assignment,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $ManagedDevice,
        [AllowEmptyCollection()] [object[]] $DeploymentOutcome = @(),
        [datetimeoffset] $AsOf = [DateTimeOffset]::Now
    )

    $investigations = [System.Collections.Generic.List[object]]::new()
    $updateWorkloads = @($Workload | Where-Object { (Get-IntuneAccessProperty $_ 'WorkloadType') -eq 'Updates' -or (Get-IntuneAccessProperty $_ 'SourceCollection') -match '(?i)update' })
    $complianceWorkloads = @($Workload | Where-Object WorkloadType -EQ 'Compliance')
    $apiVersions = @($updateWorkloads + $complianceWorkloads | ForEach-Object {
        [string] (Get-IntuneAccessProperty $_ 'SourceApiVersion' 'NotReturned')
    } | Select-Object -Unique)
    foreach ($device in $ManagedDevice) {
        $lastSync = ConvertTo-IntuneAccessDateTimeOffset $device.LastSyncDateTime
        $age = if ($null -eq $lastSync) { $null } else { [math]::Max(0, [math]::Floor(($AsOf - $lastSync).TotalDays)) }
        foreach ($item in @($updateWorkloads + $complianceWorkloads)) {
            $outcomes = @($DeploymentOutcome | Where-Object { $_.WorkloadId -eq $item.Id -and $_.DeviceId -eq $device.Id })
            $assignments = @($Assignment | Where-Object WorkloadId -EQ $item.Id)
            $returnedState = if ($outcomes.Count -eq 0) { 'NoReportedEvidence' } elseif (@($outcomes | Where-Object Category -EQ 'Error').Count -gt 0) { 'ReturnedFailure' } elseif (@($outcomes | Where-Object Category -EQ 'Success').Count -gt 0) { 'ReportedSuccess' } else { [string] $outcomes[0].Category }
            $targetVersion = [string] (Get-IntuneAccessProperty $item 'TargetVersion')
            $patchState = 'NotEvaluated'
            $reason = 'No dependable target version and supported device result were available together.'
            if ($item.WorkloadType -eq 'Compliance') {
                $patchState = switch -Regex ([string] $device.ComplianceState) {
                    '^compliant$' { 'ReportedCompliant'; break }
                    '^noncompliant$' { 'ReportedNonCompliant'; break }
                    default { 'NotEvaluated' }
                }
                $reason = 'This state comes from the managed-device compliance summary; setting-level evidence can differ.'
            }
            elseif (-not [string]::IsNullOrWhiteSpace($targetVersion) -and -not [string]::IsNullOrWhiteSpace([string] $device.OsVersion)) {
                $patchState = if ([string] $device.OsVersion -match [regex]::Escape($targetVersion)) { 'TargetVersionObserved' } else { 'OutsideObservedTargetVersion' }
                $reason = 'The current OS version was compared with the version label returned by the update workload. This does not prove update eligibility or deadline state.'
            }
            if ($returnedState -eq 'ReturnedFailure') { $patchState = 'ReturnedFailure'; $reason = 'A supported Microsoft Graph outcome endpoint returned an error-category result.' }
            elseif ($age -ge 30 -and $patchState -notin @('ReturnedFailure')) { $patchState = 'StaleReporting'; $reason = "The latest managed-device check-in evidence is $age days old." }

            if ($assignments.Count -gt 0 -or $outcomes.Count -gt 0 -or $item.WorkloadType -eq 'Compliance') {
                $investigations.Add([PSCustomObject] @{
                    PSTypeName         = 'IntuneAccess.UpdateComplianceInvestigation'
                    DeviceId           = [string] $device.Id
                    DeviceName         = [string] $device.DeviceName
                    UserPrincipalName  = [string] $device.UserPrincipalName
                    OperatingSystem    = [string] $device.OperatingSystem
                    OsVersion          = [string] $device.OsVersion
                    WorkloadId         = [string] $item.Id
                    WorkloadName       = [string] $item.Name
                    WorkloadType       = [string] $item.WorkloadType
                    SourceCollection   = [string] (Get-IntuneAccessProperty $item 'SourceCollection' 'NotReturned')
                    TargetVersion      = $targetVersion
                    ConfiguredTargets  = $assignments
                    ReportedOutcomes   = $outcomes
                    ReportedState      = $returnedState
                    InvestigationState = $patchState
                    Explanation        = $reason
                    EvidenceAgeDays    = $age
                    EvidenceTimestamp  = $lastSync
                    EvidenceBoundary   = 'Configured targeting, reporting delay, stale evidence, returned failure and unavailable evidence are separate states. A configured target is not proof of applicability or delivery.'
                })
            }
        }
    }

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.UpdateComplianceEvidence'
        Investigations       = $investigations.ToArray()
        UpdateWorkloads      = $updateWorkloads
        ComplianceWorkloads  = $complianceWorkloads
        CollectionStatus     = [PSCustomObject] @{ State = if ($ManagedDevice.Count -eq 0) { 'NoDeviceEvidence' } else { 'Available' }; RecordCount = $investigations.Count; ApiVersions = $apiVersions }
        Warnings             = @('Update and compliance reporting availability varies by workload. NotEvaluated is retained where the collected evidence cannot support a conclusion.')
        GraphPermissionsUsed = @('DeviceManagementConfiguration.Read.All', 'DeviceManagementManagedDevices.Read.All')
        GeneratedAt          = $AsOf
        ToolVersion          = $script:IntuneAccessVersion
    }
}
