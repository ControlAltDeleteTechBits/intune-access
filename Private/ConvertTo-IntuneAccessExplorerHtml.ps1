function ConvertTo-IntuneAccessExplorerHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $TenantRbac
    )

    function ConvertTo-ExplorerText {
        param([AllowNull()] [object] $Value)
        return [System.Net.WebUtility]::HtmlEncode([string] $Value)
    }

    function Get-ExplorerAsset {
        param(
            [Parameter(Mandatory)] [string] $RelativePath,
            [Parameter(Mandatory)] [string] $MimeType
        )
        $assetPath = Join-Path -Path $script:IntuneAccessModuleRoot -ChildPath $RelativePath
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) { return '' }
        return "data:$MimeType;base64,$([Convert]::ToBase64String([IO.File]::ReadAllBytes($assetPath)))"
    }

    function Add-ExplorerRow {
        param(
            [Parameter(Mandatory)] [System.Text.StringBuilder] $Builder,
            [Parameter(Mandatory)] [string] $Key,
            [Parameter(Mandatory)] [string] $View,
            [Parameter(Mandatory)] [string] $Title,
            [AllowEmptyString()] [string] $Meta,
            [AllowEmptyString()] [string] $Badge,
            [Parameter(Mandatory)] [string] $Icon
        )
        $searchText = ConvertTo-ExplorerText "$Title $Meta $Badge"
        $null = $Builder.AppendLine(('<button class="object-row" type="button" data-inspect="{0}" data-view-target="{1}" data-search="{2}"><img src="{3}" alt=""><span class="object-copy"><strong>{4}</strong><small>{5}</small></span><span class="object-badge">{6}</span></button>' -f
            $Key, $View, $searchText, $Icon, (ConvertTo-ExplorerText $Title), (ConvertTo-ExplorerText $Meta), (ConvertTo-ExplorerText $Badge)))
    }

    function New-ExplorerLink {
        param(
            [Parameter(Mandatory)] [string] $Key,
            [Parameter(Mandatory)] [string] $View,
            [Parameter(Mandatory)] [string] $Label,
            [AllowEmptyString()] [string] $Meta
        )
        return '<button class="relation-link" type="button" data-inspect="{0}" data-view-target="{1}"><strong>{2}</strong><small>{3}</small></button>' -f
            $Key, $View, (ConvertTo-ExplorerText $Label), (ConvertTo-ExplorerText $Meta)
    }

    function New-ExplorerEmptyState {
        param([Parameter(Mandatory)] [string] $Text)
        return '<div class="empty-state">{0}</div>' -f (ConvertTo-ExplorerText $Text)
    }

    function Get-ExplorerEvidenceLabel {
        param([AllowNull()] [string] $State)
        switch ($State) {
            'ConfirmedAssignment' { 'Confirmed assignment' }
            'ExcludedTarget' { 'Excluded target' }
            'NotEvaluated' { 'Not evaluated' }
            'MissingData' { 'Missing data' }
            default { $State }
        }
    }

    function ConvertTo-ExplorerDateText {
        param([AllowNull()] [object] $Value)
        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) { return 'Not returned' }
        try {
            return ([DateTimeOffset]::Parse([string] $Value)).ToString('dd MMM yyyy HH:mm zzz', [Globalization.CultureInfo]::GetCultureInfo('en-GB'))
        }
        catch {
            return [string] $Value
        }
    }

    $tenant = Get-IntuneAccessProperty $TenantRbac 'Tenant'
    $administrators = @(Get-IntuneAccessProperty $TenantRbac 'Administrators' @())
    $adminGroups = @(Get-IntuneAccessProperty $TenantRbac 'AdminGroups' @())
    $assignments = @(Get-IntuneAccessProperty $TenantRbac 'RoleAssignments' @())
    $roles = @(Get-IntuneAccessProperty $TenantRbac 'RoleDefinitions' @())
    $scopeGroups = @(Get-IntuneAccessProperty $TenantRbac 'ScopeGroups' @())
    $scopeTags = @(Get-IntuneAccessProperty $TenantRbac 'ScopeTags' @())
    $permissions = @(Get-IntuneAccessProperty $TenantRbac 'Permissions' @())
    $memberships = @(Get-IntuneAccessProperty $TenantRbac 'Memberships' @())
    $workloadObjects = @(Get-IntuneAccessProperty $TenantRbac 'WorkloadObjects' @())
    $workloadAssignments = @(Get-IntuneAccessProperty $TenantRbac 'WorkloadAssignments' @())
    $workloadGroups = @(Get-IntuneAccessProperty $TenantRbac 'WorkloadGroups' @())
    $assignmentFilters = @(Get-IntuneAccessProperty $TenantRbac 'AssignmentFilters' @())
    $workloadCollectionStatus = @(Get-IntuneAccessProperty $TenantRbac 'WorkloadCollectionStatus' @())
    $managedDevices = @(Get-IntuneAccessProperty $TenantRbac 'ManagedDevices' @())
    $managedUsers = @(Get-IntuneAccessProperty $TenantRbac 'ManagedUsers' @())
    $deploymentOutcomes = @(Get-IntuneAccessProperty $TenantRbac 'DeploymentOutcomes' @())
    $outcomeCollectionStatus = @(Get-IntuneAccessProperty $TenantRbac 'OutcomeCollectionStatus' @())
    $snapshotComparison = Get-IntuneAccessProperty $TenantRbac 'SnapshotComparison'
    $snapshotChanges = @(if ($null -ne $snapshotComparison) { Get-IntuneAccessProperty $snapshotComparison 'Changes' @() })
    $policySettings = @(Get-IntuneAccessProperty $TenantRbac 'PolicySettings' @())
    $policyConflictFindings = @(Get-IntuneAccessProperty $TenantRbac 'PolicyConflictFindings' @())
    $policyConflictCollectionStatus = @(Get-IntuneAccessProperty $TenantRbac 'PolicyConflictCollectionStatus' @())
    $auditEvents = @(Get-IntuneAccessProperty $TenantRbac 'AuditEvents' @())
    $auditCollectionStatus = Get-IntuneAccessProperty $TenantRbac 'AuditCollectionStatus'
    $warnings = @(Get-IntuneAccessProperty $TenantRbac 'Warnings' @())
    $tenantName = [string] (Get-IntuneAccessProperty $tenant 'DisplayName' 'Unknown tenant')
    $generated = [DateTimeOffset] (Get-IntuneAccessProperty $TenantRbac 'GeneratedAt' ([DateTimeOffset]::Now))
    $generatedText = $generated.ToString('dd MMMM yyyy HH:mm zzz', [Globalization.CultureInfo]::GetCultureInfo('en-GB'))

    $spaceFont = Get-ExplorerAsset -RelativePath 'Assets\Fonts\SpaceGrotesk-Variable.ttf' -MimeType 'font/ttf'
    $plexRegular = Get-ExplorerAsset -RelativePath 'Assets\Fonts\IBMPlexMono-Regular.ttf' -MimeType 'font/ttf'
    $plexSemiBold = Get-ExplorerAsset -RelativePath 'Assets\Fonts\IBMPlexMono-SemiBold.ttf' -MimeType 'font/ttf'
    $iconUser = Get-ExplorerAsset -RelativePath 'Assets\Icons\user-circle.svg' -MimeType 'image/svg+xml'
    $iconGroups = Get-ExplorerAsset -RelativePath 'Assets\Icons\users-three.svg' -MimeType 'image/svg+xml'
    $iconRole = Get-ExplorerAsset -RelativePath 'Assets\Icons\shield-check.svg' -MimeType 'image/svg+xml'
    $iconDevices = Get-ExplorerAsset -RelativePath 'Assets\Icons\devices.svg' -MimeType 'image/svg+xml'
    $iconTenant = Get-ExplorerAsset -RelativePath 'Assets\Icons\buildings.svg' -MimeType 'image/svg+xml'
    $iconCalendar = Get-ExplorerAsset -RelativePath 'Assets\Icons\calendar-blank.svg' -MimeType 'image/svg+xml'
    $iconLock = Get-ExplorerAsset -RelativePath 'Assets\Icons\lock.svg' -MimeType 'image/svg+xml'
    $iconQuestion = Get-ExplorerAsset -RelativePath 'Assets\Icons\question.svg' -MimeType 'image/svg+xml'
    $iconLightbulb = Get-ExplorerAsset -RelativePath 'Assets\Icons\lightbulb.svg' -MimeType 'image/svg+xml'

    $fontCss = if ($spaceFont -and $plexRegular -and $plexSemiBold) {
        "@font-face{font-family:'Space Grotesk';src:url('$spaceFont') format('truetype');font-weight:300 700;font-style:normal;font-display:swap}@font-face{font-family:'IBM Plex Mono';src:url('$plexRegular') format('truetype');font-weight:400;font-style:normal;font-display:swap}@font-face{font-family:'IBM Plex Mono';src:url('$plexSemiBold') format('truetype');font-weight:600;font-style:normal;font-display:swap}"
    }
    else { '' }

    $userKeys = @{}
    $groupKeys = @{}
    $assignmentKeys = @{}
    $roleKeys = @{}
    $scopeGroupKeys = @{}
    $scopeTagKeys = @{}
    $permissionKeys = @{}
    $workloadKeys = @{}
    $workloadAssignmentKeys = @{}
    $workloadGroupKeys = @{}
    $filterKeys = @{}
    $managedDeviceKeys = @{}
    $managedUserKeys = @{}
    $deploymentOutcomeKeys = @{}
    $snapshotChangeKeys = @{}
    $policySettingKeys = @{}
    $policyConflictKeys = @{}
    $auditEventKeys = @{}
    for ($index = 0; $index -lt $administrators.Count; $index++) { $userKeys[[string] $administrators[$index].User.Id] = "administrator-$($index + 1)" }
    for ($index = 0; $index -lt $adminGroups.Count; $index++) { $groupKeys[[string] $adminGroups[$index].Id] = "admin-group-$($index + 1)" }
    for ($index = 0; $index -lt $assignments.Count; $index++) { $assignmentKeys[[string] $assignments[$index].Id] = "assignment-$($index + 1)" }
    for ($index = 0; $index -lt $roles.Count; $index++) { $roleKeys[[string] $roles[$index].Id] = "role-$($index + 1)" }
    for ($index = 0; $index -lt $scopeGroups.Count; $index++) { $scopeGroupKeys[[string] $scopeGroups[$index].Id] = "scope-group-$($index + 1)" }
    for ($index = 0; $index -lt $scopeTags.Count; $index++) { $scopeTagKeys[[string] $scopeTags[$index].Id] = "scope-tag-$($index + 1)" }
    for ($index = 0; $index -lt $permissions.Count; $index++) { $permissionKeys[[string] $permissions[$index].RawAction] = "permission-$($index + 1)" }
    for ($index = 0; $index -lt $workloadObjects.Count; $index++) { $workloadKeys[[string] $workloadObjects[$index].Id] = "workload-$($index + 1)" }
    for ($index = 0; $index -lt $workloadAssignments.Count; $index++) { $workloadAssignmentKeys["$($workloadAssignments[$index].WorkloadId)::$($workloadAssignments[$index].Id)"] = "workload-assignment-$($index + 1)" }
    for ($index = 0; $index -lt $workloadGroups.Count; $index++) { $workloadGroupKeys[[string] $workloadGroups[$index].Id] = "workload-group-$($index + 1)" }
    for ($index = 0; $index -lt $assignmentFilters.Count; $index++) { $filterKeys[[string] $assignmentFilters[$index].Id] = "assignment-filter-$($index + 1)" }
    for ($index = 0; $index -lt $managedDevices.Count; $index++) { $managedDeviceKeys[[string] $managedDevices[$index].Id] = "managed-device-$($index + 1)" }
    for ($index = 0; $index -lt $managedUsers.Count; $index++) { $managedUserKeys[[string] $managedUsers[$index].UserPrincipalName] = "managed-user-$($index + 1)" }
    for ($index = 0; $index -lt $deploymentOutcomes.Count; $index++) { $deploymentOutcomeKeys["$($deploymentOutcomes[$index].WorkloadId)::$($deploymentOutcomes[$index].Id)"] = "deployment-outcome-$($index + 1)" }
    for ($index = 0; $index -lt $snapshotChanges.Count; $index++) { $snapshotChangeKeys[$index] = "snapshot-change-$($index + 1)" }
    for ($index = 0; $index -lt $policySettings.Count; $index++) { $policySettingKeys[[string] $policySettings[$index].Id] = "policy-setting-$($index + 1)" }
    for ($index = 0; $index -lt $policyConflictFindings.Count; $index++) { $policyConflictKeys[[string] $policyConflictFindings[$index].Id] = "policy-conflict-$($index + 1)" }
    for ($index = 0; $index -lt $auditEvents.Count; $index++) { $auditEventKeys[[string] $auditEvents[$index].Id] = "audit-event-$($index + 1)" }

    $initialUpn = [string] (Get-IntuneAccessProperty $TenantRbac 'InitialUserPrincipalName')
    $initialAdministrator = $administrators | Where-Object { $_.User.UserPrincipalName -eq $initialUpn } | Select-Object -First 1
    if ($null -eq $initialAdministrator -and $administrators.Count -gt 0) { $initialAdministrator = $administrators[0] }
    $initialKey = if ($null -ne $initialAdministrator) { [string] $userKeys[[string] $initialAdministrator.User.Id] } else { '' }

    $administratorRows = [System.Text.StringBuilder]::new()
    $groupRows = [System.Text.StringBuilder]::new()
    $assignmentRows = [System.Text.StringBuilder]::new()
    $roleRows = [System.Text.StringBuilder]::new()
    $scopeGroupRows = [System.Text.StringBuilder]::new()
    $scopeTagRows = [System.Text.StringBuilder]::new()
    $permissionRows = [System.Text.StringBuilder]::new()
    $workloadRows = [System.Text.StringBuilder]::new()
    $workloadAssignmentRows = [System.Text.StringBuilder]::new()
    $workloadGroupRows = [System.Text.StringBuilder]::new()
    $filterRows = [System.Text.StringBuilder]::new()
    $managedDeviceRows = [System.Text.StringBuilder]::new()
    $managedUserRows = [System.Text.StringBuilder]::new()
    $deploymentOutcomeRows = [System.Text.StringBuilder]::new()
    $snapshotChangeRows = [System.Text.StringBuilder]::new()
    $policySettingRows = [System.Text.StringBuilder]::new()
    $policyConflictRows = [System.Text.StringBuilder]::new()
    $auditEventRows = [System.Text.StringBuilder]::new()
    $inspectorPanels = [System.Text.StringBuilder]::new()

    foreach ($administrator in $administrators) {
        $user = $administrator.User
        $key = $userKeys[[string] $user.Id]
        Add-ExplorerRow -Builder $administratorRows -Key $key -View 'administrators' -Title ([string] $user.DisplayName) -Meta ([string] $user.UserPrincipalName) -Badge "$(@($administrator.RoleAssignments).Count) assignments" -Icon $iconUser

        $groupLinks = @($administrator.AdminGroupMemberships | ForEach-Object {
            if ($groupKeys.ContainsKey([string] $_.GroupId)) { New-ExplorerLink -Key $groupKeys[[string] $_.GroupId] -View 'admin-groups' -Label $_.GroupName -Meta "$($_.MembershipType) membership" }
        }) -join ''
        $assignmentLinks = @($administrator.RoleAssignments | ForEach-Object {
            if ($assignmentKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $assignmentKeys[[string] $_.Id] -View 'assignments' -Label $_.Name -Meta $_.RoleDefinition.DisplayName }
        }) -join ''
        $permissionLinks = @($administrator.EffectivePermissions | ForEach-Object {
            if ($permissionKeys.ContainsKey([string] $_.RawAction)) { New-ExplorerLink -Key $permissionKeys[[string] $_.RawAction] -View 'permissions' -Label "$($_.Resource): $($_.Operation)" -Meta $_.State }
        }) -join ''
        if (-not $groupLinks) { $groupLinks = New-ExplorerEmptyState 'No connected Admin Group was returned.' }
        if (-not $assignmentLinks) { $assignmentLinks = New-ExplorerEmptyState 'No matching role assignment was returned.' }
        if (-not $permissionLinks) { $permissionLinks = New-ExplorerEmptyState 'No effective Intune RBAC permission was confirmed.' }

        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">ADMINISTRATOR</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Account</small><strong>{3}</strong></span><span><small>Confirmed assignments</small><strong>{4}</strong></span><span><small>Review assignments</small><strong>{5}</strong></span><span><small>Effective permissions</small><strong>{6}</strong></span></div><h3>Admin Groups</h3><div class="relation-list">{7}</div><h3>Role assignments</h3><div class="relation-list">{8}</div><h3>Permissions</h3><div class="relation-list">{9}</div></section>' -f
            $key, (ConvertTo-ExplorerText $user.DisplayName), (ConvertTo-ExplorerText $user.UserPrincipalName), (ConvertTo-ExplorerText $user.UserType), $administrator.ConfirmedAssignments, $administrator.ReviewAssignments, @($administrator.EffectivePermissions).Count, $groupLinks, $assignmentLinks, $permissionLinks))
    }

    foreach ($group in $adminGroups) {
        $key = $groupKeys[[string] $group.Id]
        $groupMemberships = @($memberships | Where-Object GroupId -EQ $group.Id)
        $groupAssignments = @($assignments | Where-Object { $group.Id -in @($_.RawIds.AdminGroupIds) })
        Add-ExplorerRow -Builder $groupRows -Key $key -View 'admin-groups' -Title ([string] $group.DisplayName) -Meta ([string] $group.Description) -Badge "$($groupMemberships.Count) users" -Icon $iconGroups
        $memberLinks = @($groupMemberships | ForEach-Object {
            if ($userKeys.ContainsKey([string] $_.User.Id)) { New-ExplorerLink -Key $userKeys[[string] $_.User.Id] -View 'administrators' -Label $_.User.DisplayName -Meta "$($_.MembershipType) membership" }
        }) -join ''
        $linkedAssignments = @($groupAssignments | ForEach-Object {
            if ($assignmentKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $assignmentKeys[[string] $_.Id] -View 'assignments' -Label $_.Name -Meta $_.RoleDefinition.DisplayName }
        }) -join ''
        if (-not $memberLinks) { $memberLinks = New-ExplorerEmptyState 'No user was returned from this Admin Group.' }
        if (-not $linkedAssignments) { $linkedAssignments = New-ExplorerEmptyState 'No connected assignment was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">ADMIN GROUP</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Users</small><strong>{3}</strong></span><span><small>Assignments</small><strong>{4}</strong></span><span><small>Resolution</small><strong>{5}</strong></span></div><h3>Administrators</h3><div class="relation-list">{6}</div><h3>Role assignments</h3><div class="relation-list">{7}</div></section>' -f
            $key, (ConvertTo-ExplorerText $group.DisplayName), (ConvertTo-ExplorerText $group.Description), $groupMemberships.Count, $groupAssignments.Count, (ConvertTo-ExplorerText $group.ResolutionState), $memberLinks, $linkedAssignments))
    }

    foreach ($assignment in $assignments) {
        $key = $assignmentKeys[[string] $assignment.Id]
        Add-ExplorerRow -Builder $assignmentRows -Key $key -View 'assignments' -Title ([string] $assignment.Name) -Meta ([string] $assignment.RoleDefinition.DisplayName) -Badge "$(@($assignment.Permissions).Count) actions" -Icon $iconRole
        $roleLink = if ($roleKeys.ContainsKey([string] $assignment.RoleDefinition.Id)) { New-ExplorerLink -Key $roleKeys[[string] $assignment.RoleDefinition.Id] -View 'roles' -Label $assignment.RoleDefinition.DisplayName -Meta $(if ($assignment.RoleDefinition.IsBuiltIn) { 'Built-in role' } else { 'Custom role' }) } else { New-ExplorerEmptyState 'The role definition was not resolved.' }
        $adminGroupLinks = @($assignment.AdminGroups | ForEach-Object { if ($groupKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $groupKeys[[string] $_.Id] -View 'admin-groups' -Label $_.DisplayName -Meta 'Admin Group' } }) -join ''
        $scopeGroupLinks = @($assignment.ScopeGroups | ForEach-Object { if ($scopeGroupKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $scopeGroupKeys[[string] $_.Id] -View 'scope-groups' -Label $_.DisplayName -Meta 'Scope Group' } }) -join ''
        $scopeTagLinks = @($assignment.ScopeTags | ForEach-Object { if ($scopeTagKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $scopeTagKeys[[string] $_.Id] -View 'scope-tags' -Label $_.DisplayName -Meta 'Scope Tag' } }) -join ''
        $permissionLinks = @($assignment.Permissions | ForEach-Object { $action = [string] $_; if ($permissionKeys.ContainsKey($action)) { $friendly = ConvertFrom-IntuneAccessActionName -Action $action; New-ExplorerLink -Key $permissionKeys[$action] -View 'permissions' -Label "$($friendly.Resource): $($friendly.Operation)" -Meta $action } }) -join ''
        if (-not $adminGroupLinks) { $adminGroupLinks = New-ExplorerEmptyState 'No Admin Group was returned.' }
        if (-not $scopeGroupLinks) { $scopeGroupLinks = New-ExplorerEmptyState "Scope type: $($assignment.ScopeType)" }
        if (-not $scopeTagLinks) { $scopeTagLinks = New-ExplorerEmptyState 'No explicit Scope Tag was returned.' }
        if (-not $permissionLinks) { $permissionLinks = New-ExplorerEmptyState 'No permission action was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">ROLE ASSIGNMENT</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Scope type</small><strong>{3}</strong></span><span><small>Permission actions</small><strong>{4}</strong></span><span><small>Source</small><strong>{5}</strong></span></div><h3>Role</h3><div class="relation-list">{6}</div><h3>Admin Groups</h3><div class="relation-list">{7}</div><h3>Scope Groups</h3><div class="relation-list">{8}</div><h3>Scope Tags</h3><div class="relation-list">{9}</div><h3>Permissions</h3><div class="relation-list">{10}</div></section>' -f
            $key, (ConvertTo-ExplorerText $assignment.Name), (ConvertTo-ExplorerText $assignment.Description), (ConvertTo-ExplorerText $assignment.ScopeType), @($assignment.Permissions).Count, (ConvertTo-ExplorerText $assignment.SourceApiVersion), $roleLink, $adminGroupLinks, $scopeGroupLinks, $scopeTagLinks, $permissionLinks))
    }

    foreach ($role in $roles) {
        $key = $roleKeys[[string] $role.Id]
        $roleAssignments = @($assignments | Where-Object { $_.RoleDefinition.Id -eq $role.Id })
        $roleActions = @(Get-IntuneAccessAllowedActions -RoleDefinition $role)
        Add-ExplorerRow -Builder $roleRows -Key $key -View 'roles' -Title ([string] $role.DisplayName) -Meta $(if ($role.IsBuiltIn) { 'Built-in Intune role' } else { 'Custom Intune role' }) -Badge "$($roleAssignments.Count) assignments" -Icon $iconRole
        $linkedAssignments = @($roleAssignments | ForEach-Object { New-ExplorerLink -Key $assignmentKeys[[string] $_.Id] -View 'assignments' -Label $_.Name -Meta $_.ScopeType }) -join ''
        $permissionLinks = @($roleActions | ForEach-Object { $action = [string] $_; if ($permissionKeys.ContainsKey($action)) { $friendly = ConvertFrom-IntuneAccessActionName -Action $action; New-ExplorerLink -Key $permissionKeys[$action] -View 'permissions' -Label "$($friendly.Resource): $($friendly.Operation)" -Meta $action } }) -join ''
        if (-not $linkedAssignments) { $linkedAssignments = New-ExplorerEmptyState 'No connected assignment was returned.' }
        if (-not $permissionLinks) { $permissionLinks = New-ExplorerEmptyState 'No permission action was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">INTUNE ROLE</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Role type</small><strong>{3}</strong></span><span><small>Assignments</small><strong>{4}</strong></span><span><small>Actions</small><strong>{5}</strong></span></div><h3>Role assignments</h3><div class="relation-list">{6}</div><h3>Permissions</h3><div class="relation-list">{7}</div></section>' -f
            $key, (ConvertTo-ExplorerText $role.DisplayName), (ConvertTo-ExplorerText $role.Description), $(if ($role.IsBuiltIn) { 'Built-in' } else { 'Custom' }), $roleAssignments.Count, $roleActions.Count, $linkedAssignments, $permissionLinks))
    }

    foreach ($scopeGroup in $scopeGroups) {
        $key = $scopeGroupKeys[[string] $scopeGroup.Id]
        $linked = @($assignments | Where-Object { $scopeGroup.Id -in @($_.RawIds.ScopeGroupIds) })
        Add-ExplorerRow -Builder $scopeGroupRows -Key $key -View 'scope-groups' -Title ([string] $scopeGroup.DisplayName) -Meta ([string] $scopeGroup.Description) -Badge "$($linked.Count) assignments" -Icon $iconGroups
        $links = @($linked | ForEach-Object { New-ExplorerLink -Key $assignmentKeys[[string] $_.Id] -View 'assignments' -Label $_.Name -Meta $_.RoleDefinition.DisplayName }) -join ''
        if (-not $links) { $links = New-ExplorerEmptyState 'No connected assignment was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">SCOPE GROUP</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Assignments</small><strong>{3}</strong></span><span><small>Resolution</small><strong>{4}</strong></span></div><h3>Role assignments</h3><div class="relation-list">{5}</div></section>' -f $key, (ConvertTo-ExplorerText $scopeGroup.DisplayName), (ConvertTo-ExplorerText $scopeGroup.Description), $linked.Count, (ConvertTo-ExplorerText $scopeGroup.ResolutionState), $links))
    }

    foreach ($scopeTag in $scopeTags) {
        $key = $scopeTagKeys[[string] $scopeTag.Id]
        $linked = @($assignments | Where-Object { $scopeTag.Id -in @($_.RawIds.ScopeTagIds) })
        Add-ExplorerRow -Builder $scopeTagRows -Key $key -View 'scope-tags' -Title ([string] $scopeTag.DisplayName) -Meta ([string] $scopeTag.Description) -Badge "$($linked.Count) assignments" -Icon $iconDevices
        $links = @($linked | ForEach-Object { New-ExplorerLink -Key $assignmentKeys[[string] $_.Id] -View 'assignments' -Label $_.Name -Meta $_.RoleDefinition.DisplayName }) -join ''
        if (-not $links) { $links = New-ExplorerEmptyState 'No connected assignment was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">SCOPE TAG</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Assignments</small><strong>{3}</strong></span><span><small>Built in</small><strong>{4}</strong></span><span><small>Source</small><strong>{5}</strong></span></div><h3>Role assignments</h3><div class="relation-list">{6}</div></section>' -f $key, (ConvertTo-ExplorerText $scopeTag.DisplayName), (ConvertTo-ExplorerText $scopeTag.Description), $linked.Count, $(if ($scopeTag.IsBuiltIn) { 'Yes' } else { 'No' }), (ConvertTo-ExplorerText $scopeTag.SourceApiVersion), $links))
    }

    foreach ($permission in $permissions) {
        $key = $permissionKeys[[string] $permission.RawAction]
        Add-ExplorerRow -Builder $permissionRows -Key $key -View 'permissions' -Title "$($permission.Resource): $($permission.Operation)" -Meta ([string] $permission.RawAction) -Badge "$($permission.AdministratorCount) administrators" -Icon $iconLock
        $assignmentLinks = @($permission.RoleAssignments | ForEach-Object { if ($assignmentKeys.ContainsKey([string] $_.RoleAssignmentId)) { New-ExplorerLink -Key $assignmentKeys[[string] $_.RoleAssignmentId] -View 'assignments' -Label $_.RoleAssignmentName -Meta $_.RoleDefinitionName } }) -join ''
        $roleLinks = @($permission.RoleDefinitions | ForEach-Object { if ($roleKeys.ContainsKey([string] $_.RoleDefinitionId)) { New-ExplorerLink -Key $roleKeys[[string] $_.RoleDefinitionId] -View 'roles' -Label $_.RoleDefinitionName -Meta 'Intune role' } }) -join ''
        if (-not $assignmentLinks) { $assignmentLinks = New-ExplorerEmptyState 'No role assignment source was returned.' }
        if (-not $roleLinks) { $roleLinks = New-ExplorerEmptyState 'No role definition source was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">PERMISSION</p><h2>{1}: {2}</h2><code class="raw-value">{3}</code><div class="fact-grid"><span><small>Administrators</small><strong>{4}</strong></span><span><small>Assignments</small><strong>{5}</strong></span><span><small>Roles</small><strong>{6}</strong></span></div><h3>Role assignments</h3><div class="relation-list">{7}</div><h3>Roles</h3><div class="relation-list">{8}</div></section>' -f $key, (ConvertTo-ExplorerText $permission.Resource), (ConvertTo-ExplorerText $permission.Operation), (ConvertTo-ExplorerText $permission.RawAction), $permission.AdministratorCount, @($permission.RoleAssignments).Count, @($permission.RoleDefinitions).Count, $assignmentLinks, $roleLinks))
    }

    foreach ($workload in $workloadObjects) {
        $key = $workloadKeys[[string] $workload.Id]
        $linkedAssignments = @($workloadAssignments | Where-Object WorkloadId -EQ $workload.Id)
        Add-ExplorerRow -Builder $workloadRows -Key $key -View 'workloads' -Title ([string] $workload.Name) -Meta ([string] $workload.WorkloadType) -Badge "$($linkedAssignments.Count) targets" -Icon $iconDevices
        $assignmentLinks = @($linkedAssignments | ForEach-Object {
            $assignmentKey = "$($_.WorkloadId)::$($_.Id)"
            if ($workloadAssignmentKeys.ContainsKey($assignmentKey)) {
                $targetName = if ($null -ne $_.Group) { [string] $_.Group.DisplayName } else { [string] $_.TargetType }
                New-ExplorerLink -Key $workloadAssignmentKeys[$assignmentKey] -View 'workload-assignments' -Label $targetName -Meta "$($_.Intent), $(Get-ExplorerEvidenceLabel $_.EvidenceState)"
            }
        }) -join ''
        if (-not $assignmentLinks) { $assignmentLinks = New-ExplorerEmptyState 'No assignment target was returned for this object.' }
        $scopeTagText = @($workload.ScopeTagIds | Where-Object { $_ }) -join ', '
        if ([string]::IsNullOrWhiteSpace($scopeTagText)) { $scopeTagText = 'None returned' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">INTUNE WORKLOAD</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Workload</small><strong>{3}</strong></span><span><small>Assignments</small><strong>{4}</strong></span><span><small>Assignment evidence</small><strong>{5}</strong></span><span><small>API</small><strong>{6}</strong></span></div><h3>Scope Tag IDs</h3><code class="raw-value">{7}</code><h3>Assignment targets</h3><div class="relation-list">{8}</div></section>' -f
            $key, (ConvertTo-ExplorerText $workload.Name), (ConvertTo-ExplorerText $workload.Description), (ConvertTo-ExplorerText $workload.WorkloadType), $linkedAssignments.Count, (ConvertTo-ExplorerText $workload.AssignmentDataState), (ConvertTo-ExplorerText $workload.SourceApiVersion), (ConvertTo-ExplorerText $scopeTagText), $assignmentLinks))
    }

    foreach ($workloadAssignment in $workloadAssignments) {
        $compositeId = "$($workloadAssignment.WorkloadId)::$($workloadAssignment.Id)"
        $key = $workloadAssignmentKeys[$compositeId]
        $targetName = if ($null -ne $workloadAssignment.Group) { [string] $workloadAssignment.Group.DisplayName } elseif (-not [string]::IsNullOrWhiteSpace([string] $workloadAssignment.CollectionId)) { [string] $workloadAssignment.CollectionId } else { [string] $workloadAssignment.TargetType }
        $evidenceLabel = Get-ExplorerEvidenceLabel ([string] $workloadAssignment.EvidenceState)
        Add-ExplorerRow -Builder $workloadAssignmentRows -Key $key -View 'workload-assignments' -Title ([string] $workloadAssignment.WorkloadName) -Meta $targetName -Badge $evidenceLabel -Icon $iconRole
        $workloadLink = if ($workloadKeys.ContainsKey([string] $workloadAssignment.WorkloadId)) { New-ExplorerLink -Key $workloadKeys[[string] $workloadAssignment.WorkloadId] -View 'workloads' -Label $workloadAssignment.WorkloadName -Meta $workloadAssignment.WorkloadType } else { New-ExplorerEmptyState 'The source workload object was not resolved.' }
        $groupLink = if ($null -ne $workloadAssignment.Group -and $workloadGroupKeys.ContainsKey([string] $workloadAssignment.GroupId)) { New-ExplorerLink -Key $workloadGroupKeys[[string] $workloadAssignment.GroupId] -View 'target-groups' -Label $workloadAssignment.Group.DisplayName -Meta $workloadAssignment.TargetType } elseif (-not [string]::IsNullOrWhiteSpace([string] $workloadAssignment.GroupId)) { New-ExplorerEmptyState "The target group name was not resolved. ID: $($workloadAssignment.GroupId)" } else { New-ExplorerEmptyState $workloadAssignment.TargetType }
        $filterLink = if ($null -ne $workloadAssignment.Filter -and $filterKeys.ContainsKey([string] $workloadAssignment.FilterId)) { New-ExplorerLink -Key $filterKeys[[string] $workloadAssignment.FilterId] -View 'assignment-filters' -Label $workloadAssignment.Filter.DisplayName -Meta $workloadAssignment.FilterMode } elseif (-not [string]::IsNullOrWhiteSpace([string] $workloadAssignment.FilterId)) { New-ExplorerEmptyState "The assignment filter name was not resolved. ID: $($workloadAssignment.FilterId)" } else { New-ExplorerEmptyState 'No assignment filter was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">WORKLOAD ASSIGNMENT</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Intent</small><strong>{3}</strong></span><span><small>Target</small><strong>{4}</strong></span><span><small>Evidence</small><strong>{5}</strong></span><span><small>API</small><strong>{6}</strong></span></div><h3>Workload object</h3><div class="relation-list">{7}</div><h3>Target group</h3><div class="relation-list">{8}</div><h3>Assignment filter</h3><div class="relation-list">{9}</div><h3>Raw target type</h3><code class="raw-value">{10}</code></section>' -f
            $key, (ConvertTo-ExplorerText $workloadAssignment.WorkloadName), (ConvertTo-ExplorerText $targetName), (ConvertTo-ExplorerText $workloadAssignment.Intent), (ConvertTo-ExplorerText $workloadAssignment.TargetType), (ConvertTo-ExplorerText $evidenceLabel), (ConvertTo-ExplorerText $workloadAssignment.SourceApiVersion), $workloadLink, $groupLink, $filterLink, (ConvertTo-ExplorerText $workloadAssignment.RawTargetType)))
    }

    foreach ($workloadGroup in $workloadGroups) {
        $key = $workloadGroupKeys[[string] $workloadGroup.Id]
        $linkedAssignments = @($workloadAssignments | Where-Object GroupId -EQ $workloadGroup.Id)
        Add-ExplorerRow -Builder $workloadGroupRows -Key $key -View 'target-groups' -Title ([string] $workloadGroup.DisplayName) -Meta ([string] $workloadGroup.Description) -Badge "$($linkedAssignments.Count) targets" -Icon $iconGroups
        $links = @($linkedAssignments | ForEach-Object {
            $assignmentKey = "$($_.WorkloadId)::$($_.Id)"
            if ($workloadAssignmentKeys.ContainsKey($assignmentKey)) { New-ExplorerLink -Key $workloadAssignmentKeys[$assignmentKey] -View 'workload-assignments' -Label $_.WorkloadName -Meta "$($_.TargetType), $($_.Intent)" }
        }) -join ''
        if (-not $links) { $links = New-ExplorerEmptyState 'No connected workload assignment was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">ASSIGNMENT TARGET GROUP</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Assignments</small><strong>{3}</strong></span><span><small>Resolution</small><strong>{4}</strong></span></div><h3>Workload assignments</h3><div class="relation-list">{5}</div></section>' -f
            $key, (ConvertTo-ExplorerText $workloadGroup.DisplayName), (ConvertTo-ExplorerText $workloadGroup.Description), $linkedAssignments.Count, (ConvertTo-ExplorerText $workloadGroup.ResolutionState), $links))
    }

    foreach ($assignmentFilter in $assignmentFilters) {
        $key = $filterKeys[[string] $assignmentFilter.Id]
        $linkedAssignments = @($workloadAssignments | Where-Object FilterId -EQ $assignmentFilter.Id)
        Add-ExplorerRow -Builder $filterRows -Key $key -View 'assignment-filters' -Title ([string] $assignmentFilter.DisplayName) -Meta ([string] $assignmentFilter.Platform) -Badge "$($linkedAssignments.Count) uses" -Icon $iconLock
        $links = @($linkedAssignments | ForEach-Object {
            $assignmentKey = "$($_.WorkloadId)::$($_.Id)"
            if ($workloadAssignmentKeys.ContainsKey($assignmentKey)) { New-ExplorerLink -Key $workloadAssignmentKeys[$assignmentKey] -View 'workload-assignments' -Label $_.WorkloadName -Meta $_.FilterMode }
        }) -join ''
        if (-not $links) { $links = New-ExplorerEmptyState 'No connected workload assignment was returned.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">ASSIGNMENT FILTER</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Platform</small><strong>{3}</strong></span><span><small>Assignments</small><strong>{4}</strong></span><span><small>API</small><strong>{5}</strong></span></div><h3>Rule</h3><code class="raw-value">{6}</code><h3>Workload assignments</h3><div class="relation-list">{7}</div></section>' -f
            $key, (ConvertTo-ExplorerText $assignmentFilter.DisplayName), (ConvertTo-ExplorerText $assignmentFilter.Description), (ConvertTo-ExplorerText $assignmentFilter.Platform), $linkedAssignments.Count, (ConvertTo-ExplorerText $assignmentFilter.SourceApiVersion), (ConvertTo-ExplorerText $assignmentFilter.Rule), $links))
    }

    foreach ($managedDevice in $managedDevices) {
        $key = $managedDeviceKeys[[string] $managedDevice.Id]
        $deviceOutcomes = @($deploymentOutcomes | Where-Object DeviceId -EQ $managedDevice.Id)
        $deviceErrors = @($deviceOutcomes | Where-Object Category -EQ 'Error').Count
        Add-ExplorerRow -Builder $managedDeviceRows -Key $key -View 'managed-devices' -Title ([string] $managedDevice.DeviceName) -Meta "$($managedDevice.OperatingSystem) $($managedDevice.OsVersion)" -Badge "$deviceErrors errors" -Icon $iconDevices
        $userLink = if ($managedUserKeys.ContainsKey([string] $managedDevice.UserPrincipalName)) { New-ExplorerLink -Key $managedUserKeys[[string] $managedDevice.UserPrincipalName] -View 'managed-users' -Label $managedDevice.UserPrincipalName -Meta 'Associated managed user' } elseif (-not [string]::IsNullOrWhiteSpace([string] $managedDevice.UserPrincipalName)) { New-ExplorerEmptyState "The associated user was not resolved: $($managedDevice.UserPrincipalName)" } else { New-ExplorerEmptyState 'No associated user was returned by Intune.' }
        $outcomeLinks = @($deviceOutcomes | ForEach-Object {
            $outcomeId = "$($_.WorkloadId)::$($_.Id)"
            if ($deploymentOutcomeKeys.ContainsKey($outcomeId)) { New-ExplorerLink -Key $deploymentOutcomeKeys[$outcomeId] -View 'deployment-outcomes' -Label $_.WorkloadName -Meta "$($_.State), $($_.Category)" }
        }) -join ''
        if (-not $outcomeLinks) { $outcomeLinks = New-ExplorerEmptyState 'No supported deployment outcome was matched to this device.' }
        $lastSync = ConvertTo-ExplorerDateText $managedDevice.LastSyncDateTime
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">DEVICE 360</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Compliance</small><strong>{3}</strong></span><span><small>Outcomes</small><strong>{4}</strong></span><span><small>Errors</small><strong>{5}</strong></span><span><small>Last sync</small><strong>{6}</strong></span><span><small>Ownership</small><strong>{7}</strong></span><span><small>Management</small><strong>{8}</strong></span></div><h3>Associated user</h3><div class="relation-list">{9}</div><h3>Reported workload outcomes</h3><div class="relation-list">{10}</div><h3>Identifiers</h3><code class="raw-value">Intune: {11}<br>Microsoft Entra: {12}<br>Serial: {13}</code></section>' -f
            $key, (ConvertTo-ExplorerText $managedDevice.DeviceName), (ConvertTo-ExplorerText "$($managedDevice.Manufacturer) $($managedDevice.Model)"), (ConvertTo-ExplorerText $managedDevice.ComplianceState), $deviceOutcomes.Count, $deviceErrors, (ConvertTo-ExplorerText $lastSync), (ConvertTo-ExplorerText $managedDevice.Ownership), (ConvertTo-ExplorerText $managedDevice.ManagementState), $userLink, $outcomeLinks, (ConvertTo-ExplorerText $managedDevice.Id), (ConvertTo-ExplorerText $managedDevice.EntraDeviceId), (ConvertTo-ExplorerText $managedDevice.SerialNumber)))
    }

    foreach ($managedUser in $managedUsers) {
        $key = $managedUserKeys[[string] $managedUser.UserPrincipalName]
        $userDevices = @($managedDevices | Where-Object UserPrincipalName -EQ $managedUser.UserPrincipalName)
        $userDeviceIds = @($userDevices.Id)
        $userOutcomes = @($deploymentOutcomes | Where-Object { $_.UserPrincipalName -eq $managedUser.UserPrincipalName -or $_.DeviceId -in $userDeviceIds })
        $displayName = if ([string]::IsNullOrWhiteSpace([string] $managedUser.DisplayName)) { [string] $managedUser.UserPrincipalName } else { [string] $managedUser.DisplayName }
        Add-ExplorerRow -Builder $managedUserRows -Key $key -View 'managed-users' -Title $displayName -Meta ([string] $managedUser.UserPrincipalName) -Badge "$($userDevices.Count) devices" -Icon $iconUser
        $deviceLinks = @($userDevices | ForEach-Object { if ($managedDeviceKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $managedDeviceKeys[[string] $_.Id] -View 'managed-devices' -Label $_.DeviceName -Meta "$($_.OperatingSystem) $($_.OsVersion)" } }) -join ''
        if (-not $deviceLinks) { $deviceLinks = New-ExplorerEmptyState 'No associated Intune managed device was returned.' }
        $outcomeLinks = @($userOutcomes | ForEach-Object {
            $outcomeId = "$($_.WorkloadId)::$($_.Id)"
            if ($deploymentOutcomeKeys.ContainsKey($outcomeId)) { New-ExplorerLink -Key $deploymentOutcomeKeys[$outcomeId] -View 'deployment-outcomes' -Label $_.WorkloadName -Meta "$($_.DeviceName), $($_.State)" }
        }) -join ''
        if (-not $outcomeLinks) { $outcomeLinks = New-ExplorerEmptyState 'No supported deployment outcome was connected to this user or their devices.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">USER 360</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Managed devices</small><strong>{3}</strong></span><span><small>Reported outcomes</small><strong>{4}</strong></span><span><small>Errors</small><strong>{5}</strong></span></div><h3>Managed devices</h3><div class="relation-list">{6}</div><h3>Reported workload outcomes</h3><div class="relation-list">{7}</div></section>' -f
            $key, (ConvertTo-ExplorerText $displayName), (ConvertTo-ExplorerText $managedUser.UserPrincipalName), $userDevices.Count, $userOutcomes.Count, @($userOutcomes | Where-Object Category -EQ 'Error').Count, $deviceLinks, $outcomeLinks))
    }

    foreach ($deploymentOutcome in $deploymentOutcomes) {
        $outcomeId = "$($deploymentOutcome.WorkloadId)::$($deploymentOutcome.Id)"
        $key = $deploymentOutcomeKeys[$outcomeId]
        $targetText = if ([string]::IsNullOrWhiteSpace([string] $deploymentOutcome.DeviceName)) { 'Unresolved device' } else { [string] $deploymentOutcome.DeviceName }
        Add-ExplorerRow -Builder $deploymentOutcomeRows -Key $key -View 'deployment-outcomes' -Title ([string] $deploymentOutcome.WorkloadName) -Meta $targetText -Badge ([string] $deploymentOutcome.Category) -Icon $iconRole
        $workloadLink = if ($workloadKeys.ContainsKey([string] $deploymentOutcome.WorkloadId)) { New-ExplorerLink -Key $workloadKeys[[string] $deploymentOutcome.WorkloadId] -View 'workloads' -Label $deploymentOutcome.WorkloadName -Meta $deploymentOutcome.WorkloadType } else { New-ExplorerEmptyState 'The source workload object was not resolved.' }
        $deviceLink = if ($managedDeviceKeys.ContainsKey([string] $deploymentOutcome.DeviceId)) { New-ExplorerLink -Key $managedDeviceKeys[[string] $deploymentOutcome.DeviceId] -View 'managed-devices' -Label $deploymentOutcome.DeviceName -Meta $deploymentOutcome.DeviceMatchState } else { New-ExplorerEmptyState "Device relationship: $($deploymentOutcome.DeviceMatchState). Raw device: $targetText" }
        $userLink = if ($managedUserKeys.ContainsKey([string] $deploymentOutcome.UserPrincipalName)) { New-ExplorerLink -Key $managedUserKeys[[string] $deploymentOutcome.UserPrincipalName] -View 'managed-users' -Label $deploymentOutcome.UserPrincipalName -Meta 'Reported user' } else { New-ExplorerEmptyState $(if ([string]::IsNullOrWhiteSpace([string] $deploymentOutcome.UserPrincipalName)) { 'No user was returned with this outcome.' } else { "The reported user was not resolved: $($deploymentOutcome.UserPrincipalName)" }) }
        $lastReported = ConvertTo-ExplorerDateText $deploymentOutcome.LastReportedDateTime
        $errorText = if ([string]::IsNullOrWhiteSpace([string] $deploymentOutcome.ErrorCodeHex)) { 'No non-zero error code was returned.' } else { "$($deploymentOutcome.ErrorCode) ($($deploymentOutcome.ErrorCodeHex))" }
        $detailText = if ([string]::IsNullOrWhiteSpace([string] $deploymentOutcome.StateDetail)) { 'No additional state detail was returned.' } else { [string] $deploymentOutcome.StateDetail }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">REPORTED DEPLOYMENT OUTCOME</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>State</small><strong>{3}</strong></span><span><small>Category</small><strong>{4}</strong></span><span><small>Last reported</small><strong>{5}</strong></span><span><small>Device match</small><strong>{6}</strong></span><span><small>API</small><strong>{7}</strong></span><span><small>Evidence</small><strong>{8}</strong></span></div><h3>State detail</h3><code class="raw-value">{9}</code><h3>Error code</h3><code class="raw-value">{10}</code><h3>Workload</h3><div class="relation-list">{11}</div><h3>Device</h3><div class="relation-list">{12}</div><h3>User</h3><div class="relation-list">{13}</div></section>' -f
            $key, (ConvertTo-ExplorerText $deploymentOutcome.WorkloadName), (ConvertTo-ExplorerText $targetText), (ConvertTo-ExplorerText $deploymentOutcome.State), (ConvertTo-ExplorerText $deploymentOutcome.Category), (ConvertTo-ExplorerText $lastReported), (ConvertTo-ExplorerText $deploymentOutcome.DeviceMatchState), (ConvertTo-ExplorerText $deploymentOutcome.SourceApiVersion), (ConvertTo-ExplorerText $deploymentOutcome.EvidenceState), (ConvertTo-ExplorerText $detailText), (ConvertTo-ExplorerText $errorText), $workloadLink, $deviceLink, $userLink))
    }

    foreach ($auditEvent in $auditEvents) {
        $key = $auditEventKeys[[string] $auditEvent.Id]
        $title = if ([string]::IsNullOrWhiteSpace([string] $auditEvent.Activity)) { [string] $auditEvent.DisplayName } else { [string] $auditEvent.Activity }
        $actorText = if ([string]::IsNullOrWhiteSpace([string] $auditEvent.ActorUserPrincipalName)) { [string] $auditEvent.ActorApplication } else { [string] $auditEvent.ActorUserPrincipalName }
        Add-ExplorerRow -Builder $auditEventRows -Key $key -View 'audit-events' -Title $title -Meta $actorText -Badge ([string] $auditEvent.ActivityResult) -Icon $iconCalendar
        $resourceText = @($auditEvent.Resources | ForEach-Object { "$(ConvertTo-ExplorerText $_.DisplayName) [$((ConvertTo-ExplorerText $_.ResourceId))]" }) -join '<br>'
        if ([string]::IsNullOrWhiteSpace($resourceText)) { $resourceText = 'No resource was returned with this audit event.' }
        $activityDate = ConvertTo-ExplorerDateText $auditEvent.ActivityDateTime
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">INTUNE AUDIT EVENT</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Activity time</small><strong>{3}</strong></span><span><small>Result</small><strong>{4}</strong></span><span><small>Operation</small><strong>{5}</strong></span><span><small>Component</small><strong>{6}</strong></span></div><h3>Actor</h3><code class="raw-value">{7}</code><h3>Resources</h3><code class="raw-value">{8}</code><h3>Correlation ID</h3><code class="raw-value">{9}</code></section>' -f
            $key, (ConvertTo-ExplorerText $title), (ConvertTo-ExplorerText $auditEvent.Category), (ConvertTo-ExplorerText $activityDate), (ConvertTo-ExplorerText $auditEvent.ActivityResult), (ConvertTo-ExplorerText $auditEvent.ActivityOperationType), (ConvertTo-ExplorerText $auditEvent.ComponentName), (ConvertTo-ExplorerText $actorText), $resourceText, (ConvertTo-ExplorerText $auditEvent.CorrelationId)))
    }

    for ($index = 0; $index -lt $snapshotChanges.Count; $index++) {
        $change = $snapshotChanges[$index]
        $key = $snapshotChangeKeys[$index]
        $changedPropertyText = @($change.ChangedProperties) -join ', '
        $meta = if ([string]::IsNullOrWhiteSpace($changedPropertyText)) { [string] $change.EntityType } else { "$($change.EntityType): $changedPropertyText" }
        Add-ExplorerRow -Builder $snapshotChangeRows -Key $key -View 'snapshot-changes' -Title "$($change.ChangeType): $($change.Name)" -Meta $meta -Badge ([string] $change.ImpactState) -Icon $iconCalendar
        $potentialUsers = if ($null -eq $change.PotentialUserCount) { 'Not evaluated' } else { [string] $change.PotentialUserCount }
        $potentialDevices = if ($null -eq $change.PotentialDeviceCount) { 'Not evaluated' } else { [string] $change.PotentialDeviceCount }
        $properties = if ([string]::IsNullOrWhiteSpace($changedPropertyText)) { 'Record added or removed' } else { $changedPropertyText }
        $relatedAuditEvents = @(Get-IntuneAccessProperty $change 'AuditEvents' @())
        $auditLinks = @($relatedAuditEvents | ForEach-Object { if ($auditEventKeys.ContainsKey([string] $_.Id)) { New-ExplorerLink -Key $auditEventKeys[[string] $_.Id] -View 'audit-events' -Label $_.Activity -Meta (ConvertTo-ExplorerDateText $_.ActivityDateTime) } }) -join ''
        if (-not $auditLinks) { $auditLinks = New-ExplorerEmptyState 'No matching Intune audit event was returned for this change.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">SNAPSHOT CHANGE</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Entity</small><strong>{3}</strong></span><span><small>Change</small><strong>{4}</strong></span><span><small>Impact state</small><strong>{5}</strong></span><span><small>Changed properties</small><strong>{6}</strong></span><span><small>Potential users</small><strong>{7}</strong></span><span><small>Potential devices</small><strong>{8}</strong></span></div><h3>Impact summary</h3><p>{9}</p><h3>Stable key</h3><code class="raw-value">{10}</code><h3>Related Intune audit events</h3><div class="relation-list">{11}</div></section>' -f
            $key, (ConvertTo-ExplorerText $change.Name), (ConvertTo-ExplorerText $change.ImpactSummary), (ConvertTo-ExplorerText $change.EntityType), (ConvertTo-ExplorerText $change.ChangeType), (ConvertTo-ExplorerText $change.ImpactState), (ConvertTo-ExplorerText $properties), (ConvertTo-ExplorerText $potentialUsers), (ConvertTo-ExplorerText $potentialDevices), (ConvertTo-ExplorerText $change.ImpactSummary), (ConvertTo-ExplorerText $change.Id), $auditLinks))
    }

    foreach ($policySetting in $policySettings) {
        $key = $policySettingKeys[[string] $policySetting.Id]
        Add-ExplorerRow -Builder $policySettingRows -Key $key -View 'policy-settings' -Title ([string] $policySetting.SettingDefinitionId) -Meta ([string] $policySetting.WorkloadName) -Badge "$($policySetting.ValueCount) values" -Icon $iconDevices
        $policyLink = if ($workloadKeys.ContainsKey([string] $policySetting.WorkloadId)) { New-ExplorerLink -Key $workloadKeys[[string] $policySetting.WorkloadId] -View 'workloads' -Label $policySetting.WorkloadName -Meta $policySetting.WorkloadType } else { New-ExplorerEmptyState 'The source policy was not resolved in this report.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">OBSERVED POLICY SETTING</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Policy type</small><strong>{3}</strong></span><span><small>Values</small><strong>{4}</strong></span><span><small>API</small><strong>{5}</strong></span><span><small>Evidence</small><strong>{6}</strong></span></div><h3>Observed value set</h3><code class="raw-value">{7}</code><h3>Source policy</h3><div class="relation-list">{8}</div></section>' -f
            $key, (ConvertTo-ExplorerText $policySetting.SettingDefinitionId), (ConvertTo-ExplorerText $policySetting.WorkloadName), (ConvertTo-ExplorerText $policySetting.WorkloadType), $policySetting.ValueCount, (ConvertTo-ExplorerText $policySetting.SourceApiVersion), (ConvertTo-ExplorerText $policySetting.EvidenceState), (ConvertTo-ExplorerText $policySetting.ValueJson), $policyLink))
    }

    foreach ($finding in $policyConflictFindings) {
        $key = $policyConflictKeys[[string] $finding.Id]
        Add-ExplorerRow -Builder $policyConflictRows -Key $key -View 'policy-conflicts' -Title ([string] $finding.SettingDefinitionId) -Meta "$($finding.FirstPolicyName) and $($finding.SecondPolicyName)" -Badge ([string] $finding.FindingState) -Icon $iconLightbulb
        $firstPolicyLink = if ($workloadKeys.ContainsKey([string] $finding.FirstPolicyId)) { New-ExplorerLink -Key $workloadKeys[[string] $finding.FirstPolicyId] -View 'workloads' -Label $finding.FirstPolicyName -Meta 'First observed policy' } else { New-ExplorerEmptyState 'The first source policy was not resolved.' }
        $secondPolicyLink = if ($workloadKeys.ContainsKey([string] $finding.SecondPolicyId)) { New-ExplorerLink -Key $workloadKeys[[string] $finding.SecondPolicyId] -View 'workloads' -Label $finding.SecondPolicyName -Meta 'Second observed policy' } else { New-ExplorerEmptyState 'The second source policy was not resolved.' }
        $null = $inspectorPanels.AppendLine(('<section class="inspector-panel" data-object-panel="{0}" hidden><p class="eyebrow">POLICY OVERLAP FINDING</p><h2>{1}</h2><p class="wrap-value">{2}</p><div class="fact-grid"><span><small>Finding</small><strong>{3}</strong></span><span><small>Target overlap</small><strong>{4}</strong></span><span><small>Values differ</small><strong>{5}</strong></span><span><small>Target evidence</small><strong>{6}</strong></span></div><h3>First policy value</h3><code class="raw-value">{7}</code><div class="relation-list">{8}</div><h3>Second policy value</h3><code class="raw-value">{9}</code><div class="relation-list">{10}</div><h3>Evidence boundary</h3><p>{11} This finding does not claim the final value enforced on a device.</p></section>' -f
            $key, (ConvertTo-ExplorerText $finding.SettingDefinitionId), (ConvertTo-ExplorerText "$($finding.FirstPolicyName) compared with $($finding.SecondPolicyName)"), (ConvertTo-ExplorerText $finding.FindingState), (ConvertTo-ExplorerText $finding.TargetOverlapState), (ConvertTo-ExplorerText $finding.ValuesDiffer), @($finding.TargetEvidence).Count, (ConvertTo-ExplorerText $finding.FirstValueJson), $firstPolicyLink, (ConvertTo-ExplorerText $finding.SecondValueJson), $secondPolicyLink, (ConvertTo-ExplorerText $finding.Reason)))
    }

    if ($administrators.Count -eq 0) { $null = $administratorRows.AppendLine((New-ExplorerEmptyState 'No administrator was returned from the connected Admin Groups.')) }
    if ($adminGroups.Count -eq 0) { $null = $groupRows.AppendLine((New-ExplorerEmptyState 'No Admin Group was returned from Intune role assignments.')) }
    if ($assignments.Count -eq 0) { $null = $assignmentRows.AppendLine((New-ExplorerEmptyState 'No Intune role assignment was returned.')) }
    if ($roles.Count -eq 0) { $null = $roleRows.AppendLine((New-ExplorerEmptyState 'No connected Intune role was returned.')) }
    if ($scopeGroups.Count -eq 0) { $null = $scopeGroupRows.AppendLine((New-ExplorerEmptyState 'No connected Scope Group was returned.')) }
    if ($scopeTags.Count -eq 0) { $null = $scopeTagRows.AppendLine((New-ExplorerEmptyState 'No explicit Scope Tag was returned.')) }
    if ($permissions.Count -eq 0) { $null = $permissionRows.AppendLine((New-ExplorerEmptyState 'No permission action was returned.')) }
    if ($workloadObjects.Count -eq 0) { $null = $workloadRows.AppendLine((New-ExplorerEmptyState 'No policy, application, script or update object was collected. Review the selected features and collection notes.')) }
    if ($workloadAssignments.Count -eq 0) { $null = $workloadAssignmentRows.AppendLine((New-ExplorerEmptyState 'No workload assignment target was returned.')) }
    if ($workloadGroups.Count -eq 0) { $null = $workloadGroupRows.AppendLine((New-ExplorerEmptyState 'No group-based workload assignment target was returned.')) }
    if ($assignmentFilters.Count -eq 0) { $null = $filterRows.AppendLine((New-ExplorerEmptyState 'No assignment filter connected to a collected workload assignment was returned.')) }
    if ($managedDevices.Count -eq 0) { $null = $managedDeviceRows.AppendLine((New-ExplorerEmptyState 'No Intune managed device was collected. Review the selected features and collection notes.')) }
    if ($managedUsers.Count -eq 0) { $null = $managedUserRows.AppendLine((New-ExplorerEmptyState 'No user associated with a collected Intune managed device was returned.')) }
    if ($deploymentOutcomes.Count -eq 0) { $null = $deploymentOutcomeRows.AppendLine((New-ExplorerEmptyState 'No supported reported deployment outcome was collected. Missing outcome data is not treated as success.')) }
    if ($snapshotChanges.Count -eq 0) { $null = $snapshotChangeRows.AppendLine((New-ExplorerEmptyState 'No baseline snapshot comparison is attached to this report. Use Start-IntuneAccess with BaselineSnapshotPath to review changes.')) }
    if ($policySettings.Count -eq 0) { $null = $policySettingRows.AppendLine((New-ExplorerEmptyState 'No supported policy setting value was collected. Review PolicyAnalysis collection status.')) }
    if ($policyConflictFindings.Count -eq 0) { $null = $policyConflictRows.AppendLine((New-ExplorerEmptyState 'No shared observed setting was found across two supported policies. This does not prove that the tenant has no conflict.')) }
    if ($auditEvents.Count -eq 0) { $null = $auditEventRows.AppendLine((New-ExplorerEmptyState 'No recent Intune audit event was returned. Review AuditEvidence collection status.')) }
    if ($inspectorPanels.Length -eq 0) { $null = $inspectorPanels.AppendLine('<section class="inspector-panel" data-object-panel="none"><p class="eyebrow">NO OBJECTS</p><h2>No Intune RBAC object was collected</h2><p>Review the collection notes and signed-in account permissions.</p></section>') }

    $warningItems = if ($warnings.Count -gt 0) { @($warnings | ForEach-Object { '<li>{0}</li>' -f (ConvertTo-ExplorerText $_) }) -join '' } else { '<li>No collection warning was produced.</li>' }
    $collectionItems = if ($workloadCollectionStatus.Count -gt 0) {
        @($workloadCollectionStatus | ForEach-Object {
            '<li><strong>{0}</strong>: {1} ({2}, {3} objects){4}</li>' -f (ConvertTo-ExplorerText $_.Source), (ConvertTo-ExplorerText $_.State), (ConvertTo-ExplorerText $_.ApiVersion), $_.ItemCount, $(if ([string]::IsNullOrWhiteSpace([string] $_.Reason)) { '' } else { ' - ' + (ConvertTo-ExplorerText $_.Reason) })
        }) -join ''
    }
    else { '<li>Workload assignment collection was not selected for this report.</li>' }
    $outcomeStatusItems = if ($outcomeCollectionStatus.Count -gt 0) {
        @($outcomeCollectionStatus | ForEach-Object {
            '<li><strong>{0}</strong>: {1} ({2} records){3}</li>' -f (ConvertTo-ExplorerText $_.WorkloadName), (ConvertTo-ExplorerText $_.State), $_.RecordCount, $(if ([string]::IsNullOrWhiteSpace([string] $_.Reason)) { '' } else { ' - ' + (ConvertTo-ExplorerText $_.Reason) })
        }) -join ''
    }
    else { '<li>Operational outcome collection was not selected for this report.</li>' }
    $policyStatusItems = if ($policyConflictCollectionStatus.Count -gt 0) {
        @($policyConflictCollectionStatus | ForEach-Object {
            '<li><strong>{0}</strong>: {1} ({2} settings){3}</li>' -f (ConvertTo-ExplorerText $_.WorkloadName), (ConvertTo-ExplorerText $_.State), $_.SettingCount, $(if ([string]::IsNullOrWhiteSpace([string] $_.Reason)) { '' } else { ' - ' + (ConvertTo-ExplorerText $_.Reason) })
        }) -join ''
    }
    else { '<li>Policy setting analysis was not selected for this report.</li>' }
    $auditStatusItem = if ($null -eq $auditCollectionStatus) { '<li>Audit evidence collection was not selected for this report.</li>' } else { '<li><strong>Recent Intune audit events</strong>: {0} ({1} events across {2} days){3}</li>' -f (ConvertTo-ExplorerText $auditCollectionStatus.State), $auditCollectionStatus.EventCount, $auditCollectionStatus.Days, $(if ([string]::IsNullOrWhiteSpace([string] $auditCollectionStatus.Reason)) { '' } else { ' - ' + (ConvertTo-ExplorerText $auditCollectionStatus.Reason) }) }
    $graphScopes = @(Get-IntuneAccessProperty $TenantRbac 'GraphPermissionsUsed' @())
    $scopeItems = @($graphScopes | Sort-Object | ForEach-Object { '<code>{0}</code>' -f (ConvertTo-ExplorerText $_) }) -join ''

    return @"
