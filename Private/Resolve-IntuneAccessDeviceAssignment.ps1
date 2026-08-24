function Test-IntuneAccessAssignmentFilterRule {
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Filter,
        [Parameter(Mandatory)] [object] $Device
    )

    if ($null -eq $Filter) {
        return [PSCustomObject] @{ State = 'NotEvaluated'; Explanation = 'The assignment referenced a filter that was not collected.'; Rule = ''; ObservedValue = $null }
    }
    $rule = [string] (Get-IntuneAccessProperty $Filter 'Rule')
    if ([string]::IsNullOrWhiteSpace($rule)) {
        return [PSCustomObject] @{ State = 'NotEvaluated'; Explanation = 'The assignment filter rule was empty.'; Rule = $rule; ObservedValue = $null }
    }

    $propertyMap = @{
        'device.devicename' = 'DeviceName'; 'device.manufacturer' = 'Manufacturer'; 'device.model' = 'Model'
        'device.operatingsystemsku' = 'OperatingSystemSku'; 'device.osversion' = 'OsVersion'
        'device.ownership' = 'Ownership'; 'device.enrollmentprofileName' = 'EnrollmentProfileName'
    }
    $match = [regex]::Match($rule.Trim(), '^\(?\s*\[?(?<property>device\.[A-Za-z0-9]+)\]?\s+-(?<operator>eq|ne|contains|startsWith)\s+"(?<value>[^"]*)"\s*\)?$', 'IgnoreCase')
    if (-not $match.Success) {
        return [PSCustomObject] @{ State = 'NotEvaluated'; Explanation = 'The filter uses a compound or unsupported expression. The raw rule is retained.'; Rule = $rule; ObservedValue = $null }
    }
    $propertyKey = $match.Groups['property'].Value.ToLowerInvariant()
    if (-not $propertyMap.ContainsKey($propertyKey)) {
        return [PSCustomObject] @{ State = 'NotEvaluated'; Explanation = "The device property '$propertyKey' is not present in the collected evidence model."; Rule = $rule; ObservedValue = $null }
    }
    $observed = [string] (Get-IntuneAccessProperty $Device $propertyMap[$propertyKey] '')
    $expected = $match.Groups['value'].Value
    $isMatch = switch ($match.Groups['operator'].Value.ToLowerInvariant()) {
        'eq' { $observed -ieq $expected }
        'ne' { $observed -ine $expected }
        'contains' { $observed.IndexOf($expected, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
        'startswith' { $observed.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase) }
    }
    [PSCustomObject] @{ State = if ($isMatch) { 'Matched' } else { 'NotMatched' }; Explanation = "The supported filter expression was evaluated against $propertyKey."; Rule = $rule; ObservedValue = $observed }
}

