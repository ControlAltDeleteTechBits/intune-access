function Get-IntuneAccessDependencyIndex {
    <#
    Lists every group, assignment filter and scope tag that collected Intune objects depend on,
    with the workloads and role assignments that would be affected by changing or deleting it.
    Built from collected evidence only; object families that were not collected are not shown.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Compact local helpers keep each dependency on one readable line.')]
    [CmdletBinding()]
    [OutputType([System.Array])]
    param([Parameter(Mandatory)] [object] $Collection)

    $workloadAssignments = @(Get-IntuneAccessProperty $Collection 'WorkloadAssignments' @())
    $workloads = @(Get-IntuneAccessProperty $Collection 'WorkloadObjects' @())
    $roleAssignments = @(Get-IntuneAccessProperty $Collection 'RoleAssignments' @())
    $collectedTags = @(Get-IntuneAccessProperty $Collection 'AllScopeTags' @()) + @(Get-IntuneAccessProperty $Collection 'ScopeTags' @())
    $subjects = @{}

    function Get-Subject([string] $Type, [string] $Id, [string] $Name, [string] $State = 'Resolved') {
        $key = "$Type|$Id"
        if (-not $subjects.ContainsKey($key)) {
            $subjects[$key] = [PSCustomObject] @{
                PSTypeName      = 'IntuneAccess.DependencySubject'
                SubjectType     = $Type
                Id              = $Id
                Name            = if ($Name) { $Name } elseif ($Type -eq 'ScopeTag') { "Scope tag ID $Id (name not collected)" } else { "[$Type $Id]" }
                ResolutionState = $State
                Dependents      = [System.Collections.Generic.List[object]]::new()
                Flags           = [System.Collections.Generic.List[string]]::new()
            }
        }
        elseif ($Name -and ($subjects[$key].Name -like '`[*' -or $subjects[$key].Name -like '*(name not collected)')) { $subjects[$key].Name = $Name }
        $subjects[$key]
    }
    function Add-Dependent($Subject, [string] $Kind, [string] $Name, [string] $Relationship, [string] $Id) {
        $Subject.Dependents.Add([PSCustomObject] @{ Kind = $Kind; Name = $Name; Relationship = $Relationship; Id = $Id })
    }

    foreach ($assignment in $workloadAssignments) {
        $groupId = [string] (Get-IntuneAccessProperty $assignment 'GroupId' '')
        if ($groupId) {
            $group = Get-IntuneAccessProperty $assignment 'Group'
            $subject = Get-Subject 'Group' $groupId ([string] (Get-IntuneAccessProperty $group 'DisplayName' '')) ([string] (Get-IntuneAccessProperty $group 'ResolutionState' 'NotCollected'))
            $relationship = if ($assignment.TargetType -eq 'Excluded group') { 'Excluded from' } else { "Included in ($($assignment.Intent))" }
            Add-Dependent $subject $assignment.WorkloadType $assignment.WorkloadName $relationship $assignment.WorkloadId
        }
        $filterId = [string] (Get-IntuneAccessProperty $assignment 'FilterId' '')
        if ($filterId) {
            $filter = Get-IntuneAccessProperty $assignment 'Filter'
            $subject = Get-Subject 'AssignmentFilter' $filterId ([string] (Get-IntuneAccessProperty $filter 'DisplayName' '')) $(if ($null -eq $filter) { 'NotCollected' } else { 'Resolved' })
            Add-Dependent $subject $assignment.WorkloadType $assignment.WorkloadName "$($assignment.FilterMode) filter on $($assignment.TargetType)" $assignment.WorkloadId
        }
    }

    foreach ($roleAssignment in $roleAssignments) {
        $roleName = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $roleAssignment 'RoleDefinition') 'DisplayName' '')
        $label = '{0} ({1})' -f $roleAssignment.Name, $roleName
        foreach ($group in @(Get-IntuneAccessProperty $roleAssignment 'AdminGroups' @())) {
            $subject = Get-Subject 'Group' ([string] $group.Id) ([string] $group.DisplayName) ([string] (Get-IntuneAccessProperty $group 'ResolutionState' 'Resolved'))
            Add-Dependent $subject 'Role assignment' $label 'Admin Group of' $roleAssignment.Id
        }
        foreach ($group in @(Get-IntuneAccessProperty $roleAssignment 'ScopeGroups' @())) {
            $subject = Get-Subject 'Group' ([string] $group.Id) ([string] $group.DisplayName) ([string] (Get-IntuneAccessProperty $group 'ResolutionState' 'Resolved'))
            Add-Dependent $subject 'Role assignment' $label 'Scope (Groups) of' $roleAssignment.Id
        }
        foreach ($tag in @(Get-IntuneAccessProperty $roleAssignment 'ScopeTags' @())) {
            $subject = Get-Subject 'ScopeTag' ([string] $tag.Id) ([string] $tag.DisplayName)
            Add-Dependent $subject 'Role assignment' $label 'Scope tag on' $roleAssignment.Id
        }
    }

    $tagNames = @{}
    foreach ($tag in $collectedTags) { $tagNames[[string] $tag.Id] = [string] $tag.DisplayName }
    foreach ($workload in $workloads) {
        foreach ($tagId in @(Get-IntuneAccessProperty $workload 'ScopeTagIds' @())) {
            $id = [string] $tagId
            $name = if ($tagNames.ContainsKey($id)) { $tagNames[$id] } elseif ($id -eq '0') { 'Default' } else { '' }
            $subject = Get-Subject 'ScopeTag' $id $name
            Add-Dependent $subject $workload.WorkloadType $workload.Name 'Tagged with' $workload.Id
        }
    }

    $assignmentsWithoutTags = @($roleAssignments | Where-Object {
        [string] (Get-IntuneAccessProperty $_ 'ScopeTagDataState' 'Available') -ne 'Missing' -and @(Get-IntuneAccessProperty (Get-IntuneAccessProperty $_ 'RawIds') 'ScopeTagIds' @()).Count -eq 0
    }).Count

    foreach ($subject in $subjects.Values) {
        $dependents = @($subject.Dependents)
        if ($subject.SubjectType -eq 'Group' -and $subject.ResolutionState -eq 'Unresolved') {
            $subject.Flags.Add('The group could not be read. It may have been deleted, or the signed-in account cannot see it. Assignments that reference it may not behave as intended.')
        }
        if ($subject.SubjectType -eq 'Group') {
            $included = @($dependents | Where-Object Relationship -Like 'Included*').Count
            $excluded = @($dependents | Where-Object Relationship -EQ 'Excluded from').Count
            if ($included -gt 0 -and $excluded -gt 0) { $subject.Flags.Add("Used as an inclusion on $included workload assignment(s) and an exclusion on $excluded. Membership changes affect both directions.") }
            if (@($dependents | Where-Object Kind -EQ 'Role assignment').Count -gt 0 -and ($included + $excluded) -gt 0) { $subject.Flags.Add('Controls both administrative access and workload targeting. Changing membership changes who can administer and what is delivered.') }
        }
        if ($subject.SubjectType -eq 'AssignmentFilter' -and $subject.ResolutionState -eq 'NotCollected') {
            $subject.Flags.Add('The filter definition was not collected, so its rule cannot be reviewed here.')
        }
        if ($subject.SubjectType -eq 'ScopeTag') {
            $taggedObjects = @($dependents | Where-Object Relationship -EQ 'Tagged with').Count
            $taggedRoles = @($dependents | Where-Object Kind -EQ 'Role assignment').Count
            if ($taggedObjects -gt 0 -and $taggedRoles -eq 0 -and $subject.Id -ne '0') {
                $visibility = if ($assignmentsWithoutTags -gt 0) { "only administrators whose role assignments have no scope tags ($assignmentsWithoutTags assignment(s)) can see them" } else { 'no collected role assignment grants visibility of them' }
                $subject.Flags.Add("$taggedObjects collected object(s) use this tag, but no role assignment includes it; $visibility.")
            }
        }
    }

    @($subjects.Values | ForEach-Object {
        $_ | Add-Member -NotePropertyName DependentCount -NotePropertyValue @($_.Dependents).Count -Force
        $_.Dependents = @($_.Dependents | Sort-Object Kind, Name)
        $_.Flags = @($_.Flags)
        $_
    } | Sort-Object @{ Expression = { @($_.Flags).Count }; Descending = $true }, @{ Expression = 'DependentCount'; Descending = $true }, Name)
}

