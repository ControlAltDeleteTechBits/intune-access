Import-Module (Join-Path $PSScriptRoot '../../IntuneAccess.psd1') -Force
Describe 'Remediation evidence boundaries' {
    InModuleScope IntuneAccess {
        BeforeAll {
            $script:package = [pscustomobject] @{ Id = 'package'; Name = 'Test'; WorkloadType = 'Scripts'; SourceCollection = 'Remediations' }
            $script:coverage = [pscustomobject] @{ WorkloadId = 'package'; State = 'Available' }
            $script:asOf = [DateTimeOffset]::Parse('2026-09-15T12:00:00Z')
        }
        BeforeEach {
            $script:record = [pscustomobject] @{ Id = 'run'; WorkloadId = 'package'; DeviceId = 'device'; DeviceName = 'PC'; DetectionState = 'fail'; RemediationState = 'success'; LastStateUpdateDateTime = '2026-09-15T10:00:00Z' }
        }
        It 'retains separate states and prefers execution time over sync time' {
            $raw = [pscustomobject] @{ id = 'run'; detectionState = 'fail'; remediationState = 'success'; lastStateUpdateDateTime = '2026-09-14T10:00:00Z'; lastSyncDateTime = '2026-09-15T10:00:00Z'; remediationScriptError = 'message'; managedDevice = @{ id = 'gone'; deviceName = 'Gone' } }
            $result = ConvertTo-IntuneAccessDeploymentOutcome -InputObject $raw -Workload $package -ApiVersion beta -ManagedDevice @([pscustomobject] @{ Id = 'other'; DeviceName = 'Other' })
            $result.DetectionState | Should -Be 'fail'
            $result.RemediationState | Should -Be 'success'
            $result.LastReportedDateTime | Should -Be '2026-09-14T10:00:00Z'
            $result.RemediationScriptError | Should -Be 'message'
            $result.DeviceId | Should -Be 'gone'
        }
        It 'does not equate reported remediation success with resolution' {
            $result = Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf
            $result.FindingState | Should -Be 'RemediationReportedSuccess'
            $result.ResolutionState | Should -Be 'NotConfirmed'
        }
        It 'does not count repeated snapshots of one execution as recurrence' {
            $result = Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -PreviousOutcome @($record) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf
            $result.HistoryState | Should -Be 'SameExecution'
        }
        It 'identifies repeated detection in distinct executions' {
            $prior = $record.PSObject.Copy(); $prior.LastStateUpdateDateTime = '2026-09-14T10:00:00Z'
            $result = Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -PreviousOutcome @($prior) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf
            $result.HistoryState | Should -Be 'RepeatedDetection'
        }
        It 'identifies return after a clear detection without claiming cause' {
            $prior = $record.PSObject.Copy(); $prior.LastStateUpdateDateTime = '2026-09-14T10:00:00Z'; $prior.DetectionState = 'success'
            $result = Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -PreviousOutcome @($prior) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf
            $result.HistoryState | Should -Be 'IssueReturnedAfterClearDetection'
        }
        It 'retains stale and future dates as uncertain evidence' {
            $record.LastStateUpdateDateTime = '2026-08-01T10:00:00Z'
            (Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf).FindingState | Should -Be 'StaleReporting'
            $record.LastStateUpdateDateTime = '2027-08-01T10:00:00Z'
            (Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf).FindingState | Should -Be 'NotEvaluated'
        }
        It 'does not turn unavailable collection or empty results into success' {
            (Get-IntuneAccessRemediationEffectiveness -Workload @($package) -AsOf $asOf).FindingState | Should -Be 'NotEvaluated'
            (Get-IntuneAccessRemediationEffectiveness -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf).FindingState | Should -Be 'NoReportedResults'
            (Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -Workload @($package) -AsOf $asOf).FindingState | Should -Be 'NotEvaluated'
        }
        It 'recognises persistent script errors' {
            $record.RemediationState = 'scriptError'
            $prior = $record.PSObject.Copy(); $prior.LastStateUpdateDateTime = '2026-09-14T10:00:00Z'
            $result = Get-IntuneAccessRemediationEffectiveness -Outcome @($record) -PreviousOutcome @($prior) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf
            $result.FindingState | Should -Be 'ScriptError'
            $result.HistoryState | Should -Be 'PersistentScriptError'
        }
        It 'retains a known device whose current remediation result disappears' {
            $results = @(Get-IntuneAccessRemediationEffectiveness -PreviousOutcome @($record) -Workload @($package) -CollectionStatus @($coverage) -AsOf $asOf)
            $missing = @($results | Where-Object DeviceId -EQ 'device')
            $missing.Count | Should -Be 1
            $missing[0].FindingState | Should -Be 'MissingReportedResult'
            $missing[0].ResolutionState | Should -Be 'NotConfirmed'
            @($missing[0].PreviousObservation).Count | Should -Be 1
        }
    }
}
