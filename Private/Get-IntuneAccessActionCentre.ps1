function Get-IntuneAccessActionCentre {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Collection,
        [AllowEmptyCollection()] [object[]] $PreviousOutcome = @(),
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow
    )
    $findings = [Collections.Generic.List[object]]::new()
    foreach ($existing in @(Get-IntuneAccessProperty $Collection 'EstateFindings' @())) {
        $findings.Add($existing.PSObject.Copy())
    }
    foreach ($conflict in @(Get-IntuneAccessProperty $Collection 'PolicyConflictFindings' @() | Where-Object FindingState -EQ 'PotentialConflict')) {
        $findings.Add([pscustomobject] @{
            FindingId = "POLICY/$($conflict.Id)"; Title = "Potential setting conflict: $($conflict.SettingDefinitionId)"; PriorityScore = 60; Severity = 'Medium'
            Category = 'Configuration'; DeviceId = ''; DeviceName = ''; SourceType = 'PolicyConflict'; SourceId = [string] $conflict.Id
            EvidenceTimestamp = Get-IntuneAccessProperty $Collection 'GeneratedAt'; Explanation = [string] $conflict.Reason
            ReviewRecommendation = 'Review both configured values and target overlap before proposing consolidation.'; CauseState = 'NotAsserted'; Evidence = $conflict
        })
    }
    foreach ($assignment in @(Get-IntuneAccessProperty $Collection 'DeviceAssignmentExplanations' @())) {
        $required = @((Get-IntuneAccessProperty $assignment 'AssignmentPaths' @()) | Where-Object { (Get-IntuneAccessProperty $_ 'Intent' '') -eq 'required' -and (Get-IntuneAccessProperty $_ 'PathState' '') -eq 'Included' })
        if ($assignment.WorkloadType -eq 'Applications' -and $assignment.AssignmentState -eq 'Included' -and $assignment.ReportedOutcomeState -eq 'NoReportedEvidence' -and $required.Count -gt 0) {
            $findings.Add([pscustomobject] @{
                FindingId = "MISSING-RESULT/$($assignment.WorkloadId)/$($assignment.DeviceId)"; Title = "Required application has no reported result: $($assignment.WorkloadName)"; PriorityScore = 45; Severity = 'Information'
                Category = 'Application'; DeviceId = [string] $assignment.DeviceId; DeviceName = [string] $assignment.DeviceName; SourceType = 'ApplicationEvidence'; SourceId = [string] $assignment.WorkloadId
                EvidenceTimestamp = Get-IntuneAccessProperty $assignment 'GeneratedAt'; Explanation = 'An included required path was calculated, but no device outcome was returned. This is an evidence gap, not a proven installation failure.'
                ReviewRecommendation = 'Review reporting coverage and client detection evidence.'; CauseState = 'NotAsserted'; Evidence = $assignment
            })
        }
    }
    $effectiveness = @(Get-IntuneAccessRemediationEffectiveness -Outcome @(Get-IntuneAccessProperty $Collection 'DeploymentOutcomes' @()) -PreviousOutcome $PreviousOutcome -Workload @(Get-IntuneAccessProperty $Collection 'WorkloadObjects' @()) -CollectionStatus @(Get-IntuneAccessProperty $Collection 'OutcomeCollectionStatus' @()) -AsOf $AsOf)
    foreach ($item in $effectiveness) {
        if ($item.FindingState -in @('ScriptError', 'RemediationFailed', 'DetectedWithoutSuccessfulRemediation', 'StaleReporting', 'NoReportedResults', 'MissingReportedResult', 'NotEvaluated') -or $item.HistoryState -in @('RepeatedDetection', 'IssueReturnedAfterClearDetection', 'PersistentScriptError')) {
            $findings.Add([pscustomobject] @{
                FindingId = [string] $item.Id; Title = "$($item.WorkloadName): $($item.FindingState)"; PriorityScore = 55; Severity = 'Medium'
                Category = 'Remediation'; DeviceId = [string] $item.DeviceId; DeviceName = [string] $item.DeviceName; SourceType = 'RemediationEffectiveness'; SourceId = [string] $item.WorkloadId
                EvidenceTimestamp = $item.EvidenceTimestamp; Explanation = [string] $item.Explanation
                ReviewRecommendation = 'Review separate script states and distinct execution observations.'; CauseState = 'NotAsserted'; Evidence = $item
            })
        }
    }
    foreach ($finding in $findings) {
        foreach ($name in @('DeviceId', 'DeviceName', 'SourceId', 'SourceType', 'EvidenceTimestamp', 'Evidence')) {
            if ($null -eq $finding.PSObject.Properties[$name]) {
                $finding | Add-Member -NotePropertyName $name -NotePropertyValue $null
            }
        }
        $finding | Add-Member -NotePropertyName ResolutionGuide -NotePropertyValue (Get-IntuneAccessResolutionGuide -Finding $finding) -Force
        $finding | Add-Member -NotePropertyName CollectedAt -NotePropertyValue $AsOf -Force
        $finding | Add-Member -NotePropertyName AffectedObjects -NotePropertyValue @(
            if ($finding.DeviceId) { [pscustomobject] @{ Type = 'Device'; Id = $finding.DeviceId; Name = $finding.DeviceName } }
            if ($finding.SourceType -eq 'PolicyConflict') {
                [pscustomobject] @{ Type = 'Policy'; Id = $finding.Evidence.FirstPolicyId; Name = $finding.Evidence.FirstPolicyName }
                [pscustomobject] @{ Type = 'Policy'; Id = $finding.Evidence.SecondPolicyId; Name = $finding.Evidence.SecondPolicyName }
            }
            elseif ($finding.SourceType -ne 'DeviceHygiene') { [pscustomobject] @{ Type = $finding.SourceType; Id = $finding.SourceId; Name = $finding.Title } }
        ) -Force
    }
    [pscustomobject] @{
        Findings = @($findings | Sort-Object PriorityScore -Descending)
        RemediationEffectiveness = $effectiveness
        ReadOnly = $true; GeneratedAt = $AsOf
    }
}
