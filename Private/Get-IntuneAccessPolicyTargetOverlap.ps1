function Get-IntuneAccessPolicyTargetOverlap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $FirstAssignment,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $SecondAssignment
    )

    $firstIncluded = @($FirstAssignment | Where-Object { $_.EvidenceState -eq 'ConfirmedAssignment' -and $_.TargetType -ne 'Excluded group' })
    $secondIncluded = @($SecondAssignment | Where-Object { $_.EvidenceState -eq 'ConfirmedAssignment' -and $_.TargetType -ne 'Excluded group' })
    if ($firstIncluded.Count -eq 0 -or $secondIncluded.Count -eq 0) {
        return [PSCustomObject] @{ State = 'NotAssigned'; Evidence = @(); Reason = 'One or both policies have no confirmed inclusion target in the collected assignment data.' }
    }

    $evidence = [Collections.Generic.List[object]]::new()
    foreach ($first in $firstIncluded) {
        foreach ($second in $secondIncluded) {
            $sameFilter = ([string] $first.FilterId -eq [string] $second.FilterId) -and ([string] $first.FilterMode -eq [string] $second.FilterMode)
            $sameBroadTarget = $first.TargetType -eq $second.TargetType -and $first.TargetType -in @('All devices', 'All users', 'All licensed users')
            $sameGroup = $first.TargetType -eq 'Included group' -and $second.TargetType -eq 'Included group' -and -not [string]::IsNullOrWhiteSpace([string] $first.GroupId) -and $first.GroupId -eq $second.GroupId
            if (($sameBroadTarget -or $sameGroup) -and $sameFilter) {
                $evidence.Add([PSCustomObject] @{ FirstAssignmentId = $first.Id; SecondAssignmentId = $second.Id; TargetType = $first.TargetType; GroupId = $first.GroupId; FilterId = $first.FilterId; FilterMode = $first.FilterMode })
            }
        }
    }
    if ($evidence.Count -gt 0) {
        return [PSCustomObject] @{ State = 'ConfirmedOverlap'; Evidence = $evidence.ToArray(); Reason = 'The policies share an exact included broad target or group and the same filter evidence.' }
    }
    [PSCustomObject] @{ State = 'NotEvaluated'; Evidence = @(); Reason = 'Different groups, filters or target types may still overlap, but the collected evidence does not prove it.' }
}