<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; font-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
<title>IntuneAccess explorer - $(ConvertTo-ExplorerText $tenantName)</title>
<style>
$fontCss
:root{--paper:#fbfbfa;--surface:#fff;--ink:#111214;--muted:#687079;--line:#d9dcdf;--line-dark:#aeb4ba;--yellow:#ffd400;--yellow-soft:#fff9d8;--blue:#175cd3;--nav:#f4f4f1;--font-display:'Space Grotesk',Segoe UI,sans-serif;--font-mono:'IBM Plex Mono',Consolas,monospace}*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--paper);color:var(--ink);font:14px/1.45 var(--font-display)}button,input{font:inherit}button{color:inherit}.skip-link{position:fixed;left:12px;top:-80px;background:var(--ink);color:#fff;padding:10px 14px;z-index:20}.skip-link:focus{top:12px}.topbar{height:64px;border-bottom:1px solid var(--line);background:rgba(251,251,250,.98);display:flex;align-items:center;padding:0 26px;position:sticky;top:0;z-index:10}.topbar-inner{width:100%;display:flex;align-items:center;justify-content:space-between;gap:24px}.brand-cluster,.report-meta,.meta-pill{display:flex;align-items:center}.brand-cluster{gap:20px}.brand{font-size:23px;font-weight:700;letter-spacing:-.045em}.brand-divider{width:1px;height:24px;background:var(--line)}.report-mode{font-size:18px}.read-only{display:flex;align-items:center;gap:9px}.read-only i{width:9px;height:9px;border-radius:50%;background:var(--yellow)}.report-meta{gap:0}.meta-pill{gap:8px;padding:0 18px;border-left:1px solid var(--line);min-height:28px;white-space:nowrap}.meta-pill img{width:18px;height:18px}.meta-pill strong{font-weight:600;margin-left:3px}.app-frame{min-height:calc(100vh - 64px);display:grid;grid-template-columns:260px minmax(0,1fr)}.product-nav{background:var(--nav);border-right:1px solid var(--line);padding:22px 14px;position:sticky;top:64px;height:calc(100vh - 64px);overflow:auto}.nav-intro{padding:0 10px 18px}.nav-intro strong{display:block;font-size:16px;overflow-wrap:anywhere}.nav-intro small{display:block;color:var(--muted);margin-top:4px}.nav-item{width:100%;border:1px solid transparent;background:transparent;display:grid;grid-template-columns:32px minmax(0,1fr) auto;gap:10px;align-items:center;text-align:left;padding:10px;border-radius:4px;cursor:pointer}.nav-item:hover,.nav-item.selected{background:var(--surface);border-color:var(--line)}.nav-item.selected{box-shadow:inset 4px 0 var(--yellow)}.nav-item img{width:23px;height:23px}.nav-item span{min-width:0}.nav-item strong,.nav-item small{display:block}.nav-item strong{font-size:14px}.nav-item small{font-size:11px;color:var(--muted);margin-top:2px}.nav-count{font:600 11px/1 var(--font-mono);border:1px solid var(--line);padding:5px 7px;background:var(--surface)}.content-shell{min-width:0;padding:32px}.page-heading{display:flex;justify-content:space-between;gap:20px;align-items:flex-end;margin-bottom:25px}.page-heading h1{font-size:45px;line-height:1;letter-spacing:-.055em;margin:4px 0 7px}.page-heading p{margin:0;color:var(--muted);font-size:16px}.eyebrow{font:600 11px/1.2 var(--font-mono);letter-spacing:.07em;color:var(--muted);margin:0 0 8px;text-transform:uppercase}.search-control{width:min(360px,100%)}.search-control input{width:100%;border:1px solid var(--line);background:var(--surface);padding:11px 13px;outline:none}.search-control input:focus{border-color:var(--ink);box-shadow:0 0 0 2px var(--yellow)}.workspace{display:grid;grid-template-columns:minmax(0,1fr) 380px;gap:24px;align-items:start}.view-panel{min-width:0}.summary-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:20px}.summary-card{border:1px solid var(--line);background:var(--surface);padding:18px}.summary-card small,.fact-grid small{display:block;font:600 10px/1.25 var(--font-mono);text-transform:uppercase;letter-spacing:.045em;color:var(--muted)}.summary-card strong{display:block;font-size:32px;letter-spacing:-.04em;margin-top:7px}.overview-panel,.collection-list,.inspector{border:1px solid var(--line);background:var(--surface)}.overview-panel{padding:24px}.overview-panel h2{font-size:25px;margin:0 0 8px}.overview-panel p{color:var(--muted);max-width:760px}.overview-paths{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-top:20px}.collection-list{overflow:hidden}.object-row{width:100%;border:0;border-bottom:1px solid var(--line);background:var(--surface);display:grid;grid-template-columns:38px minmax(0,1fr) auto;gap:13px;align-items:center;text-align:left;padding:13px 15px;cursor:pointer}.object-row:last-child{border-bottom:0}.object-row:hover,.object-row:focus-visible{background:var(--yellow-soft);outline:none}.object-row img{width:29px;height:29px}.object-copy{min-width:0}.object-copy strong,.object-copy small{display:block;overflow-wrap:anywhere}.object-copy strong{font-size:15px}.object-copy small{font-size:12px;color:var(--muted);margin-top:3px}.object-badge{font:600 10px/1.2 var(--font-mono);border:1px solid var(--line);padding:6px 8px;background:var(--paper);white-space:nowrap}.inspector{position:sticky;top:96px;max-height:calc(100vh - 122px);overflow:auto}.inspector-empty,.inspector-panel{padding:23px}.inspector-empty img{width:42px;height:42px;margin-bottom:16px}.inspector h2{font-size:25px;line-height:1.05;letter-spacing:-.035em;margin:0 0 8px;overflow-wrap:anywhere}.inspector h3{font-size:15px;margin:25px 0 9px}.inspector p{color:var(--muted)}.wrap-value,.raw-value{overflow-wrap:anywhere;word-break:break-word}.raw-value{display:block;font:11px/1.55 var(--font-mono);border:1px solid var(--line);background:var(--paper);padding:10px}.fact-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:1px;background:var(--line);border:1px solid var(--line);margin-top:20px}.fact-grid span{background:var(--surface);padding:12px;min-width:0}.fact-grid strong{display:block;margin-top:5px;overflow-wrap:anywhere}.relation-list{display:grid;gap:7px}.relation-link{width:100%;text-align:left;border:1px solid var(--line);background:var(--surface);padding:9px 10px;cursor:pointer}.relation-link:hover,.relation-link:focus-visible{border-color:var(--ink);background:var(--yellow-soft);outline:none}.relation-link strong,.relation-link small{display:block;overflow-wrap:anywhere}.relation-link small{font-size:11px;color:var(--muted);margin-top:2px}.empty-state{border:1px dashed var(--line-dark);padding:22px;color:var(--muted);background:var(--surface)}.review-layout{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:20px}.review-card{border:1px solid var(--line);background:var(--surface);padding:22px}.review-card h2{margin:0 0 14px}.review-card ul{padding-left:19px}.review-card li+li{margin-top:10px}.scope-list{display:flex;flex-wrap:wrap;gap:6px}.scope-list code{font:10px/1.3 var(--font-mono);border:1px solid var(--line);padding:5px;background:var(--paper)}.mobile-nav{display:none;border:1px solid var(--line);background:var(--surface);padding:9px 12px;cursor:pointer}.report-footer{border-top:1px solid var(--line);display:flex;justify-content:space-between;gap:20px;margin-top:28px;padding:18px 2px;color:var(--muted);font-size:12px}[hidden]{display:none!important}
@media(max-width:1200px){.report-meta .meta-pill:first-child{display:none}.workspace{grid-template-columns:minmax(0,1fr) 340px}.summary-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:900px){.app-frame{grid-template-columns:1fr}.product-nav{display:none;position:fixed;inset:64px auto 0 0;width:280px;z-index:9;box-shadow:10px 0 30px rgb(0 0 0 / 12%)}.product-nav.open{display:block}.mobile-nav{display:block}.workspace{grid-template-columns:1fr}.inspector{position:static;max-height:none}.overview-paths{grid-template-columns:1fr}}
@media(max-width:650px){.topbar{padding:0 14px}.brand-divider,.report-mode,.report-meta{display:none}.content-shell{padding:22px 14px}.page-heading{align-items:flex-start}.page-heading h1{font-size:36px}.search-control{display:none}.summary-grid{grid-template-columns:1fr 1fr}.review-layout{grid-template-columns:1fr}.object-badge{white-space:normal;text-align:right}.report-footer{flex-direction:column}}
</style>
</head>
<body data-initial-object="$(ConvertTo-ExplorerText $initialKey)">
<a class="skip-link" href="#main-content">Skip to content</a>
<header class="topbar"><div class="topbar-inner"><div class="brand-cluster"><span class="brand">IntuneAccess</span><span class="brand-divider"></span><span class="report-mode">Signal Atlas</span><span class="read-only"><i></i>Read-only explorer</span></div><div class="report-meta"><span class="meta-pill"><img src="$iconTenant" alt="">Tenant:<strong>$(ConvertTo-ExplorerText $tenantName)</strong></span><span class="meta-pill"><img src="$iconCalendar" alt="">Generated:<strong>$(ConvertTo-ExplorerText $generatedText)</strong></span><span class="meta-pill"><img src="$iconLock" alt="">Read-only</span></div></div></header>
<div class="app-frame">
<aside class="product-nav" id="product-nav" aria-label="Intune evidence sections"><div class="nav-intro"><strong>$(ConvertTo-ExplorerText $tenantName)</strong><small>Intune relationships and evidence</small></div><nav>
<button class="nav-item selected" type="button" data-view="overview" data-title="Overview" data-subtitle="Tenant-wide Intune access and assignment summary" aria-current="page"><img src="$iconTenant" alt=""><span><strong>Overview</strong><small>Collection summary</small></span></button>
<button class="nav-item" type="button" data-view="workloads" data-title="Policies and Apps" data-subtitle="Configuration, compliance, security, application, script and update objects"><img src="$iconDevices" alt=""><span><strong>Policies and Apps</strong><small>Managed workloads</small></span><b class="nav-count">$($workloadObjects.Count)</b></button>
<button class="nav-item" type="button" data-view="workload-assignments" data-title="Assignment Impact" data-subtitle="Included, excluded, broad and filtered workload targets"><img src="$iconRole" alt=""><span><strong>Assignment Impact</strong><small>Configured targets</small></span><b class="nav-count">$($workloadAssignments.Count)</b></button>
<button class="nav-item" type="button" data-view="target-groups" data-title="Target Groups" data-subtitle="Microsoft Entra groups targeted by collected Intune workloads"><img src="$iconGroups" alt=""><span><strong>Target Groups</strong><small>Policy and app targets</small></span><b class="nav-count">$($workloadGroups.Count)</b></button>
<button class="nav-item" type="button" data-view="assignment-filters" data-title="Assignment Filters" data-subtitle="Filters connected to collected workload assignments"><img src="$iconLock" alt=""><span><strong>Assignment Filters</strong><small>Include and exclude rules</small></span><b class="nav-count">$($assignmentFilters.Count)</b></button>
<button class="nav-item" type="button" data-view="managed-devices" data-title="Device 360" data-subtitle="Managed-device identity, health and reported workload outcomes"><img src="$iconDevices" alt=""><span><strong>Device 360</strong><small>Devices and outcomes</small></span><b class="nav-count">$($managedDevices.Count)</b></button>
<button class="nav-item" type="button" data-view="managed-users" data-title="User 360" data-subtitle="Managed users, their devices and connected outcome evidence"><img src="$iconUser" alt=""><span><strong>User 360</strong><small>Users and devices</small></span><b class="nav-count">$($managedUsers.Count)</b></button>
<button class="nav-item" type="button" data-view="deployment-outcomes" data-title="Deployment Outcomes" data-subtitle="Reported success, error, pending and not-applicable evidence"><img src="$iconRole" alt=""><span><strong>Deployment Outcomes</strong><small>Reported states</small></span><b class="nav-count">$($deploymentOutcomes.Count)</b></button>
<button class="nav-item" type="button" data-view="policy-conflicts" data-title="Policy Conflicts" data-subtitle="Observed values, conservative target overlap and potential conflict evidence"><img src="$iconLightbulb" alt=""><span><strong>Policy Conflicts</strong><small>Overlap analysis</small></span><b class="nav-count">$(@($policyConflictFindings | Where-Object FindingState -EQ 'PotentialConflict').Count)</b></button>
<button class="nav-item" type="button" data-view="policy-settings" data-title="Policy Settings" data-subtitle="Normalised setting values retained with their source policies"><img src="$iconDevices" alt=""><span><strong>Policy Settings</strong><small>Observed values</small></span><b class="nav-count">$($policySettings.Count)</b></button>
<button class="nav-item" type="button" data-view="snapshot-changes" data-title="Snapshot Changes" data-subtitle="Added, removed and modified Intune evidence with conservative impact summaries"><img src="$iconCalendar" alt=""><span><strong>Snapshot Changes</strong><small>Local comparison</small></span><b class="nav-count">$($snapshotChanges.Count)</b></button>
<button class="nav-item" type="button" data-view="audit-events" data-title="Audit Trail" data-subtitle="Recent Intune audit events and resource evidence"><img src="$iconCalendar" alt=""><span><strong>Audit Trail</strong><small>Recent changes</small></span><b class="nav-count">$($auditEvents.Count)</b></button>
<button class="nav-item" type="button" data-view="administrators" data-title="Administrators" data-subtitle="Users connected through Intune Admin Groups"><img src="$iconUser" alt=""><span><strong>Administrators</strong><small>RBAC-connected users</small></span><b class="nav-count">$($administrators.Count)</b></button>
<button class="nav-item" type="button" data-view="admin-groups" data-title="Admin Groups" data-subtitle="Microsoft Entra groups supplying Intune role assignments"><img src="$iconGroups" alt=""><span><strong>Admin Groups</strong><small>Assignment membership</small></span><b class="nav-count">$($adminGroups.Count)</b></button>
<button class="nav-item" type="button" data-view="assignments" data-title="Role Assignments" data-subtitle="The links between Admin Groups, roles and scopes"><img src="$iconRole" alt=""><span><strong>Role Assignments</strong><small>Access paths</small></span><b class="nav-count">$($assignments.Count)</b></button>
<button class="nav-item" type="button" data-view="roles" data-title="Roles" data-subtitle="Assigned built-in and custom Intune roles"><img src="$iconRole" alt=""><span><strong>Roles</strong><small>Built-in and custom</small></span><b class="nav-count">$($roles.Count)</b></button>
<button class="nav-item" type="button" data-view="scope-groups" data-title="Scope Groups" data-subtitle="Groups constraining assignment resource scope"><img src="$iconGroups" alt=""><span><strong>Scope Groups</strong><small>Resource scope</small></span><b class="nav-count">$($scopeGroups.Count)</b></button>
<button class="nav-item" type="button" data-view="scope-tags" data-title="Scope Tags" data-subtitle="Tags connected to role assignments"><img src="$iconDevices" alt=""><span><strong>Scope Tags</strong><small>Assignment tags</small></span><b class="nav-count">$($scopeTags.Count)</b></button>
<button class="nav-item" type="button" data-view="permissions" data-title="Permissions" data-subtitle="Exact Intune resource actions returned by roles"><img src="$iconLock" alt=""><span><strong>Permissions</strong><small>Observed actions</small></span><b class="nav-count">$($permissions.Count)</b></button>
<button class="nav-item" type="button" data-view="review" data-title="Review Notes" data-subtitle="Collection boundaries and evidence requiring review"><img src="$iconLightbulb" alt=""><span><strong>Review Notes</strong><small>Limits and warnings</small></span><b class="nav-count">$($warnings.Count)</b></button>
</nav></aside>
<main id="main-content" class="content-shell"><header class="page-heading"><div><p class="eyebrow">INTUNE EVIDENCE EXPLORER</p><h1 id="view-title">Overview</h1><p id="view-subtitle">Tenant-wide Intune access and assignment summary</p></div><button class="mobile-nav" id="mobile-nav" type="button" aria-controls="product-nav" aria-expanded="false">Sections</button><label class="search-control"><span class="eyebrow">FILTER CURRENT VIEW</span><input id="object-search" type="search" placeholder="Search names, IDs and descriptions" aria-label="Filter current view"></label></header>
<div class="workspace">
<div>
<section class="view-panel" data-view-panel="overview"><div class="summary-grid"><div class="summary-card"><small>Managed workloads</small><strong>$($workloadObjects.Count)</strong></div><div class="summary-card"><small>Workload targets</small><strong>$($workloadAssignments.Count)</strong></div><div class="summary-card"><small>Managed devices</small><strong>$($managedDevices.Count)</strong></div><div class="summary-card"><small>Reported outcomes</small><strong>$($deploymentOutcomes.Count)</strong></div></div><div class="overview-panel"><p class="eyebrow">EVIDENCE STARTING POINTS</p><h2>Who can change it, who should receive it and what Intune reported</h2><p>Open Policies and Apps to inspect configured targets, filters and exclusions. Use Device 360, User 360 and Deployment Outcomes for reported operational evidence. RBAC sections trace administrators, roles, scopes and permissions. Missing outcome data is never presented as success.</p><div class="overview-paths">$workloadRows</div></div></section>
<section class="view-panel" data-view-panel="workloads" hidden><div class="collection-list">$workloadRows</div></section>
<section class="view-panel" data-view-panel="workload-assignments" hidden><div class="collection-list">$workloadAssignmentRows</div></section>
<section class="view-panel" data-view-panel="target-groups" hidden><div class="collection-list">$workloadGroupRows</div></section>
<section class="view-panel" data-view-panel="assignment-filters" hidden><div class="collection-list">$filterRows</div></section>
<section class="view-panel" data-view-panel="managed-devices" hidden><div class="collection-list">$managedDeviceRows</div></section>
<section class="view-panel" data-view-panel="managed-users" hidden><div class="collection-list">$managedUserRows</div></section>
<section class="view-panel" data-view-panel="deployment-outcomes" hidden><div class="collection-list">$deploymentOutcomeRows</div></section>
<section class="view-panel" data-view-panel="policy-conflicts" hidden><div class="collection-list">$policyConflictRows</div></section>
<section class="view-panel" data-view-panel="policy-settings" hidden><div class="collection-list">$policySettingRows</div></section>
<section class="view-panel" data-view-panel="snapshot-changes" hidden><div class="collection-list">$snapshotChangeRows</div></section>
<section class="view-panel" data-view-panel="audit-events" hidden><div class="collection-list">$auditEventRows</div></section>
<section class="view-panel" data-view-panel="administrators" hidden><div class="collection-list">$administratorRows</div></section>
<section class="view-panel" data-view-panel="admin-groups" hidden><div class="collection-list">$groupRows</div></section>
<section class="view-panel" data-view-panel="assignments" hidden><div class="collection-list">$assignmentRows</div></section>
<section class="view-panel" data-view-panel="roles" hidden><div class="collection-list">$roleRows</div></section>
<section class="view-panel" data-view-panel="scope-groups" hidden><div class="collection-list">$scopeGroupRows</div></section>
<section class="view-panel" data-view-panel="scope-tags" hidden><div class="collection-list">$scopeTagRows</div></section>
<section class="view-panel" data-view-panel="permissions" hidden><div class="collection-list">$permissionRows</div></section>
<section class="view-panel" data-view-panel="review" hidden><div class="review-layout"><div><div class="review-card"><h2>Items requiring review</h2><ul>$warningItems</ul></div><div class="review-card"><h2>Workload collection status</h2><ul>$collectionItems</ul></div><div class="review-card"><h2>Outcome collection status</h2><ul>$outcomeStatusItems</ul></div><div class="review-card"><h2>Policy setting collection status</h2><ul>$policyStatusItems</ul></div><div class="review-card"><h2>Audit collection status</h2><ul>$auditStatusItem</ul></div></div><div class="review-card"><h2>Requested read scopes</h2><div class="scope-list">$scopeItems</div></div></div></section>
<footer class="report-footer"><span>Open-source Intune evidence explorer for auditors and administrators.</span><span>Generated locally by IntuneAccess $(ConvertTo-ExplorerText (Get-IntuneAccessProperty $TenantRbac 'ToolVersion')). No tenant data was sent to the project author.</span></footer>
</div>
<aside class="inspector" id="object-inspector" aria-live="polite"><div class="inspector-empty" id="inspector-empty"><img src="$iconQuestion" alt=""><p class="eyebrow">OBJECT INSPECTOR</p><h2>Select an Intune object</h2><p>Open a workload, target, administrator, role, scope or permission to inspect its relationships and evidence.</p></div>$inspectorPanels</aside>
</div></main></div>
<script>
(function(){
  'use strict';
  var navItems=Array.from(document.querySelectorAll('[data-view]'));
  var viewPanels=Array.from(document.querySelectorAll('[data-view-panel]'));
  var inspectorPanels=Array.from(document.querySelectorAll('[data-object-panel]'));
  var title=document.getElementById('view-title');
  var subtitle=document.getElementById('view-subtitle');
  var search=document.getElementById('object-search');
  var inspectorEmpty=document.getElementById('inspector-empty');
  var productNav=document.getElementById('product-nav');
  var mobileNav=document.getElementById('mobile-nav');
  function showView(name){
    viewPanels.forEach(function(panel){panel.hidden=panel.getAttribute('data-view-panel')!==name;});
    navItems.forEach(function(item){var selected=item.getAttribute('data-view')===name;item.classList.toggle('selected',selected);if(selected){item.setAttribute('aria-current','page');title.textContent=item.getAttribute('data-title');subtitle.textContent=item.getAttribute('data-subtitle');}else{item.removeAttribute('aria-current');}});
    search.value='';filterRows('');productNav.classList.remove('open');mobileNav.setAttribute('aria-expanded','false');
  }
  function inspectObject(key,view){
    if(view){showView(view);}
    var selected=null;
    inspectorPanels.forEach(function(panel){var match=panel.getAttribute('data-object-panel')===key;panel.hidden=!match;if(match){selected=panel;}});
    inspectorEmpty.hidden=!!selected;
    if(selected&&window.matchMedia('(max-width: 900px)').matches){selected.scrollIntoView({behavior:'smooth',block:'start'});}
  }
  function filterRows(value){
    var active=document.querySelector('[data-view-panel]:not([hidden])');
    if(!active){return;}
    var query=(value||'').trim().toLocaleLowerCase('en-GB');
    active.querySelectorAll('.object-row').forEach(function(row){row.hidden=!!query&&!row.getAttribute('data-search').toLocaleLowerCase('en-GB').includes(query);});
  }
  navItems.forEach(function(item){item.addEventListener('click',function(){showView(item.getAttribute('data-view'));});});
  document.addEventListener('click',function(event){var target=event.target.closest('[data-inspect]');if(target){inspectObject(target.getAttribute('data-inspect'),target.getAttribute('data-view-target'));}});
  search.addEventListener('input',function(){filterRows(search.value);});
  mobileNav.addEventListener('click',function(){var open=productNav.classList.toggle('open');mobileNav.setAttribute('aria-expanded',String(open));});
  var initial=document.body.getAttribute('data-initial-object');
  if(initial){inspectObject(initial,'overview');}
})();
</script>
</body>
</html>
"@
}
