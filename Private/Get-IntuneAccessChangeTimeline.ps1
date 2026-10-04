function Compare-IntuneAccessOutcomeTransition {
    <#
    Compares reported outcomes between two collections by workload and device.
    Returns NewFailure, Recovered, NewResult and ResultRemoved transitions only.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()] [object[]] $Before = @(),
        [AllowEmptyCollection()] [object[]] $After = @()
    )

    function Get-OutcomeKey([object] $Outcome) {
        $device = [string] (Get-IntuneAccessProperty $Outcome 'DeviceId' '')
        if ([string]::IsNullOrWhiteSpace($device)) { $device = 'name:' + [string] (Get-IntuneAccessProperty $Outcome 'DeviceName' '') }
        '{0}|{1}' -f [string] (Get-IntuneAccessProperty $Outcome 'WorkloadId' ''), $device
    }

    $beforeMap = @{}
    foreach ($item in @($Before)) { if ($null -ne $item) { $beforeMap[(Get-OutcomeKey $item)] = $item } }
    $afterMap = @{}
    foreach ($item in @($After)) { if ($null -ne $item) { $afterMap[(Get-OutcomeKey $item)] = $item } }

    $transitions = [System.Collections.Generic.List[object]]::new()
    foreach ($key in @($beforeMap.Keys + $afterMap.Keys | Sort-Object -Unique)) {
        $old = if ($beforeMap.ContainsKey($key)) { $beforeMap[$key] } else { $null }
        $new = if ($afterMap.ContainsKey($key)) { $afterMap[$key] } else { $null }
        $oldCategory = [string] (Get-IntuneAccessProperty $old 'Category' '')
        $newCategory = [string] (Get-IntuneAccessProperty $new 'Category' '')
        $transition = if ($null -eq $old -and $newCategory -eq 'Error') { 'NewFailure' }
            elseif ($null -eq $old) { 'NewResult' }
            elseif ($null -eq $new) { 'ResultRemoved' }
            elseif ($oldCategory -ne 'Error' -and $newCategory -eq 'Error') { 'NewFailure' }
            elseif ($oldCategory -eq 'Error' -and $newCategory -eq 'Success') { 'Recovered' }
            else { '' }
        if (-not $transition) { continue }
        $record = if ($null -ne $new) { $new } else { $old }
        $transitions.Add([PSCustomObject] @{
            PSTypeName      = 'IntuneAccess.OutcomeTransition'
            Transition      = $transition
            WorkloadId      = [string] (Get-IntuneAccessProperty $record 'WorkloadId' '')
            WorkloadName    = [string] (Get-IntuneAccessProperty $record 'WorkloadName' '')
            DeviceId        = [string] (Get-IntuneAccessProperty $record 'DeviceId' '')
            DeviceName      = [string] (Get-IntuneAccessProperty $record 'DeviceName' '')
            BeforeState     = [string] (Get-IntuneAccessProperty $old 'State' '')
            AfterState      = [string] (Get-IntuneAccessProperty $new 'State' '')
            AfterErrorCode  = Get-IntuneAccessProperty $new 'ErrorCode' $null
            ReportedAt      = [string] (Get-IntuneAccessProperty $record 'LastReportedDateTime' '')
        })
    }
    $transitions.ToArray()
}

