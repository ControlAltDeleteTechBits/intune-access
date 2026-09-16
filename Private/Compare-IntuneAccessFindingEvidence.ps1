function Compare-IntuneAccessFindingEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Before,
        [Parameter(Mandatory)] [object] $After,
        [Parameter(Mandatory)] [DateTimeOffset] $BeforeAt,
        [Parameter(Mandatory)] [DateTimeOffset] $AfterAt
    )
    $prior = Get-IntuneAccessActionCentre -Collection $Before -AsOf $BeforeAt
    $current = Get-IntuneAccessActionCentre -Collection $After -PreviousOutcome @(Get-IntuneAccessProperty $Before 'DeploymentOutcomes' @()) -AsOf $AfterAt
    foreach ($finding in $prior.Findings) {
        $state = 'NotEvaluated'
        $reason = 'No fresh, positive evidence establishes whether this observation cleared.'
        $afterEvidence = $null
        $matchingFindings = @($current.Findings | Where-Object FindingId -EQ $finding.FindingId)
        $currentDevices = @(Get-IntuneAccessProperty $After 'ManagedDevices' @() | Where-Object Id -EQ $finding.DeviceId)
        if ($finding.DeviceId -and $currentDevices.Count -ne 1) {
            $reason = 'The exact device is missing or ambiguous in the later collection. Disappearance is not resolution.'
        }
        elseif ($matchingFindings.Count -gt 0) {
            $state = 'Persisted'; $reason = 'The same finding is present in the later collection. This does not imply a new execution or establish cause.'
            $afterEvidence = $matchingFindings[0].Evidence
        }
        else {
            $devices = @(Get-IntuneAccessProperty $After 'ManagedDevices' @() | Where-Object Id -EQ $finding.DeviceId)
            $inventory = @(Get-IntuneAccessProperty $After 'DeviceInventory' @() | Where-Object Id -EQ $finding.DeviceId)
            $device = if ($devices.Count -eq 1) { $devices[0] } else { $null }
            $lastSync = [DateTimeOffset]::MinValue
            $freshDevice = $null -ne $device -and [DateTimeOffset]::TryParse([string] (Get-IntuneAccessProperty $device 'LastSyncDateTime'), [ref] $lastSync) -and $lastSync -gt $BeforeAt -and $lastSync -le $AfterAt -and ($AfterAt - $lastSync).TotalDays -le 8
            $positive = $false
            if ($finding.SourceType -eq 'DeviceHygiene' -and $freshDevice) {
                $afterEvidence = $device
                switch ($finding.SourceId) {
                    'DEV-CHECKIN-STALE' { $positive = $true }
                    'DEV-CHECKIN-MISSING' { $positive = $true }
                    'DEV-ENROLMENT-NO-HEALTHY-CHECKIN' {
                        $enrolled = [DateTimeOffset]::MinValue
                        $positive = [DateTimeOffset]::TryParse([string] (Get-IntuneAccessProperty $device 'EnrolledDateTime'), [ref] $enrolled) -and $lastSync -gt $enrolled
                    }
                    'DEV-PRIMARY-USER-MISSING' { $positive = -not [string]::IsNullOrWhiteSpace([string] (Get-IntuneAccessProperty $device 'UserId' '')) }
                    'DEV-COMPLIANCE-UNKNOWN' {
                        # Clear the unknown finding without declaring the device compliant.
                        $positive = (Get-IntuneAccessProperty $device 'ComplianceState' '') -in @('compliant', 'noncompliant')
                    }
                    'DEV-ENTRA-CORRELATION' { $positive = $inventory.Count -eq 1 -and (Get-IntuneAccessProperty $inventory[0] 'EntraCorrelationState' '') -eq 'Matched' }
                    'DEV-OS-VERSION-MISMATCH' {
                        if ($inventory.Count -eq 1) {
                            $os = [string] (Get-IntuneAccessProperty $inventory[0] 'OsVersion' '')
                            $positive = $os -ne '' -and $os -eq (Get-IntuneAccessProperty $inventory[0] 'EntraOperatingSystemVersion' '')
                        }
                    }
                }
            }
            elseif ($finding.SourceType -in @('DeploymentOutcome', 'ApplicationEvidence', 'UpdateCompliance') -and $null -ne $device) {
                $coverage = @(Get-IntuneAccessProperty $After 'OutcomeCollectionStatus' @() | Where-Object { $_.WorkloadId -eq $finding.SourceId -and $_.State -eq 'Available' })
                $results = @(Get-IntuneAccessProperty $After 'DeploymentOutcomes' @() | Where-Object { $_.WorkloadId -eq $finding.SourceId -and $_.DeviceId -eq $finding.DeviceId })
                $freshResults = @($results | Where-Object {
                    $time = [DateTimeOffset]::MinValue
                    [DateTimeOffset]::TryParse([string] (Get-IntuneAccessProperty $_ 'LastReportedDateTime'), [ref] $time) -and $time -gt $BeforeAt -and $time -le $AfterAt -and ($AfterAt - $time).TotalDays -le 8
                })
                $positive = $coverage.Count -eq 1 -and $freshResults.Count -gt 0 -and @($freshResults | Where-Object { $_.Category -ne 'Success' -or (Get-IntuneAccessProperty $_ 'DeviceMatchState' '') -ne 'MatchedById' }).Count -eq 0
                $afterEvidence = $freshResults
            }
            elseif ($finding.SourceType -eq 'PolicyConflict') {
                $conflict = $finding.Evidence
                $settings = @(Get-IntuneAccessProperty $After 'PolicySettings' @() | Where-Object SettingDefinitionId -EQ $conflict.SettingDefinitionId)
                $first = @($settings | Where-Object WorkloadId -EQ $conflict.FirstPolicyId)
                $second = @($settings | Where-Object WorkloadId -EQ $conflict.SecondPolicyId)
                $statuses = @(Get-IntuneAccessProperty $After 'PolicyConflictCollectionStatus' @())
                $available = @($statuses | Where-Object { $_.WorkloadId -in @($conflict.FirstPolicyId, $conflict.SecondPolicyId) -and $_.State -eq 'Available' } | Select-Object -ExpandProperty WorkloadId -Unique)
                $collected = [DateTimeOffset]::MinValue
                $freshCollection = [DateTimeOffset]::TryParse([string] (Get-IntuneAccessProperty $After 'CollectedAt'), [ref] $collected) -and $collected -gt $BeforeAt -and $collected -le $AfterAt -and ($AfterAt - $collected).TotalDays -le 8
                $positive = $freshCollection -and $available.Count -eq 2 -and $first.Count -eq 1 -and $second.Count -eq 1 -and [string] $first[0].ValueJson -ceq [string] $second[0].ValueJson
                $afterEvidence = $settings
            }
            elseif ($finding.SourceType -eq 'RemediationEffectiveness' -and $null -ne $device) {
                $results = @($current.RemediationEffectiveness | Where-Object { $_.WorkloadId -eq $finding.SourceId -and $_.DeviceId -eq $finding.DeviceId })
                if ($results.Count -eq 1) {
                    $time = [DateTimeOffset]::MinValue
                    $positive = $results[0].FindingState -eq 'DetectionReportedClear' -and (Get-IntuneAccessProperty $results[0].Evidence 'DeviceMatchState' '') -eq 'MatchedById' -and [DateTimeOffset]::TryParse([string] $results[0].EvidenceTimestamp, [ref] $time) -and $time -gt $BeforeAt
                    $afterEvidence = $results[0]
                }
            }
            if ($positive) {
                $state = 'ObservationCleared'
                $reason = 'Later positive evidence clears this specific observation. This does not prove the external change caused it or that all device problems are resolved.'
            }
            elseif ($finding.DeviceId -and $null -eq $device) {
                $reason = 'The exact device is missing or ambiguous in the later collection. Disappearance is not resolution.'
            }
        }
        [pscustomobject] @{
            FindingId = $finding.FindingId; Title = $finding.Title; DeviceId = $finding.DeviceId; DeviceName = $finding.DeviceName
            VerificationState = $state; Explanation = $reason; BeforeCollectedAt = $BeforeAt; AfterCollectedAt = $AfterAt
            BeforeEvidenceTimestamp = $finding.EvidenceTimestamp; BeforeEvidence = $finding.Evidence; AfterEvidence = $afterEvidence
            CauseState = 'NotAsserted'
        }
    }
}
