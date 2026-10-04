function New-IntuneAccessChainStep {
    param([int] $Order, [string] $Name, [string] $State, [string] $Finding, [string] $Evidence = '')
    [PSCustomObject] @{ PSTypeName = 'IntuneAccess.DeliveryChainStep'; Order = $Order; Name = $Name; State = $State; Finding = $Finding; Evidence = $Evidence }
}

function Get-IntuneAccessDeliveryChain {
    <#
    Turns one device assignment explanation into an ordered "why didn't it apply?" chain.
    Each step is Passed, Broken, Waiting, Information or NotEvaluated. The chain stops at the
    first Broken or NotEvaluated step; later steps are still listed for context but the
    verdict comes from the first link that fails or where the evidence ends.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Compact internal step constructor keeps each chain step on one readable line.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Explanation,
        [AllowNull()] [object] $Device,
        [AllowEmptyCollection()] [object[]] $OutcomeCollectionStatus = @(),
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow,
        [ValidateRange(1, 365)] [int] $StaleDays = 7
    )

    $steps = [System.Collections.Generic.List[object]]::new()
    $paths = @(Get-IntuneAccessProperty $Explanation 'AssignmentPaths' @())
    $assignmentState = [string] (Get-IntuneAccessProperty $Explanation 'AssignmentState' 'NotEvaluated')
    $workloadId = [string] (Get-IntuneAccessProperty $Explanation 'WorkloadId' '')
    $workloadType = [string] (Get-IntuneAccessProperty $Explanation 'WorkloadType' '')

    # 1. Device check-in.
    $lastSync = $null
    $syncText = [string] (Get-IntuneAccessProperty $Device 'LastSyncDateTime' '')
    $parsedSync = [DateTimeOffset]::MinValue
    if ($null -ne $Device -and [DateTimeOffset]::TryParse($syncText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref] $parsedSync)) { $lastSync = $parsedSync }
    $syncAgeDays = if ($null -ne $lastSync) { [Math]::Round(($AsOf - $lastSync).TotalDays, 1) } else { $null }
    $deviceStale = $null -ne $syncAgeDays -and $syncAgeDays -gt $StaleDays
    $deviceStep = if ($null -eq $Device) {
        New-IntuneAccessChainStep 1 'Device check-in' 'NotEvaluated' 'The managed-device record was not available.'
    }
    elseif ($null -eq $lastSync) {
        New-IntuneAccessChainStep 1 'Device check-in' 'NotEvaluated' 'Intune returned no last check-in time for this device.'
    }
    elseif ($deviceStale) {
        New-IntuneAccessChainStep 1 'Device check-in' 'Information' "Last check-in was $syncAgeDays days ago, beyond the $StaleDays-day threshold. A device that is not checking in cannot receive or report new assignments." "LastSyncDateTime $syncText"
    }
    else {
        New-IntuneAccessChainStep 1 'Device check-in' 'Passed' "Device checked in $syncAgeDays days ago." "LastSyncDateTime $syncText"
    }
    $steps.Add($deviceStep)

    # 2. Assignment exists.
    if ($assignmentState -eq 'NotAssigned' -or $paths.Count -eq 0) {
        $steps.Add((New-IntuneAccessChainStep 2 'Assignment configured' 'Broken' 'The workload has no assignments, so Intune has nothing to deliver.'))
    }
    else {
        $steps.Add((New-IntuneAccessChainStep 2 'Assignment configured' 'Passed' "$($paths.Count) assignment target(s) configured." (($paths | ForEach-Object { "$($_.TargetType)$(if ($_.GroupName) { ': ' + $_.GroupName })" }) -join '; ')))

        # 3. Targeting.
        $matched = @($paths | Where-Object { $_.DeviceTargetState -eq 'Matched' -or $_.UserTargetState -eq 'Matched' })
        $uncertain = @($paths | Where-Object { $_.DeviceTargetState -eq 'NotEvaluated' -or $_.UserTargetState -eq 'NotEvaluated' })
        $includeTargets = @($paths | Where-Object TargetType -NE 'Excluded group')
        $matchedIncludes = @($matched | Where-Object TargetType -NE 'Excluded group')
        if ($matchedIncludes.Count -gt 0) {
            $how = ($matchedIncludes | ForEach-Object {
                $through = if ($_.DeviceTargetState -eq 'Matched') { 'device' } else { 'primary user' }
                "$($_.TargetType)$(if ($_.GroupName) { ' ' + $_.GroupName }) via $through"
            }) -join '; '
            $steps.Add((New-IntuneAccessChainStep 3 'Device or user targeted' 'Passed' 'The device or its primary user is in an included target.' $how))
        }
        elseif (@($paths | Where-Object PathState -EQ 'Excluded').Count -gt 0) {
            $steps.Add((New-IntuneAccessChainStep 3 'Device or user targeted' 'Information' 'No included target matched, and an exclusion group also applies.'))
        }
        elseif ($uncertain.Count -gt 0) {
            $steps.Add((New-IntuneAccessChainStep 3 'Device or user targeted' 'NotEvaluated' 'Group membership could not be evaluated for at least one target, so targeting is not proven either way.'))
        }
        else {
            $targets = ($includeTargets | ForEach-Object { "$($_.TargetType)$(if ($_.GroupName) { ': ' + $_.GroupName })" }) -join '; '
            $steps.Add((New-IntuneAccessChainStep 3 'Device or user targeted' 'Broken' 'Neither the device nor its primary user is a member of any included target group.' "Included targets: $targets"))
        }

        # 4. Exclusion.
        $excluded = @($paths | Where-Object PathState -EQ 'Excluded')
        if ($excluded.Count -gt 0) {
            $steps.Add((New-IntuneAccessChainStep 4 'Not excluded' 'Broken' 'An exclusion group matched the device or its primary user. Exclusions take precedence over inclusions.' (($excluded | ForEach-Object { "Excluded group: $($_.GroupName)" }) -join '; ')))
        }
        else {
            $steps.Add((New-IntuneAccessChainStep 4 'Not excluded' 'Passed' 'No exclusion group matched.'))
        }

        # 5. Assignment filter.
        $filtered = @($paths | Where-Object PathState -EQ 'FilteredOut')
        $filterUnknown = @($paths | Where-Object { $_.FilterState -eq 'NotEvaluated' -and $_.PathState -eq 'NotEvaluated' })
        $included = @($paths | Where-Object PathState -EQ 'Included')
        if ($included.Count -eq 0 -and $filtered.Count -gt 0) {
            $detail = ($filtered | ForEach-Object { "$($_.FilterMode) filter rule $($_.FilterRule); device value '$($_.FilterObservedValue)'" }) -join '; '
            $steps.Add((New-IntuneAccessChainStep 5 'Assignment filter' 'Broken' 'An assignment filter removed the device from every matching target.' $detail))
        }
        elseif ($included.Count -eq 0 -and $filterUnknown.Count -gt 0) {
            $steps.Add((New-IntuneAccessChainStep 5 'Assignment filter' 'NotEvaluated' 'The filter rule is compound or uses a property IntuneAccess does not collect, so filter evaluation is not proven.' (($filterUnknown | ForEach-Object { $_.FilterRule }) -join '; ')))
        }
        elseif (@($paths | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.FilterId) }).Count -gt 0) {
            $steps.Add((New-IntuneAccessChainStep 5 'Assignment filter' 'Passed' 'The device passed the supported assignment filter.'))
        }
        else {
            $steps.Add((New-IntuneAccessChainStep 5 'Assignment filter' 'Passed' 'No assignment filter applies to the matching target.'))
        }

        # 6. Intent.
        $intents = @($included | ForEach-Object { ([string] $_.Intent).ToLowerInvariant() } | Select-Object -Unique)
        if ($included.Count -gt 0 -and $intents.Count -gt 0 -and @($intents | Where-Object { $_ -notin @('available', 'uninstall') }).Count -eq 0) {
            if ('uninstall' -in $intents) {
                $steps.Add((New-IntuneAccessChainStep 6 'Assignment intent' 'Information' 'The matching assignment intent is Uninstall, so Intune removes the app rather than installing it.'))
            }
            else {
                $steps.Add((New-IntuneAccessChainStep 6 'Assignment intent' 'Information' 'The matching assignment intent is Available. Intune does not push the app; the user installs it from Company Portal.'))
            }
        }
    }

    # 7. Reported outcome.
    $outcomes = @(Get-IntuneAccessProperty $Explanation 'DeploymentOutcomes' @())
    $status = @($OutcomeCollectionStatus | Where-Object { [string] (Get-IntuneAccessProperty $_ 'WorkloadId' '') -eq $workloadId } | Select-Object -First 1)
    $statusState = if ($status.Count) { [string] (Get-IntuneAccessProperty $status[0] 'State' '') } else { '' }
    $errorReference = $null
    if ($outcomes.Count -eq 0) {
        if ($statusState -eq 'NotSupported') {
            $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'NotEvaluated' "IntuneAccess does not collect per-device results for this $workloadType type. Check the policy's device status in the Intune admin centre."))
        }
        elseif ($deviceStale) {
            $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'Waiting' "No result has been reported, and the device has not checked in for $syncAgeDays days. The device needs to check in before Intune can deliver or report."))
        }
        else {
            $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'NotEvaluated' 'No device result was returned for this workload. It may not have been processed yet, or the result is not exposed.'))
        }
    }
    else {
        $outcome = @($outcomes | Sort-Object { [string] (Get-IntuneAccessProperty $_ 'LastReportedDateTime' '') } -Descending)[0]
        $category = [string] (Get-IntuneAccessProperty $outcome 'Category' 'Unknown')
        $state = [string] (Get-IntuneAccessProperty $outcome 'State' '')
        $detail = [string] (Get-IntuneAccessProperty $outcome 'StateDetail' '')
        $reported = [string] (Get-IntuneAccessProperty $outcome 'LastReportedDateTime' '')
        $evidence = "State $state$(if ($detail) { " ($detail)" }); reported $reported"
        switch ($category) {
            'Success' { $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'Passed' 'Intune reported success for this device.' $evidence)) }
            'Error' {
                $errorReference = Get-IntuneAccessErrorReference -ErrorCode (Get-IntuneAccessProperty $outcome 'ErrorCode' $null)
                $detectionState = [string] (Get-IntuneAccessProperty $outcome 'DetectionState' '')
                $remediationState = [string] (Get-IntuneAccessProperty $outcome 'RemediationState' '')
                $finding = if ($detectionState) {
                    "The detection script reported '$detectionState'$(if ($remediationState) { " and remediation reported '$remediationState'" }). For Remediations this means the issue was detected on the device."
                }
                else { "Intune reported '$state'$(if ($detail) { " ($detail)" }) for this device." }
                if ($null -ne $errorReference) {
                    $evidence += "; error $($errorReference.Hex)"
                    $finding = if ($errorReference.Meaning) { "Intune reported error $($errorReference.Hex): $($errorReference.Meaning)" } else { "$finding Error code $($errorReference.Hex)." }
                }
                $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'Broken' $finding $evidence))
            }
            'Pending' { $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'Waiting' 'Intune reports the deployment as pending on this device.' $evidence)) }
            default { $steps.Add((New-IntuneAccessChainStep 7 'Reported outcome' 'NotEvaluated' "Intune returned state '$state', which does not establish success or failure." $evidence)) }
        }
    }

    $stepArray = $steps.ToArray()
    $firstStop = @($stepArray | Where-Object { $_.State -in @('Broken', 'NotEvaluated', 'Waiting') } | Select-Object -First 1)
    $intentStep = @($stepArray | Where-Object { $_.Name -eq 'Assignment intent' })
    $verdict = if ($firstStop.Count -eq 0) { if ($intentStep.Count) { 'AvailableOrUninstallIntent' } else { 'Applied' } }
        else {
            switch ($firstStop[0].Name) {
                'Assignment configured' { 'NotAssigned' }
                'Device or user targeted' { if ($firstStop[0].State -eq 'Broken') { 'NotTargeted' } else { 'NotEvaluated' } }
                'Not excluded' { 'Excluded' }
                'Assignment filter' { if ($firstStop[0].State -eq 'Broken') { 'FilteredOut' } else { 'NotEvaluated' } }
                'Reported outcome' { switch ($firstStop[0].State) { 'Broken' { 'Failed' } 'Waiting' { 'WaitingForDevice' } default { if ($statusState -eq 'NotSupported') { 'ResultNotCollected' } else { 'NoResult' } } } }
                default { 'NotEvaluated' }
            }
        }
    if ($verdict -in @('NoResult', 'ResultNotCollected') -and $intentStep.Count) { $verdict = 'AvailableOrUninstallIntent' }

    $nextCheck = switch ($verdict) {
        'Applied' { 'No action indicated. Intune reported success; confirm the end-user symptom separately if it persists.' }
        'AvailableOrUninstallIntent' { 'Confirm the intended assignment type. Use Required if the app must install without user action.' }
        'NotAssigned' { 'Assign the workload to a group that contains the device or its primary user, after checking the change in a pilot group.' }
        'NotTargeted' { 'Add the device or user to an included group, or confirm that it is deliberately out of scope.' }
        'Excluded' { 'Review the exclusion group membership. Exclusion wins over inclusion.' }
        'FilteredOut' { 'Compare the filter rule with the device property shown. Correct the filter or the device record if the device should be in scope.' }
        'Failed' { if ($null -ne $errorReference -and $errorReference.NextCheck) { $errorReference.NextCheck } else { 'Review the device-side logs for this workload and the error detail shown.' } }
        'ResultNotCollected' { "Targeting looks correct. IntuneAccess does not collect per-device results for this workload type, so open the policy's device status in the Intune admin centre to confirm delivery." }
        'WaitingForDevice' { if ($deviceStale) { 'Find out why the device is not checking in (powered off, network, MDM certificate or enrolment problem) before investigating the workload.' } else { 'Wait for the next check-in, then refresh the report.' } }
        default { 'The evidence stops here. Check the Intune admin centre for this device and workload, or collect device-side logs.' }
    }

    [PSCustomObject] @{
        PSTypeName     = 'IntuneAccess.DeliveryChain'
        DeviceId       = [string] (Get-IntuneAccessProperty $Explanation 'DeviceId' '')
        DeviceName     = [string] (Get-IntuneAccessProperty $Explanation 'DeviceName' '')
        UserPrincipalName = [string] (Get-IntuneAccessProperty $Device 'UserPrincipalName' '')
        WorkloadId     = $workloadId
        WorkloadName   = [string] (Get-IntuneAccessProperty $Explanation 'WorkloadName' '')
        WorkloadType   = $workloadType
        Verdict        = $verdict
        StoppedAt      = if ($firstStop.Count) { $firstStop[0].Name } else { '' }
        Summary        = if ($firstStop.Count) { $firstStop[0].Finding } else { ($stepArray[-1]).Finding }
        NextCheck      = $nextCheck
        ErrorReference = $errorReference
        DeviceCheckInAgeDays = $syncAgeDays
        Steps          = $stepArray
        EvidenceBoundary = 'Each step is calculated from collected configuration or reported by Intune. A configured assignment does not prove delivery, and a reported result does not prove which assignment produced it.'
    }
}