function Get-IntuneAccessPrivilegeUsage {
    <#
    Compares each administrator's write permissions with Intune audit activity in the collected window.
    Read actions are not audited by Intune, so they are never reported as unused. Audit categories are
    mapped to RBAC permission families only where the relationship is direct; everything else is NotEvaluated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Collection,
        [ValidateRange(1, 730)] [int] $WindowDays = 30
    )

    # Audit category (Intune admin centre pane) > RBAC permission family.
    $categoryMap = @{
        'DeviceConfiguration' = 'DeviceConfigurations'
        'Compliance'          = 'DeviceCompliancePolices'
        'Device'              = 'ManagedDevices'
        'Application'         = 'MobileApps'
        'Role'                = 'Roles'
    }
    $events = @(Get-IntuneAccessProperty $Collection 'AuditEvents' @())
    $auditState = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $Collection 'AuditCollectionStatus') 'State' $(if ($events.Count) { 'Available' } else { 'NotCollected' }))
    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($administrator in @(Get-IntuneAccessProperty $Collection 'Administrators' @())) {
        $upn = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $administrator 'User') 'UserPrincipalName' '')
        $actorEvents = @($events | Where-Object { [string] $_.ActorUserPrincipalName -ieq $upn })
        $writePermissions = @(Get-IntuneAccessProperty $administrator 'EffectivePermissions' @() | Where-Object { $_.State -eq 'Allowed' -and $_.Operation -notmatch '^Read' })
        foreach ($family in @($writePermissions | Group-Object { ([string] $_.Resource) -replace '\s', '' })) {
            $mappedCategories = @($categoryMap.Keys | Where-Object { $categoryMap[$_] -eq $family.Name })
            $familyEvents = @($actorEvents | Where-Object { $_.Category -in $mappedCategories })
            $state = if ($auditState -ne 'Available') { 'NotEvaluated' }
                elseif ($mappedCategories.Count -eq 0) { 'NotEvaluated' }
                elseif ($familyEvents.Count -gt 0) { 'ObservedActivity' }
                else { 'NoObservedActivity' }
            $reason = switch ($state) {
                'ObservedActivity' { "$($familyEvents.Count) audited change(s) by this administrator in the window." }
                'NoObservedActivity' { "No audited change by this administrator in the last $WindowDays days. Review whether these write permissions are still needed." }
                default { if ($auditState -ne 'Available') { 'Audit evidence was not collected.' } else { 'This permission family has no direct audit category mapping, so usage cannot be judged.' } }
            }
            $rows.Add([PSCustomObject] @{
                PSTypeName         = 'IntuneAccess.PrivilegeUsage'
                UserPrincipalName  = $upn
                DisplayName        = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $administrator 'User') 'DisplayName' $upn)
                PermissionFamily   = [string] @($family.Group)[0].Resource
                WriteOperations    = @($family.Group | ForEach-Object Operation | Sort-Object -Unique)
                State              = $state
                ObservedActivities = @($familyEvents | ForEach-Object Activity | Sort-Object -Unique)
                LastActivity       = @($familyEvents | Sort-Object ActivityDateTime -Descending | Select-Object -First 1 | ForEach-Object ActivityDateTime)
                Reason             = $reason
            })
        }
    }

    [PSCustomObject] @{
        PSTypeName      = 'IntuneAccess.PrivilegeUsageReview'
        Rows            = @($rows | Sort-Object @{ Expression = { switch ($_.State) { 'NoObservedActivity' { 0 } 'ObservedActivity' { 1 } default { 2 } } } }, DisplayName, PermissionFamily)
        NoObservedActivity = @($rows | Where-Object State -EQ 'NoObservedActivity').Count
        WindowDays      = $WindowDays
        AuditState      = $auditState
        EvidenceBoundary = 'Intune audits changes, not reads, so read permissions are never reported as unused. Absence of audited activity in the window is a review prompt, not proof that a permission is unnecessary. Microsoft Entra roles and activity outside Intune are not included.'
    }
}
