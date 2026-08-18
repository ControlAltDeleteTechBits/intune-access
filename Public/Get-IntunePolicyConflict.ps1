function Get-IntunePolicyConflict {
    <#
    .SYNOPSIS
    Finds overlapping Intune policy settings and potential conflicts.
    .DESCRIPTION
    Compares observed setting values across supported Settings Catalog, endpoint
    security intent and legacy device configuration profiles. A potential conflict
    is reported only when values differ and exact target evidence confirms overlap.
    The command does not claim the final setting enforced on a device.
    .PARAMETER Workload
    Optional workload objects from Get-IntuneAssignmentImpact.
    .PARAMETER Assignment
    Optional workload assignments from Get-IntuneAssignmentImpact.
    .EXAMPLE
    Get-IntunePolicyConflict
    .EXAMPLE
    $impact = Get-IntuneAssignmentImpact
    Get-IntunePolicyConflict -Workload $impact.Workloads -Assignment $impact.Assignments
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()] [object[]] $Workload,
        [AllowEmptyCollection()] [object[]] $Assignment
    )

    if (-not $PSBoundParameters.ContainsKey('Workload')) {
        $inventory = Get-IntuneAccessWorkloadAssignments
        $Workload = @($inventory.Workloads)
        $Assignment = @($inventory.Assignments)
    }
    elseif (-not $PSBoundParameters.ContainsKey('Assignment')) {
        $Assignment = @($Workload | ForEach-Object { Get-IntuneAccessProperty $_ 'Assignments' @() })
    }

    $settingInventory = Get-IntuneAccessPolicySettings -Workload @($Workload)
    $findings = [Collections.Generic.List[object]]::new()
    foreach ($definitionGroup in @($settingInventory.Settings | Group-Object SettingDefinitionId)) {
        $policySettings = @($definitionGroup.Group | Sort-Object WorkloadId -Unique)
        for ($firstIndex = 0; $firstIndex -lt $policySettings.Count; $firstIndex++) {
            for ($secondIndex = $firstIndex + 1; $secondIndex -lt $policySettings.Count; $secondIndex++) {
                $first = $policySettings[$firstIndex]
                $second = $policySettings[$secondIndex]
                if ($first.WorkloadId -eq $second.WorkloadId) { continue }
                $overlap = Get-IntuneAccessPolicyTargetOverlap `
                    -FirstAssignment @($Assignment | Where-Object WorkloadId -EQ $first.WorkloadId) `
                    -SecondAssignment @($Assignment | Where-Object WorkloadId -EQ $second.WorkloadId)
                $valuesDiffer = [string] $first.ValueJson -cne [string] $second.ValueJson
                $findingState = if (-not $valuesDiffer) { 'SameValue' } elseif ($overlap.State -eq 'ConfirmedOverlap') { 'PotentialConflict' } else { 'NotEvaluated' }
                $findings.Add([PSCustomObject] @{
                    PSTypeName          = 'IntuneAccess.PolicyConflictFinding'
                    Id                  = "$($definitionGroup.Name)::$($first.WorkloadId)::$($second.WorkloadId)"
                    SettingDefinitionId = [string] $definitionGroup.Name
                    FirstPolicyId       = [string] $first.WorkloadId
                    FirstPolicyName     = [string] $first.WorkloadName
                    FirstValueJson      = [string] $first.ValueJson
                    SecondPolicyId      = [string] $second.WorkloadId
                    SecondPolicyName    = [string] $second.WorkloadName
                    SecondValueJson     = [string] $second.ValueJson
                    ValuesDiffer        = $valuesDiffer
                    TargetOverlapState  = [string] $overlap.State
                    TargetEvidence      = @($overlap.Evidence)
                    FindingState        = $findingState
                    Reason              = [string] $overlap.Reason
                    EvidenceState       = 'CalculatedFromObservedSettingsAndAssignments'
                })
            }
        }
    }

    $result = [PSCustomObject] @{
        PSTypeName       = 'IntuneAccess.PolicyConflictAnalysis'
        PolicySettings   = @($settingInventory.Settings)
        Findings         = $findings.ToArray()
        PotentialConflicts = @($findings | Where-Object FindingState -EQ 'PotentialConflict')
        PotentialConflictCount = @($findings | Where-Object FindingState -EQ 'PotentialConflict').Count
        UnevaluatedCount = @($findings | Where-Object FindingState -EQ 'NotEvaluated').Count
        CollectionStatus = @($settingInventory.CollectionStatus)
        Warnings         = @($settingInventory.Warnings)
        ReadOnly         = $true
        GeneratedAt      = [DateTimeOffset]::Now
        ToolVersion      = $script:IntuneAccessVersion
    }
    $result.PSObject.TypeNames.Insert(0, 'IntuneAccess.PolicyConflictAnalysis')
    $result
}
