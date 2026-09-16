Import-Module (Join-Path $PSScriptRoot '../../IntuneAccess.psd1') -Force
Describe 'Before and after finding evidence' {
    InModuleScope IntuneAccess {
        BeforeEach {
            $script:beforeAt = [DateTimeOffset]::Parse('2026-09-14T12:00:00Z')
            $script:afterAt = [DateTimeOffset]::Parse('2026-09-15T12:00:00Z')
            $script:finding = [pscustomobject] @{ FindingId = 'stale/d'; SourceId = 'DEV-CHECKIN-STALE'; SourceType = 'DeviceHygiene'; DeviceId = 'd'; DeviceName = 'PC'; Title = 'Stale'; PriorityScore = 75; EvidenceTimestamp = '2026-08-01T00:00:00Z'; Evidence = @{ LastSyncDateTime = '2026-08-01T00:00:00Z' } }
            $script:before = [pscustomobject] @{ EstateFindings = @($finding) }
            $script:after = [pscustomobject] @{ ManagedDevices = @([pscustomobject] @{ Id = 'd'; LastSyncDateTime = '2026-09-15T10:00:00Z' }) }
        }
        It 'requires fresh positive evidence to clear a stale check-in observation' {
            $result = @(Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt)
            $result[0].VerificationState | Should -Be 'ObservationCleared'
            $result[0].CauseState | Should -Be 'NotAsserted'
        }
        It 'does not treat a missing device or old check-in as resolved' {
            $after.ManagedDevices[0].LastSyncDateTime = '2026-08-01T00:00:00Z'
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'NotEvaluated'
            $after.ManagedDevices = @()
            $result = Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt
            $result.VerificationState | Should -Be 'NotEvaluated'
            $result.Explanation | Should -Match 'Disappearance is not resolution'
        }
        It 'retains an observation still present without claiming a new occurrence' {
            $after | Add-Member -NotePropertyName EstateFindings -NotePropertyValue @($finding)
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'Persisted'
        }
        It 'requires available workload coverage as well as a newer success result' {
            $finding.SourceType = 'DeploymentOutcome'; $finding.SourceId = 'app'
            $after | Add-Member -NotePropertyName DeploymentOutcomes -NotePropertyValue @([pscustomobject] @{ WorkloadId = 'app'; DeviceId = 'd'; Category = 'Success'; DeviceMatchState = 'MatchedById'; LastReportedDateTime = '2026-09-15T10:00:00Z' })
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'NotEvaluated'
            $after | Add-Member -NotePropertyName OutcomeCollectionStatus -NotePropertyValue @([pscustomobject] @{ WorkloadId = 'app'; State = 'Available' })
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'ObservationCleared'
            $after.DeploymentOutcomes[0].DeviceMatchState = 'MatchedByName'
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'NotEvaluated'
        }
        It 'requires complete fresh policy evidence and preserves missing values as unknown' {
            $conflict = [pscustomobject] @{ Id = 'c'; SettingDefinitionId = 'setting'; FirstPolicyId = 'p1'; FirstPolicyName = 'First'; FirstValueJson = 'true'; SecondPolicyId = 'p2'; SecondPolicyName = 'Second'; SecondValueJson = 'false'; FindingState = 'PotentialConflict'; Reason = 'Observed overlap' }
            $before = [pscustomobject] @{ PolicyConflictFindings = @($conflict) }
            $after = [pscustomobject] @{ CollectedAt = '2026-09-15T10:00:00Z'; PolicySettings = @([pscustomobject] @{ WorkloadId = 'p1'; SettingDefinitionId = 'setting'; ValueJson = 'true' }, [pscustomobject] @{ WorkloadId = 'p2'; SettingDefinitionId = 'setting'; ValueJson = 'true' }); PolicyConflictCollectionStatus = @([pscustomobject] @{ WorkloadId = 'p1'; State = 'Available' }, [pscustomobject] @{ WorkloadId = 'p2'; State = 'Available' }) }
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'ObservationCleared'
            $after.PolicyConflictCollectionStatus[1].State = 'Unavailable'
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'NotEvaluated'
            $after.PolicyConflictCollectionStatus[1].State = 'Available'; $after.CollectedAt = '2026-09-01T00:00:00Z'
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'NotEvaluated'
        }
        It 'does not preserve a stale finding as current when its device disappeared' {
            $after.ManagedDevices = @()
            $after | Add-Member -NotePropertyName EstateFindings -NotePropertyValue @($finding)
            (Compare-IntuneAccessFindingEvidence -Before $before -After $after -BeforeAt $beforeAt -AfterAt $afterAt).VerificationState | Should -Be 'NotEvaluated'
        }
        It 'pseudonymises free-text script outputs and errors' {
            $value = [pscustomobject] @{ PreRemediationDetectionScriptOutput = 'person@example.test'; RemediationScriptError = 'C:\Users\Person'; StateDetail = 'person@example.test'; DetectionState = 'fail' }
            $safe = Copy-IntuneAccessSnapshotValue -Value $value -RedactionKey 'test'
            $safe.PreRemediationDetectionScriptOutput | Should -Match '^redacted-'
            $safe.RemediationScriptError | Should -Match '^redacted-'
            $safe.StateDetail | Should -Match '^redacted-'
            $safe.DetectionState | Should -Be 'fail'
        }
    }
}
