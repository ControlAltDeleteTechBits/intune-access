function Get-IntuneAccessRemediationEffectiveness {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()] [object[]] $Outcome = @(),
        [AllowEmptyCollection()] [object[]] $PreviousOutcome = @(),
        [AllowEmptyCollection()] [object[]] $Workload = @(),
        [AllowEmptyCollection()] [object[]] $CollectionStatus = @(),
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow,
        [ValidateRange(1, 365)] [int] $StaleAfterDays = 8
    )

    # Latest-state APIs do not provide execution history. Earlier snapshots provide
    # observations only; repeated copies of one execution are not repeat failures.
    foreach ($package in @($Workload | Where-Object { (Get-IntuneAccessProperty $_ 'SourceCollection' '') -eq 'Remediations' })) {
        $packageId = [string] $package.Id
        $records = @($Outcome | Where-Object WorkloadId -EQ $packageId)
        $status = @($CollectionStatus | Where-Object WorkloadId -EQ $packageId)
        $collectionAvailable = $status.Count -eq 1 -and $status[0].State -eq 'Available'
        $previousDevices = @($PreviousOutcome | Where-Object { $_.WorkloadId -eq $packageId -and -not [string]::IsNullOrWhiteSpace([string] (Get-IntuneAccessProperty $_ 'DeviceId' '')) } | Group-Object DeviceId)
        foreach ($previousDevice in $previousDevices) {
            if (@($records | Where-Object DeviceId -EQ $previousDevice.Name).Count -eq 0) {
                [pscustomobject] @{
                    Id = "REMEDIATION/$packageId/$($previousDevice.Name)/missing"
                    WorkloadId = $packageId; WorkloadName = [string] $package.Name; DeviceId = $previousDevice.Name
                    DeviceName = [string] (Get-IntuneAccessProperty $previousDevice.Group[0] 'DeviceName' '')
                    FindingState = 'MissingReportedResult'; ObservedState = 'NotReturned'; DetectionState = ''; RemediationState = ''
                    HistoryState = 'PreviousResultNotReturned'; PreviousObservation = @($previousDevice.Group)
                    EvidenceTimestamp = $null; EvidenceAgeDays = $null; Evidence = $null; CollectionAvailable = $collectionAvailable
                    Explanation = 'This device had an earlier result but no current result was returned. This does not prove the package stopped running or that the problem was fixed.'
                    ResolutionState = 'NotConfirmed'; CollectedAt = $AsOf
                }
            }
        }
        if ($records.Count -eq 0) {
            [PSCustomObject] @{
                Id = "REMEDIATION/$packageId"; WorkloadId = $packageId; WorkloadName = [string] $package.Name; DeviceId = ''; DeviceName = ''
                FindingState = if ($collectionAvailable) { 'NoReportedResults' } else { 'NotEvaluated' }
                DetectionState = ''; RemediationState = ''; HistoryState = 'NotEvaluated'; PreviousObservation = $null
                EvidenceTimestamp = $null; EvidenceAgeDays = $null; Evidence = $null; CollectionAvailable = $collectionAvailable
                Explanation = 'No device result is available. This does not establish whether the package ran or which devices should have reported.'
                ResolutionState = 'NotConfirmed'; CollectedAt = $AsOf
            }
            continue
        }
        foreach ($record in $records) {
            $deviceId = [string] (Get-IntuneAccessProperty $record 'DeviceId' '')
            $detection = [string] (Get-IntuneAccessProperty $record 'DetectionState' '')
            $remediation = [string] (Get-IntuneAccessProperty $record 'RemediationState' '')
            $timestamp = Get-IntuneAccessProperty $record 'LastStateUpdateDateTime'
            $parsed = [DateTimeOffset]::MinValue
            $validTime = [DateTimeOffset]::TryParse([string] $timestamp, [ref] $parsed) -and $parsed -le $AsOf
            $age = if ($validTime) { [math]::Round(($AsOf - $parsed).TotalDays, 2) } else { $null }
            $errors = @('PreRemediationDetectionScriptError', 'RemediationScriptError', 'PostRemediationDetectionScriptError' | ForEach-Object {
                [string] (Get-IntuneAccessProperty $record $_ '')
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $state = 'NotEvaluated'
            $explanation = 'The returned states do not support a definite conclusion.'
            if ($errors.Count -gt 0 -or $detection -eq 'scriptError' -or $remediation -eq 'scriptError') {
                $state = 'ScriptError'; $explanation = 'The returned execution contains a script error. Review the separate detection and remediation errors.'
            }
            elseif ($remediation -eq 'remediationFailed') {
                $state = 'RemediationFailed'; $explanation = 'Intune reported remediation failure; this does not identify its cause.'
            }
            elseif ($remediation -eq 'success') {
                $state = 'RemediationReportedSuccess'; $explanation = 'The remediation reported success. This alone does not prove the underlying problem is resolved.'
            }
            elseif ($detection -eq 'fail') {
                $state = 'DetectedWithoutSuccessfulRemediation'; $explanation = 'Detection reported an issue and no successful remediation was returned.'
            }
            elseif ($detection -eq 'success') {
                $state = 'DetectionReportedClear'; $explanation = 'The detection script reported success for this execution; this is limited to the checks implemented by that script.'
            }
            elseif ($detection -in @('pending', 'notApplicable')) {
                $state = if ($detection -eq 'pending') { 'Pending' } else { 'NotApplicable' }
                $explanation = 'The returned state is not evidence that an issue was fixed.'
            }
            $observedState = $state
            if (-not $validTime -or $age -gt $StaleAfterDays -or -not $collectionAvailable) {
                $state = if ($validTime -and $age -gt $StaleAfterDays) { 'StaleReporting' } else { 'NotEvaluated' }
                $explanation = "Latest recorded assessment: $observedState. Its age or collection coverage prevents a current conclusion."
            }
            $previous = @($PreviousOutcome | Where-Object { $_.WorkloadId -eq $packageId -and (Get-IntuneAccessProperty $_ 'DeviceId' '') -eq $deviceId })
            $history = 'NoBaseline'
            $prior = $null
            if ($deviceId -and $previous.Count -eq 1) {
                $prior = $previous[0]
                $priorTime = [DateTimeOffset]::MinValue
                $priorValid = [DateTimeOffset]::TryParse([string] (Get-IntuneAccessProperty $prior 'LastStateUpdateDateTime'), [ref] $priorTime)
                $history = 'NotEvaluated'
                if ($validTime -and $priorValid -and $parsed -eq $priorTime) { $history = 'SameExecution' }
                elseif ($validTime -and $priorValid -and $parsed -gt $priorTime -and $state -notin @('StaleReporting', 'NotEvaluated')) {
                    $oldDetection = [string] (Get-IntuneAccessProperty $prior 'DetectionState' '')
                    $oldRemediation = [string] (Get-IntuneAccessProperty $prior 'RemediationState' '')
                    $priorErrors = @('PreRemediationDetectionScriptError', 'RemediationScriptError', 'PostRemediationDetectionScriptError' | Where-Object { -not [string]::IsNullOrWhiteSpace([string] (Get-IntuneAccessProperty $prior $_ '')) })
                    $history = 'NewExecutionObserved'
                    if ($state -eq 'ScriptError' -and ($priorErrors.Count -gt 0 -or $oldDetection -eq 'scriptError' -or $oldRemediation -eq 'scriptError')) { $history = 'PersistentScriptError' }
                    elseif ($detection -eq 'fail' -and $oldDetection -eq 'success') { $history = 'IssueReturnedAfterClearDetection' }
                    elseif ($detection -eq 'fail' -and $oldDetection -eq 'fail') { $history = 'RepeatedDetection' }
                    elseif ($detection -ne $oldDetection -or $remediation -ne $oldRemediation) { $history = 'ReportedStatesChanged' }
                }
            }
            elseif ($previous.Count -gt 1) { $history = 'AmbiguousBaseline' }
            [PSCustomObject] @{
                Id = "REMEDIATION/$packageId/$deviceId/$([string] (Get-IntuneAccessProperty $record 'Id' ''))"
                WorkloadId = $packageId; WorkloadName = [string] $package.Name; DeviceId = $deviceId
                DeviceName = [string] (Get-IntuneAccessProperty $record 'DeviceName' '')
                FindingState = $state; ObservedState = $observedState; DetectionState = $detection; RemediationState = $remediation
                HistoryState = $history; PreviousObservation = $prior; EvidenceTimestamp = $timestamp; EvidenceAgeDays = $age
                Evidence = $record; CollectionAvailable = $collectionAvailable; Explanation = $explanation
                ResolutionState = 'NotConfirmed'; CollectedAt = $AsOf
            }
        }
    }
}
