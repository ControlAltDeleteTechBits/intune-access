function ConvertTo-IntuneAccessInsightsHtml {
    <#
    Renders the 5.0 views: why didn't it apply, what changed, change preview, privilege usage
    and Scoped permissions readiness. Returns navigation, view panels and inspector panels for
    the main explorer. All tenant values are HTML encoded; no remote resources are referenced.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Compact local row helper keeps each view readable.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $TenantRbac,
        [Parameter(Mandatory)] [hashtable] $Icon
    )

    function Enc([AllowNull()] [object] $Value) { [System.Net.WebUtility]::HtmlEncode([string] $Value) }
    function Format-InsightDate([AllowNull()] [object] $Value) {
        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) { return 'Time not returned' }
        try { ([DateTimeOffset] $Value).ToString('dd MMM yyyy HH:mm zzz', [Globalization.CultureInfo]::GetCultureInfo('en-GB')) } catch { [string] $Value }
    }
    function Add-Row([System.Text.StringBuilder] $Builder, [string] $Key, [string] $View, [string] $Title, [string] $Meta, [string] $Badge, [string] $IconData) {
        $search = Enc "$Title $Meta $Badge"
        $null = $Builder.AppendLine(('<button class="object-row" type="button" data-inspect="{0}" data-view-target="{1}" data-search="{2}"><img src="{3}" alt=""><span class="object-copy"><strong>{4}</strong><small>{5}</small></span><span class="object-badge">{6}</span></button>' -f $Key, $View, $search, $IconData, (Enc $Title), (Enc $Meta), (Enc $Badge)))
    }
    function Get-StateClass([string] $State) {
        switch ($State) {
            { $_ -in @('Passed', 'Applied', 'Agreed', 'ObservedActivity') } { 'state-ok' }
            { $_ -in @('Broken', 'Failed', 'Excluded', 'FilteredOut', 'NoObservedActivity', 'DifferentPermissions', 'MicrosoftOnly', 'ModelOnly') } { 'state-stop' }
            default { 'state-open' }
        }
    }
    function Get-Empty([string] $Text) { '<div class="empty-state">{0}</div>' -f (Enc $Text) }

    $verdictLabel = @{
        Applied = 'Applied'; Failed = 'Failed'; Excluded = 'Excluded'; FilteredOut = 'Filtered out'; NotTargeted = 'Not targeted'
        NotAssigned = 'Not assigned'; WaitingForDevice = 'Waiting for device'; NoResult = 'No result'; ResultNotCollected = 'Result not collected'
        NotEvaluated = 'Not evaluated'; AvailableOrUninstallIntent = 'Available or uninstall'
    }
    $verdictRank = @{ Failed = 0; Excluded = 1; FilteredOut = 2; WaitingForDevice = 3; NotEvaluated = 4; AvailableOrUninstallIntent = 5; NoResult = 6; ResultNotCollected = 7; NotTargeted = 8; NotAssigned = 9; Applied = 10 }

    $panels = [System.Text.StringBuilder]::new()
    $inspector = [System.Text.StringBuilder]::new()

    # Why didn't it apply?
    $chains = @(Get-IntuneAccessProperty $TenantRbac 'DeliveryChains' @() | Sort-Object @{ Expression = { if ($verdictRank.ContainsKey([string] $_.Verdict)) { $verdictRank[[string] $_.Verdict] } else { 99 } } }, DeviceName, WorkloadName)
    $chainRows = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $chains.Count; $i++) {
        $chain = $chains[$i]
        $key = "chain-$($i + 1)"
        $label = if ($verdictLabel.ContainsKey([string] $chain.Verdict)) { $verdictLabel[[string] $chain.Verdict] } else { [string] $chain.Verdict }
        Add-Row $chainRows $key 'delivery-chains' "$($chain.WorkloadName) on $($chain.DeviceName)" $chain.Summary $label $Icon.Devices
        $steps = ($chain.Steps | ForEach-Object {
            '<li class="{0}"><span class="step-state">{1}</span><strong>{2}</strong><p>{3}</p>{4}</li>' -f (Get-StateClass $_.State), (Enc $_.State), (Enc $_.Name), (Enc $_.Finding), $(if ($_.Evidence) { '<code class="raw-value">{0}</code>' -f (Enc $_.Evidence) } else { '' })
        }) -join ''
        $reference = if ($null -ne $chain.ErrorReference -and $chain.ErrorReference.Source) { '<h3>Error reference</h3><p>{0}: {1}</p><code class="raw-value">Source: {2}</code>' -f (Enc $chain.ErrorReference.Hex), (Enc $chain.ErrorReference.Meaning), (Enc $chain.ErrorReference.Source) } else { '' }
        $null = $inspector.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">WHY DIDN''T IT APPLY?</p><h2>{1}</h2><p class="wrap-value">{2} | {3}</p><div class="fact-grid"><span><small>Verdict</small><strong>{4}</strong></span><span><small>Stopped at</small><strong>{5}</strong></span></div><h3>Next check</h3><p>{6}</p><h3>Evidence chain</h3><ol class="chain-steps">{7}</ol>{8}<p class="evidence-note">{9}</p></section>' -f
            $key, (Enc $chain.WorkloadName), (Enc $chain.DeviceName), (Enc $chain.WorkloadType), (Enc $label), (Enc $(if ($chain.StoppedAt) { $chain.StoppedAt } else { 'Not stopped' })), (Enc $chain.NextCheck), $steps, $reference, (Enc $chain.EvidenceBoundary)))
    }
    $problemCount = @($chains | Where-Object Verdict -In @('Failed', 'Excluded', 'FilteredOut', 'WaitingForDevice')).Count
    $chainIntro = '<div class="insight-intro"><p>Every device and workload pair is followed from check-in, assignment, targeting, exclusion and filter through to what Intune reported. The verdict is the first link that fails or where the evidence stops. Problems are listed first; use the filter box to find a device or workload.</p><p><strong>{0}</strong> problems need attention out of <strong>{1}</strong> device and workload pairs.</p></div>' -f $problemCount, $chains.Count
    $null = $panels.AppendLine(('<section class="view-panel" data-view-panel="delivery-chains" hidden>{0}<div class="collection-list">{1}</div></section>' -f $chainIntro, $(if ($chains.Count) { $chainRows.ToString() } else { Get-Empty 'No device assignment explanations were collected. Include device intelligence to build delivery chains.' })))

    # What changed?
    $timeline = Get-IntuneAccessProperty $TenantRbac 'ChangeTimeline'
    $entries = @(Get-IntuneAccessProperty $timeline 'Entries' @())
    $timelineRows = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $entry = $entries[$i]
        $key = "timeline-$($i + 1)"
        $badge = if (@($entry.Correlated).Count) { "$($entry.Kind): followed by failures" } else { $entry.Kind }
        $when = if ($entry.TimeIsRange) { "By $(Format-InsightDate $entry.Time)" } else { Format-InsightDate $entry.Time }
        Add-Row $timelineRows $key 'change-timeline' "$($entry.Title): $($entry.Target)" "$when$(if ($entry.Actor) { ' | ' + $entry.Actor }) | $($entry.Source)" $badge $Icon.Calendar
        $details = (@($entry.Details) | Where-Object { $_ } | ForEach-Object { '<li>{0}</li>' -f (Enc $_) }) -join ''
        $correlated = if (@($entry.Correlated).Count) { '<h3>Followed by</h3><p class="correlation">{0}</p>' -f (Enc (@($entry.Correlated) -join ' ')) } else { '' }
        $null = $inspector.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">WHAT CHANGED?</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>When</small><strong>{3}</strong></span><span><small>Kind</small><strong>{4}</strong></span><span><small>Changed by</small><strong>{5}</strong></span><span><small>Source</small><strong>{6}</strong></span></div><h3>Details</h3><ul>{7}</ul>{8}</section>' -f
            $key, (Enc $entry.Title), (Enc $entry.Target), (Enc $when), (Enc $entry.Kind), (Enc $(if ($entry.Actor) { $entry.Actor } else { 'Not recorded' })), (Enc $entry.Source), $details, $correlated))
    }
    $baselineNote = if ([string] (Get-IntuneAccessProperty $timeline 'BaselineState' '') -eq 'NoBaseline') { ' No baseline snapshot was supplied, so only audit events and current failures are shown. Run Start-IntuneAccess with -BaselineSnapshotPath to add configuration and result changes.' } else { '' }
    $timelineIntro = '<div class="insight-intro"><p>Intune audit events, configuration differences between snapshots and changes in device results on one timeline. When a device reports a failure on the same workload within {0} hours of a change, the change is marked. That is timing, not proof of cause.{1}</p><p><strong>{2}</strong> configuration changes, <strong>{3}</strong> result changes, <strong>{4}</strong> followed by failures. {5} check-in and inventory refreshes are hidden.</p></div>' -f
        (Get-IntuneAccessProperty $timeline 'CorrelationHours' 72), (Enc $baselineNote), (Get-IntuneAccessProperty $timeline 'ConfigurationChanges' 0), (Get-IntuneAccessProperty $timeline 'OutcomeChanges' 0), (Get-IntuneAccessProperty $timeline 'CorrelatedChanges' 0), (Get-IntuneAccessProperty $timeline 'HiddenRefreshChanges' 0)
    $null = $panels.AppendLine(('<section class="view-panel" data-view-panel="change-timeline" hidden>{0}<div class="collection-list">{1}</div></section>' -f $timelineIntro, $(if ($entries.Count) { $timelineRows.ToString() } else { Get-Empty 'No audit events, snapshot changes or reported failures were available for the timeline.' })))

    # Change preview.
    $subjects = @(Get-IntuneAccessProperty $TenantRbac 'DependencyIndex' @())
    $dependencyRows = [System.Text.StringBuilder]::new()
    $typeLabel = @{ Group = 'Group'; AssignmentFilter = 'Assignment filter'; ScopeTag = 'Scope tag' }
    for ($i = 0; $i -lt $subjects.Count; $i++) {
        $subject = $subjects[$i]
        $key = "dependency-$($i + 1)"
        $flagCount = @($subject.Flags).Count
        $badge = if ($flagCount) { "$flagCount flag$(if ($flagCount -gt 1) { 's' })" } else { "$($subject.DependentCount) dependent$(if ($subject.DependentCount -ne 1) { 's' })" }
        $iconData = switch ($subject.SubjectType) { 'Group' { $Icon.Groups } 'AssignmentFilter' { $Icon.Lock } default { $Icon.Devices } }
        Add-Row $dependencyRows $key 'change-preview' $subject.Name "$($typeLabel[$subject.SubjectType]) | $($subject.DependentCount) dependent object$(if ($subject.DependentCount -ne 1) { 's' })" $badge $iconData
        $flags = (@($subject.Flags) | ForEach-Object { '<li>{0}</li>' -f (Enc $_) }) -join ''
        $dependents = (@($subject.Dependents) | ForEach-Object { '<li><strong>{0}</strong> <small>{1} | {2}</small></li>' -f (Enc $_.Name), (Enc $_.Relationship), (Enc $_.Kind) }) -join ''
        $null = $inspector.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">CHANGE PREVIEW</p><h2>{1}</h2><p class="wrap-value">{2} | {3}</p><div class="fact-grid"><span><small>Dependents</small><strong>{4}</strong></span><span><small>Resolution</small><strong>{5}</strong></span></div>{6}<h3>Affected if changed or deleted</h3><ul class="dependency-list">{7}</ul></section>' -f
            $key, (Enc $subject.Name), (Enc $typeLabel[$subject.SubjectType]), (Enc $subject.Id), $subject.DependentCount, (Enc $subject.ResolutionState), $(if ($flags) { "<h3>Review flags</h3><ul class=`"flag-list`">$flags</ul>" } else { '' }), $dependents))
    }
    $flagged = @($subjects | Where-Object { @($_.Flags).Count -gt 0 }).Count
    $dependencyIntro = '<div class="insight-intro"><p>Before you change or delete an Entra group, assignment filter or scope tag, see every collected policy, app, script, update and role assignment that depends on it. Flags highlight unreadable groups, scope tags no role assignment grants, and groups that control both access and targeting.</p><p><strong>{0}</strong> objects with flags out of <strong>{1}</strong>.</p></div>' -f $flagged, $subjects.Count
    $null = $panels.AppendLine(('<section class="view-panel" data-view-panel="change-preview" hidden>{0}<div class="collection-list">{1}</div></section>' -f $dependencyIntro, $(if ($subjects.Count) { $dependencyRows.ToString() } else { Get-Empty 'No dependencies were collected. Include the Assignment Explorer feature.' })))

    # Privilege usage.
    $usage = Get-IntuneAccessProperty $TenantRbac 'PrivilegeUsage'
    $usageRowsData = @(Get-IntuneAccessProperty $usage 'Rows' @())
    $usageRows = [System.Text.StringBuilder]::new()
    $usageLabel = @{ ObservedActivity = 'Used'; NoObservedActivity = 'No audited use'; NotEvaluated = 'Not evaluated' }
    for ($i = 0; $i -lt $usageRowsData.Count; $i++) {
        $row = $usageRowsData[$i]
        $key = "privilege-$($i + 1)"
        Add-Row $usageRows $key 'privilege-usage' "$($row.DisplayName): $($row.PermissionFamily)" "Write actions: $(@($row.WriteOperations) -join ', ')" $usageLabel[[string] $row.State] $Icon.User
        $activities = (@($row.ObservedActivities) | ForEach-Object { '<li>{0}</li>' -f (Enc $_) }) -join ''
        $null = $inspector.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">PRIVILEGE USAGE</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Permission family</small><strong>{3}</strong></span><span><small>State</small><strong>{4}</strong></span><span><small>Last activity</small><strong>{5}</strong></span></div><h3>Write actions allowed</h3><p>{6}</p><h3>Assessment</h3><p>{7}</p>{8}<p class="evidence-note">{9}</p></section>' -f
            $key, (Enc $row.DisplayName), (Enc $row.UserPrincipalName), (Enc $row.PermissionFamily), (Enc $usageLabel[[string] $row.State]), (Enc $(if (@($row.LastActivity).Count) { Format-InsightDate @($row.LastActivity)[0] } else { 'None in window' })), (Enc (@($row.WriteOperations) -join ', ')), (Enc $row.Reason), $(if ($activities) { "<h3>Audited activity</h3><ul>$activities</ul>" } else { '' }), (Enc (Get-IntuneAccessProperty $usage 'EvidenceBoundary' ''))))
    }
    $usageIntro = '<div class="insight-intro"><p>Each administrator''s Intune write permissions compared with the changes the Intune audit log shows they made in the last {0} days. Families with no audited use are least-privilege review prompts, not proof the permission is unnecessary. Reads are never audited, so read access is not judged.</p><p><strong>{1}</strong> permission families with no audited use.</p></div>' -f (Get-IntuneAccessProperty $usage 'WindowDays' 30), (Get-IntuneAccessProperty $usage 'NoObservedActivity' 0)
    $null = $panels.AppendLine(('<section class="view-panel" data-view-panel="privilege-usage" hidden>{0}<div class="collection-list">{1}</div></section>' -f $usageIntro, $(if ($usageRowsData.Count) { $usageRows.ToString() } else { Get-Empty 'No administrator write permissions or audit evidence were collected.' })))

    # Scoped permissions readiness.
    $readiness = Get-IntuneAccessProperty $TenantRbac 'ScopedReadiness'
    $readinessRowsData = @(Get-IntuneAccessProperty $readiness 'Rows' @())
    $readinessRows = [System.Text.StringBuilder]::new()
    $reconLabel = @{ Agreed = 'Agrees with Microsoft'; DifferentPermissions = 'Differs from Microsoft'; ModelOnly = 'IntuneAccess only'; ModelOnlyEmptyGroup = 'Empty group'; MicrosoftOnly = 'Microsoft only' }
    for ($i = 0; $i -lt $readinessRowsData.Count; $i++) {
        $row = $readinessRowsData[$i]
        $key = "scoped-$($i + 1)"
        $badge = if ([string] (Get-IntuneAccessProperty $readiness 'AssessmentState' '') -eq 'NotImported') { 'Predicted' } elseif ($reconLabel.ContainsKey([string] $row.ReconciliationState)) { $reconLabel[[string] $row.ReconciliationState] } else { [string] $row.ReconciliationState }
        Add-Row $readinessRows $key 'scoped-readiness' "$($row.Group): $($row.Resource)" "Scope tag $($row.ScopeTag) | loses $(@($row.LostPermissions) -join ', ')" $badge $Icon.Lock
        $null = $inspector.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">SCOPED PERMISSIONS</p><h2>{1}</h2><p class="wrap-value">{2} | scope tag {3}</p><div class="fact-grid"><span><small>Today (merged)</small><strong>{4}</strong></span><span><small>After Scoped permissions</small><strong>{5}</strong></span><span><small>Lost</small><strong>{6}</strong></span><span><small>Reconciliation</small><strong>{7}</strong></span></div><h3>Roles involved</h3><p>{8}</p><h3>Assessment</h3><p>{9}</p><p class="evidence-note">{10}</p></section>' -f
            $key, (Enc $row.Group), (Enc $row.Resource), (Enc $row.ScopeTag), (Enc (@($row.OldPermissions) -join ', ')), (Enc $(if (@($row.NewPermissions).Count) { @($row.NewPermissions) -join ', ' } else { 'None' })), (Enc (@($row.LostPermissions) -join ', ')), (Enc $badge), (Enc (@($row.Roles) -join ', ')), (Enc $row.Explanation), (Enc (Get-IntuneAccessProperty $readiness 'EvidenceBoundary' ''))))
    }
    $assessmentText = switch ([string] (Get-IntuneAccessProperty $readiness 'AssessmentState' 'NotImported')) {
        'NotImported' { 'No Permissions Assessment Report was imported. Export it from Tenant administration > Roles > Settings and run Start-IntuneAccess with -PermissionAssessmentPath to compare with Microsoft.' }
        'Empty' { 'The imported Permissions Assessment Report contained no rows.' }
        default { "Compared with the imported Permissions Assessment Report: $(Get-IntuneAccessProperty $readiness 'Agreed' 0) agreements and $(Get-IntuneAccessProperty $readiness 'Disagreements' 0) differences." }
    }
    $readinessIntro = '<div class="insight-intro"><p>Microsoft''s opt-in Scoped permissions setting stops Intune merging permissions across role assignments with different scope tags. Microsoft states the change cannot be reversed. This view shows which Admin Groups lose which permissions under each scope tag. IntuneAccess never reads or changes the setting.</p><p>{0}</p></div>' -f (Enc $assessmentText)
    $null = $panels.AppendLine(('<section class="view-panel" data-view-panel="scoped-readiness" hidden>{0}<div class="collection-list">{1}</div></section>' -f $readinessIntro, $(if ($readinessRowsData.Count) { $readinessRows.ToString() } else { Get-Empty 'No Admin Group is predicted to lose permissions when Scoped permissions is enabled.' })))

    $nav = @(
        @{ View = 'delivery-chains'; Title = "Why didn't it apply?"; Subtitle = 'Evidence chain from assignment to reported result'; Label = "Why didn't it apply?"; Small = 'Delivery chains'; Count = $problemCount; IconData = $Icon.Devices }
        @{ View = 'change-timeline'; Title = 'What changed?'; Subtitle = 'Audit events, configuration changes and results on one timeline'; Label = 'What changed?'; Small = 'Change timeline'; Count = $entries.Count; IconData = $Icon.Calendar }
        @{ View = 'change-preview'; Title = 'Change preview'; Subtitle = 'What depends on a group, filter or scope tag'; Label = 'Change preview'; Small = 'Before you change it'; Count = $flagged; IconData = $Icon.Groups }
        @{ View = 'privilege-usage'; Title = 'Privilege usage'; Subtitle = 'Write permissions compared with audited changes'; Label = 'Privilege usage'; Small = 'Least privilege'; Count = [int] (Get-IntuneAccessProperty $usage 'NoObservedActivity' 0); IconData = $Icon.User }
        @{ View = 'scoped-readiness'; Title = 'Scoped permissions readiness'; Subtitle = 'Who loses what when Scoped permissions is enabled'; Label = 'Scoped permissions'; Small = 'Readiness'; Count = $readinessRowsData.Count; IconData = $Icon.Lock }
    )
    $navHtml = ($nav | ForEach-Object {
        '<button class="nav-item" type="button" data-view="{0}" data-title="{1}" data-subtitle="{2}"><img src="{3}" alt=""><span><strong>{4}</strong><small>{5}</small></span><b class="nav-count">{6}</b></button>' -f $_.View, (Enc $_.Title), (Enc $_.Subtitle), $_.IconData, (Enc $_.Label), (Enc $_.Small), $_.Count
    }) -join "`n"

    [PSCustomObject] @{
        NavHtml       = $navHtml
        PanelsHtml    = $panels.ToString()
        InspectorHtml = $inspector.ToString()
        ProblemCount  = $problemCount
        CorrelatedChanges = [int] (Get-IntuneAccessProperty $timeline 'CorrelatedChanges' 0)
        FlaggedDependencies = $flagged
        UnusedPrivilege = [int] (Get-IntuneAccessProperty $usage 'NoObservedActivity' 0)
        ScopedReductions = $readinessRowsData.Count
    }
}