function Get-IntuneAccessChangeTimeline {
    <#
    Builds one "what changed?" timeline from Intune audit events, snapshot configuration
    changes and reported outcome changes. Configuration changes are separated from
    check-in and inventory refreshes. A failure reported after a change on the same
    workload is shown as correlation in time, never as proof of cause.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()] [object[]] $AuditEvent = @(),
        [AllowNull()] [object] $SnapshotComparison,
        [AllowEmptyCollection()] [object[]] $DeploymentOutcome = @(),
        [AllowEmptyCollection()] [object[]] $Workload = @(),
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow,
        [ValidateRange(1, 720)] [int] $CorrelationHours = 72
    )

    function ConvertTo-TimelineTime([object] $Value) {
        $parsed = [DateTimeOffset]::MinValue
        if ($null -ne $Value -and [DateTimeOffset]::TryParse([string] $Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref] $parsed)) { return $parsed }
        $null
    }

    $workloadNames = @{}
    foreach ($item in @($Workload)) { $workloadNames[[string] (Get-IntuneAccessProperty $item 'Id' '')] = [string] (Get-IntuneAccessProperty $item 'Name' '') }

    $configurationTypes = @('RoleAssignment', 'RoleDefinition', 'ScopeTag', 'Workload', 'WorkloadAssignment', 'AssignmentFilter', 'PolicySetting', 'AdminGroup', 'ScopeGroup', 'WorkloadGroup', 'Membership', 'Administrator', 'Permission')
    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($auditRecord in @($AuditEvent)) {
        $resourceIds = @(Get-IntuneAccessProperty $auditRecord 'ResourceIds' @())
        $resources = @(Get-IntuneAccessProperty $auditRecord 'Resources' @())
        $changed = @($resources | ForEach-Object { foreach ($property in @(Get-IntuneAccessProperty $_ 'ModifiedProperties' @())) { '{0}: {1} > {2}' -f $property.DisplayName, $(if ($property.OldValue) { $property.OldValue } else { '(empty)' }), $property.NewValue } })
        $entries.Add([PSCustomObject] @{
            PSTypeName   = 'IntuneAccess.TimelineEntry'
            Time         = ConvertTo-TimelineTime (Get-IntuneAccessProperty $auditRecord 'ActivityDateTime')
            TimeIsRange  = $false
            Kind         = 'Configuration'
            Source       = 'Intune audit log'
            Title        = [string] (Get-IntuneAccessProperty $auditRecord 'Activity' (Get-IntuneAccessProperty $auditRecord 'DisplayName' 'Audit event'))
            Target       = (($resources | ForEach-Object { $_.DisplayName } | Where-Object { $_ }) -join ', ')
            Actor        = [string] (Get-IntuneAccessProperty $auditRecord 'ActorUserPrincipalName' '')
            Details      = $changed
            WorkloadIds  = @($resourceIds | Where-Object { $workloadNames.ContainsKey([string] $_) })
            DeviceNames  = @()
            Correlated   = @()
        })
    }

    $hiddenRefreshes = 0
    if ($null -ne $SnapshotComparison) {
        $referenceAt = ConvertTo-TimelineTime (Get-IntuneAccessProperty $SnapshotComparison 'ReferenceAt')
        $differenceAt = ConvertTo-TimelineTime (Get-IntuneAccessProperty $SnapshotComparison 'DifferenceAt')
        foreach ($change in @(Get-IntuneAccessProperty $SnapshotComparison 'Changes' @())) {
            if ([string] $change.EntityType -notin $configurationTypes) { $hiddenRefreshes++; continue }
            if (@(Get-IntuneAccessProperty $change 'AuditEvents' @()).Count -gt 0) { continue }
            $record = if ($null -ne $change.After) { $change.After } else { $change.Before }
            $workloadId = [string] (Get-IntuneAccessProperty $record 'WorkloadId' '')
            if (-not $workloadId -and $change.EntityType -eq 'Workload') { $workloadId = [string] (Get-IntuneAccessProperty $record 'Id' '') }
            $entries.Add([PSCustomObject] @{
                PSTypeName   = 'IntuneAccess.TimelineEntry'
                Time         = $differenceAt
                TimeIsRange  = $true
                Kind         = 'Configuration'
                Source       = 'Snapshot comparison'
                Title        = ('{0} {1}' -f $change.EntityType, $change.ChangeType.ToLowerInvariant())
                Target       = [string] $change.Name
                Actor        = ''
                Details      = @(if ($change.ChangeType -eq 'Modified') { 'Changed: ' + (@($change.ChangedProperties) -join ', ') } else { '' }) + @("Detected between $referenceAt and $differenceAt; no matching audit event was returned.")
                WorkloadIds  = @($workloadId | Where-Object { $_ })
                DeviceNames  = @()
                Correlated   = @()
            })
        }

        foreach ($transition in @(Get-IntuneAccessProperty $SnapshotComparison 'OutcomeTransitions' @())) {
            $label = switch ($transition.Transition) { 'NewFailure' { 'New failure reported' } 'Recovered' { 'Recovered' } 'NewResult' { 'New result reported' } default { 'Result no longer reported' } }
            $entries.Add([PSCustomObject] @{
                PSTypeName   = 'IntuneAccess.TimelineEntry'
                Time         = $(if ($transition.ReportedAt) { ConvertTo-TimelineTime $transition.ReportedAt } else { $differenceAt })
                TimeIsRange  = -not [bool] $transition.ReportedAt
                Kind         = 'Outcome'
                Source       = 'Reported outcome'
                Title        = $label
                Target       = ('{0} on {1}' -f $transition.WorkloadName, $transition.DeviceName)
                Actor        = ''
                Details      = @("State: $(if ($transition.BeforeState) { $transition.BeforeState } else { '(none)' }) > $(if ($transition.AfterState) { $transition.AfterState } else { '(none)' })")
                WorkloadIds  = @($transition.WorkloadId)
                DeviceNames  = @($transition.DeviceName)
                Correlated   = @()
                Transition   = $transition.Transition
            })
        }
    }
    else {
        # Without a baseline, current failures are still placed on the timeline at their report time.
        foreach ($outcome in @($DeploymentOutcome | Where-Object { [string] (Get-IntuneAccessProperty $_ 'Category' '') -eq 'Error' })) {
            $entries.Add([PSCustomObject] @{
                PSTypeName   = 'IntuneAccess.TimelineEntry'
                Time         = ConvertTo-TimelineTime (Get-IntuneAccessProperty $outcome 'LastReportedDateTime')
                TimeIsRange  = $false
                Kind         = 'Outcome'
                Source       = 'Reported outcome'
                Title        = 'Failure reported'
                Target       = ('{0} on {1}' -f (Get-IntuneAccessProperty $outcome 'WorkloadName' ''), (Get-IntuneAccessProperty $outcome 'DeviceName' ''))
                Actor        = ''
                Details      = @("State: $(Get-IntuneAccessProperty $outcome 'State' '')")
                WorkloadIds  = @([string] (Get-IntuneAccessProperty $outcome 'WorkloadId' ''))
                DeviceNames  = @([string] (Get-IntuneAccessProperty $outcome 'DeviceName' ''))
                Correlated   = @()
                Transition   = 'CurrentFailure'
            })
        }
    }

    # Correlate configuration changes with failures reported afterwards on the same workload.
    $failures = @($entries | Where-Object { $_.Kind -eq 'Outcome' -and $null -ne $_.Time -and $_.PSObject.Properties['Transition'] -and $_.Transition -in @('NewFailure', 'CurrentFailure') })
    foreach ($entry in @($entries | Where-Object { $_.Kind -eq 'Configuration' -and $null -ne $_.Time -and -not $_.TimeIsRange -and @($_.WorkloadIds).Count -gt 0 })) {
        $windowEnd = $entry.Time.AddHours($CorrelationHours)
        $after = @($failures | Where-Object { $_.Time -ge $entry.Time -and $_.Time -le $windowEnd -and @($_.WorkloadIds | Where-Object { $_ -in $entry.WorkloadIds }).Count -gt 0 })
        if ($after.Count -gt 0) {
            $devices = @($after | ForEach-Object { $_.DeviceNames } | Select-Object -Unique)
            $entry.Correlated = @("$($devices.Count) device(s) reported a failure on this workload within $CorrelationHours hours of this change: $($devices -join ', '). This is timing only, not proof of cause.")
        }
    }

    $ordered = @($entries | Sort-Object @{ Expression = { if ($null -eq $_.Time) { [DateTimeOffset]::MinValue } else { $_.Time } }; Descending = $true })
    [PSCustomObject] @{
        PSTypeName            = 'IntuneAccess.ChangeTimeline'
        Entries               = $ordered
        ConfigurationChanges  = @($ordered | Where-Object Kind -EQ 'Configuration').Count
        OutcomeChanges        = @($ordered | Where-Object Kind -EQ 'Outcome').Count
        CorrelatedChanges     = @($ordered | Where-Object { @($_.Correlated).Count -gt 0 }).Count
        HiddenRefreshChanges  = $hiddenRefreshes
        CorrelationHours      = $CorrelationHours
        BaselineState         = if ($null -eq $SnapshotComparison) { 'NoBaseline' } else { 'Compared' }
        EvidenceBoundary      = 'Audit events show who changed what and when. Snapshot changes show what differs between two collections. A failure that follows a change is correlated in time only; it is not proof that the change caused it.'
        GeneratedAt           = $AsOf
    }
}
