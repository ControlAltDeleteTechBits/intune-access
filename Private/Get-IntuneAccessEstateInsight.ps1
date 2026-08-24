function Get-IntuneAccessEstateInsight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $DeviceIntelligence,
        [AllowNull()] [object] $ApplicationEvidence,
        [AllowNull()] [object] $UpdateComplianceEvidence,
        [AllowNull()] [object] $AutopilotEvidence,
        [AllowEmptyCollection()] [object[]] $DeploymentOutcome = @(),
        [AllowNull()] [object] $SnapshotComparison,
        [string] $PseudonymKey = 'IntuneAccess-share-safe'
    )

    $ranked = [System.Collections.Generic.List[object]]::new()
    $severityScore = @{ Critical = 100; High = 75; Medium = 50; Low = 25; Information = 10 }
    foreach ($finding in @($DeviceIntelligence.Findings)) {
        $score = $severityScore[[string] $finding.Severity]
        if ($null -eq $score) { $score = 10 }
        $ranked.Add([PSCustomObject] @{
            PSTypeName = 'IntuneAccess.EstateFinding'; FindingId = [string] $finding.FindingId; PriorityScore = $score
            Severity = [string] $finding.Severity; Category = [string] $finding.Category; Title = [string] $finding.Title
            DeviceId = [string] $finding.DeviceId; DeviceName = [string] $finding.DeviceName; SourceType = 'DeviceHygiene'; SourceId = [string] $finding.RuleId
            EvidenceTimestamp = $finding.EvidenceTimestamp; Explanation = [string] $finding.Explanation; ReviewRecommendation = [string] $finding.ReviewRecommendation
            Evidence = $finding.Evidence; CauseState = 'NotAsserted'
        })
    }
    foreach ($outcome in @($DeploymentOutcome | Where-Object Category -EQ 'Error')) {
        $ranked.Add([PSCustomObject] @{
            PSTypeName = 'IntuneAccess.EstateFinding'; FindingId = "OUTCOME/$([string] $outcome.WorkloadId)/$([string] $outcome.DeviceId)"; PriorityScore = 70
            Severity = 'High'; Category = 'Deployment'; Title = "Reported deployment error: $([string] $outcome.WorkloadName)"
            DeviceId = [string] $outcome.DeviceId; DeviceName = [string] $outcome.DeviceName; SourceType = 'DeploymentOutcome'; SourceId = [string] $outcome.WorkloadId
            EvidenceTimestamp = Get-IntuneAccessProperty $outcome 'LastReportedDateTime'; Explanation = [string] (Get-IntuneAccessProperty $outcome 'StateDetail' 'Microsoft Graph returned an error-category deployment result.'); ReviewRecommendation = 'Review the workload result and device-side logs before assigning root cause.'
            Evidence = $outcome; CauseState = 'NotAsserted'
        })
    }
    if ($null -ne $ApplicationEvidence) {
        foreach ($application in @($ApplicationEvidence.DeviceApplicationEvidence | Where-Object { 'required' -in @($_.ConfiguredIntents) -and $_.DetectionState -eq 'NotDetectedByExactName' -and @($_.InstallResults | Where-Object Category -EQ 'Success').Count -eq 0 })) {
            $ranked.Add([PSCustomObject] @{
                PSTypeName = 'IntuneAccess.EstateFinding'; FindingId = "APPLICATION/$([string] $application.ApplicationId)/$([string] $application.DeviceId)"; PriorityScore = 50
                Severity = 'Medium'; Category = 'Application'; Title = "Required application has no matching detected-software evidence: $([string] $application.ApplicationName)"
                DeviceId = [string] $application.DeviceId; DeviceName = [string] $application.DeviceName; SourceType = 'ApplicationEvidence'; SourceId = [string] $application.ApplicationId
                EvidenceTimestamp = $application.InstallResults | ForEach-Object { Get-IntuneAccessProperty $_ 'LastReportedDateTime' } | Sort-Object -Descending | Select-Object -First 1
                Explanation = 'A required intent was configured, no successful returned result was present and no exact-name detected-software relationship was observed.'
                ReviewRecommendation = 'Review the calculated assignment path, application result and client-side detection evidence.'; Evidence = $application; CauseState = 'NotAsserted'
            })
        }
    }
    if ($null -ne $UpdateComplianceEvidence) {
        foreach ($item in @($UpdateComplianceEvidence.Investigations | Where-Object InvestigationState -In @('ReturnedFailure','StaleReporting','OutsideObservedTargetVersion','ReportedNonCompliant'))) {
            $score = if ($item.InvestigationState -eq 'ReturnedFailure') { 72 } elseif ($item.InvestigationState -eq 'ReportedNonCompliant') { 65 } else { 45 }
            $ranked.Add([PSCustomObject] @{
                PSTypeName = 'IntuneAccess.EstateFinding'; FindingId = "UPDATE/$([string] $item.WorkloadId)/$([string] $item.DeviceId)"; PriorityScore = $score
                Severity = if ($score -ge 65) { 'High' } else { 'Medium' }; Category = 'UpdateCompliance'; Title = "$([string] $item.InvestigationState): $([string] $item.WorkloadName)"
                DeviceId = [string] $item.DeviceId; DeviceName = [string] $item.DeviceName; SourceType = 'UpdateCompliance'; SourceId = [string] $item.WorkloadId
                EvidenceTimestamp = $item.EvidenceTimestamp; Explanation = [string] $item.Explanation; ReviewRecommendation = 'Review targeting, evidence age and the returned device result.'
                Evidence = $item; CauseState = 'NotAsserted'
            })
        }
    }
    if ($null -ne $AutopilotEvidence) {
        foreach ($timeline in @($AutopilotEvidence.Timelines | Where-Object { @($_.FailureDetails).Count -gt 0 })) {
            $ranked.Add([PSCustomObject] @{
                PSTypeName = 'IntuneAccess.EstateFinding'; FindingId = "AUTOPILOT/$([string] $timeline.AutopilotIdentityId)"; PriorityScore = 72
                Severity = 'High'; Category = 'Enrolment'; Title = 'Autopilot event returned failure evidence'; DeviceId = [string] $timeline.ManagedDeviceId; DeviceName = [string] $timeline.DeviceName
                SourceType = 'AutopilotTimeline'; SourceId = [string] $timeline.AutopilotIdentityId; EvidenceTimestamp = $timeline.LastContactedDateTime
                Explanation = @($timeline.FailureDetails) -join '; '; ReviewRecommendation = 'Review the stage evidence and relevant device-side enrolment logs.'; Evidence = $timeline; CauseState = 'NotAsserted'
            })
        }
    }

    $recurringFailures = @($ranked | Where-Object { $_.Category -in @('Deployment','UpdateCompliance','Enrolment') } | Group-Object SourceType, SourceId, Title | Where-Object Count -GT 1 | ForEach-Object {
        [PSCustomObject] @{
            PSTypeName = 'IntuneAccess.RecurringFailureGroup'; Signature = Get-IntuneAccessSnapshotHash -Value $_.Name; Title = [string] $_.Group[0].Title
            SourceType = [string] $_.Group[0].SourceType; SourceId = [string] $_.Group[0].SourceId; DeviceCount = @($_.Group.DeviceId | Select-Object -Unique).Count
            DeviceIds = @($_.Group.DeviceId | Select-Object -Unique); FindingIds = @($_.Group.FindingId); CauseState = 'NotAsserted'
            Explanation = 'These devices share returned evidence. The grouping identifies a pattern and does not prove a common root cause.'
        }
    })

    $inventory = @($DeviceIntelligence.Inventory)
    $cohorts = [System.Collections.Generic.List[object]]::new()
    foreach ($dimension in @('Model','OsVersion','EnrollmentType','ManagementAgent')) {
        foreach ($group in @($inventory | Group-Object $dimension | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) })) {
            $deviceIds = @($group.Group.Id)
            $cohorts.Add([PSCustomObject] @{ PSTypeName = 'IntuneAccess.DeviceCohort'; Dimension = $dimension; Value = $group.Name; DeviceCount = $group.Count; DeviceIds = $deviceIds; FindingCount = @($ranked | Where-Object DeviceId -In $deviceIds).Count })
        }
    }

    $crossDevice = @($ranked | Where-Object { -not [string]::IsNullOrWhiteSpace($_.SourceId) } | Group-Object SourceType, SourceId | ForEach-Object {
        [PSCustomObject] @{
            PSTypeName = 'IntuneAccess.CrossDeviceInvestigation'; SourceType = [string] $_.Group[0].SourceType; SourceId = [string] $_.Group[0].SourceId
            DeviceCount = @($_.Group.DeviceId | Where-Object { $_ } | Select-Object -Unique).Count; DeviceIds = @($_.Group.DeviceId | Where-Object { $_ } | Select-Object -Unique)
            FindingIds = @($_.Group.FindingId); HighestPriority = ($_.Group | Measure-Object PriorityScore -Maximum).Maximum
        }
    } | Sort-Object HighestPriority -Descending)

    $trend = if ($null -eq $SnapshotComparison) { [PSCustomObject] @{ State = 'NoBaseline'; Changes = @(); Explanation = 'No local baseline snapshot was supplied.' } } else { [PSCustomObject] @{ State = 'Compared'; Changes = @($SnapshotComparison.Changes); Explanation = 'Changes were calculated locally from the supplied snapshots.' } }
    $shareData = [PSCustomObject] @{ Findings = @($ranked | Sort-Object PriorityScore -Descending); Cohorts = $cohorts.ToArray(); RecurringFailures = $recurringFailures; CrossDeviceInvestigations = $crossDevice }
    $shareSafe = Copy-IntuneAccessSnapshotValue -Value $shareData -RedactionKey (Get-IntuneAccessSnapshotHash -Value $PseudonymKey)

    [PSCustomObject] @{
        PSTypeName              = 'IntuneAccess.DeviceEstateInsight'
        PrioritisedFindings     = @($ranked | Sort-Object @{ Expression = 'PriorityScore'; Descending = $true }, DeviceName)
        RecurringFailures       = $recurringFailures
        Cohorts                 = $cohorts.ToArray()
        CrossDeviceInvestigations = $crossDevice
        HistoricalTrend        = $trend
        ShareSafeBundle        = $shareSafe
        EvidenceBoundary       = 'All findings are read-only review prompts traced to collected evidence. Correlation and grouping do not assert intent or root cause.'
        ReadOnly               = $true
        GeneratedAt            = [DateTimeOffset]::Now
        ToolVersion            = $script:IntuneAccessVersion
    }
}