function Resolve-IntuneAccessDeviceAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Device,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Workload,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Assignment,
        [Parameter(Mandatory)] [object] $DeviceMembership,
        [Parameter(Mandatory)] [object] $UserMembership,
        [AllowEmptyCollection()] [object[]] $DeploymentOutcome = @()
    )

    $deviceGroupIds = @((Get-IntuneAccessProperty $DeviceMembership 'GroupIds' @()) | ForEach-Object { ([string] $_).ToLowerInvariant() })
    $userGroupIds = @((Get-IntuneAccessProperty $UserMembership 'GroupIds' @()) | ForEach-Object { ([string] $_).ToLowerInvariant() })
    $deviceMembershipState = [string] (Get-IntuneAccessProperty $DeviceMembership 'State' 'NotEvaluated')
    $userMembershipState = [string] (Get-IntuneAccessProperty $UserMembership 'State' 'NotEvaluated')
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($item in $Workload) {
        $itemAssignments = @($Assignment | Where-Object WorkloadId -EQ $item.Id)
        $paths = [System.Collections.Generic.List[object]]::new()
        foreach ($configured in $itemAssignments) {
            $targetType = [string] $configured.TargetType
            $groupId = ([string] $configured.GroupId).ToLowerInvariant()
            $isExclusion = $targetType -eq 'Excluded group'
            $deviceTargetState = 'NotMatched'
            $userTargetState = 'NotMatched'
            if ($targetType -eq 'All devices') { $deviceTargetState = 'Matched'; $userTargetState = 'NotApplicable' }
            elseif ($targetType -in @('All users', 'All licensed users')) { $userTargetState = if ([string]::IsNullOrWhiteSpace([string] $Device.UserId)) { 'NotEvaluated' } else { 'Matched' }; $deviceTargetState = 'NotApplicable' }
            elseif ($targetType -in @('Included group', 'Excluded group')) {
                $deviceTargetState = if ($deviceMembershipState -eq 'Evaluated') { if ($groupId -in $deviceGroupIds) { 'Matched' } else { 'NotMatched' } } else { 'NotEvaluated' }
                $userTargetState = if ($userMembershipState -eq 'Evaluated') { if ($groupId -in $userGroupIds) { 'Matched' } else { 'NotMatched' } } elseif ($userMembershipState -eq 'NotApplicable') { 'NotApplicable' } else { 'NotEvaluated' }
            }
            else { $deviceTargetState = 'NotEvaluated'; $userTargetState = 'NotEvaluated' }

            $targetMatch = $deviceTargetState -eq 'Matched' -or $userTargetState -eq 'Matched'
            $targetUncertain = $deviceTargetState -eq 'NotEvaluated' -or $userTargetState -eq 'NotEvaluated'
            $filterEvaluation = [PSCustomObject] @{ State = 'NotApplicable'; Explanation = 'No assignment filter was configured.'; Rule = ''; ObservedValue = $null }
            if (-not [string]::IsNullOrWhiteSpace([string] $configured.FilterId)) {
                $filterEvaluation = Test-IntuneAccessAssignmentFilterRule -Filter $configured.Filter -Device $Device
                if ([string] $configured.FilterMode -ieq 'exclude') {
                    if ($filterEvaluation.State -eq 'Matched') { $filterEvaluation.State = 'Excluded' }
                    elseif ($filterEvaluation.State -eq 'NotMatched') { $filterEvaluation.State = 'Passed' }
                }
                else {
                    if ($filterEvaluation.State -eq 'Matched') { $filterEvaluation.State = 'Passed' }
                    elseif ($filterEvaluation.State -eq 'NotMatched') { $filterEvaluation.State = 'FilteredOut' }
                }
            }
            $pathState = if ($isExclusion -and $targetMatch) { 'Excluded' }
                elseif ($targetMatch -and $filterEvaluation.State -in @('NotApplicable', 'Passed')) { 'Included' }
                elseif ($targetMatch -and $filterEvaluation.State -in @('FilteredOut', 'Excluded')) { 'FilteredOut' }
                elseif ($targetMatch -and $filterEvaluation.State -eq 'NotEvaluated') { 'NotEvaluated' }
                elseif ($targetUncertain) { 'NotEvaluated' }
                else { 'NotMatched' }
            $paths.Add([PSCustomObject] @{
                PSTypeName       = 'IntuneAccess.AssignmentPath'
                AssignmentId    = [string] $configured.Id
                Intent          = [string] $configured.Intent
                TargetType      = $targetType
                GroupId         = [string] $configured.GroupId
                GroupName       = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $configured 'Group') 'DisplayName' '')
                DeviceTargetState = $deviceTargetState
                UserTargetState = $userTargetState
                FilterId        = [string] $configured.FilterId
                FilterMode      = [string] $configured.FilterMode
                FilterState     = [string] $filterEvaluation.State
                FilterRule      = [string] $filterEvaluation.Rule
                FilterObservedValue = $filterEvaluation.ObservedValue
                PathState       = $pathState
                SourceApiVersion = [string] $configured.SourceApiVersion
                EvidenceState   = if ($pathState -eq 'NotEvaluated') { 'NotEvaluated' } else { 'CalculatedFromObservedConfiguration' }
            })
        }

        $pathArray = $paths.ToArray()
        $calculated = if (@($pathArray | Where-Object PathState -EQ 'Excluded').Count -gt 0) { 'Excluded' }
            elseif (@($pathArray | Where-Object PathState -EQ 'Included').Count -gt 0) { 'Included' }
            elseif (@($pathArray | Where-Object PathState -EQ 'NotEvaluated').Count -gt 0) { 'NotEvaluated' }
            elseif ($itemAssignments.Count -eq 0) { 'NotAssigned' }
            else { 'NotTargeted' }
        $outcomes = @($DeploymentOutcome | Where-Object { $_.WorkloadId -eq $item.Id -and $_.DeviceId -eq $Device.Id })
        $reportedState = if ($outcomes.Count -eq 0) { 'NoReportedEvidence' } elseif (@($outcomes | Where-Object Category -EQ 'Error').Count -gt 0) { 'Error' } elseif (@($outcomes | Where-Object Category -EQ 'Success').Count -gt 0) { 'Success' } else { [string] $outcomes[0].Category }
        $results.Add([PSCustomObject] @{
            PSTypeName             = 'IntuneAccess.DeviceAssignmentExplanation'
            DeviceId               = [string] $Device.Id
            DeviceName             = [string] $Device.DeviceName
            WorkloadId             = [string] $item.Id
            WorkloadName           = [string] $item.Name
            WorkloadType           = [string] $item.WorkloadType
            AssignmentState        = $calculated
            ReportedOutcomeState   = $reportedState
            AssignmentPaths        = $pathArray
            DeploymentOutcomes     = $outcomes
            EvidenceBoundary       = 'Assignment configuration, group membership, supported filter evaluation and reported outcome are separate evidence layers. Assignment does not prove delivery.'
            GeneratedAt            = [DateTimeOffset]::Now
        })
    }
    $results.ToArray()
}
