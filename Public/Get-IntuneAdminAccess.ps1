function Get-IntuneAdminAccess {
    <#
    .SYNOPSIS
    Explains the Intune RBAC access associated with an administrator.
    .DESCRIPTION
    Correlates the target user, group membership, role assignments, role definitions,
    scope groups and scope tags. Each permission retains its granting evidence.
    .PARAMETER UserPrincipalName
    The administrator's Microsoft Entra user principal name.
    .PARAMETER UserId
    The administrator's Microsoft Entra object ID.
    .EXAMPLE
    Get-IntuneAdminAccess -UserPrincipalName 'admin@contoso.com'
    .EXAMPLE
    Get-IntuneAdminAccess -UserId '00000000-0000-0000-0000-000000000000'
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByUpn')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByUpn')] [ValidateNotNullOrEmpty()] [string] $UserPrincipalName,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [guid] $UserId
    )

    $analysisScopes = @('User.Read', 'User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All')
    $context = Assert-IntuneAccessConnection -RequiredScope $analysisScopes
    $user = if ($PSCmdlet.ParameterSetName -eq 'ById') {
        Resolve-IntuneAccessUser -UserId $UserId
    }
    else {
        Resolve-IntuneAccessUser -UserPrincipalName $UserPrincipalName
    }

    $tenant = Get-IntuneAccessTenant
    $memberships = @(Get-IntuneAccessGroupMembership -UserId ([guid] $user.Id))
    $membershipById = @{}
    foreach ($membership in $memberships) {
        $membershipById[$membership.Id] = $membership
    }

    $warnings = [System.Collections.Generic.List[string]]::new()
    $definitions = @(Get-IntuneAccessRoleDefinitions)
    foreach ($definition in $definitions) {
        if ([string]::IsNullOrWhiteSpace([string] $definition.Id)) {
            $warnings.Add('A role definition did not return an ID. Its assignments could not be evaluated.')
        }
        if ((Get-IntuneAccessProperty $definition 'PermissionDataState' 'Available') -eq 'Missing') {
            $warnings.Add("Role '$($definition.DisplayName)' did not return rolePermissions. No permission conclusion was inferred from that role.")
        }
    }
    $allAssignments = @(Get-IntuneAccessRoleAssignments -RoleDefinition $definitions -ResolveNames)
    $relevantAssignments = [System.Collections.Generic.List[object]]::new()

    foreach ($assignment in $allAssignments) {
        if ([string]::IsNullOrWhiteSpace([string] $assignment.Id)) {
            $warnings.Add("Role '$($assignment.RoleDefinition.DisplayName)' returned an assignment without an ID. Its raw relationships are retained, but the source cannot be uniquely identified.")
        }
        if ((Get-IntuneAccessProperty $assignment 'AdminGroupDataState' 'Available') -eq 'Missing') {
            $warnings.Add("Assignment '$($assignment.Name)' did not return the members property. Administrator-group applicability could not be evaluated for that assignment.")
        }
    }

    foreach ($assignment in $allAssignments) {
        $matchingMemberships = [System.Collections.Generic.List[object]]::new()
        foreach ($adminGroupId in @($assignment.RawIds.AdminGroupIds)) {
            if ($membershipById.ContainsKey($adminGroupId)) {
                $matchingMemberships.Add($membershipById[$adminGroupId])
            }
        }
        if ($matchingMemberships.Count -eq 0) {
            continue
        }

        $hasDirectMembership = @($matchingMemberships | Where-Object MembershipType -EQ 'Direct').Count -gt 0
        $assignment.Applicability = if ($hasDirectMembership) { 'Confirmed' } else { 'NotEvaluated' }
        $assignment.AdminGroupEvidence = @($matchingMemberships | ForEach-Object {
            [PSCustomObject] @{
                GroupId         = $_.Id
                GroupName       = $_.DisplayName
                MembershipType  = $_.MembershipType
                EvidenceState   = if ($_.MembershipType -eq 'Direct') { 'Observed' } else { 'ObservedNested' }
            }
        })

        if (-not $hasDirectMembership) {
            $warnings.Add("Assignment '$($assignment.Name)' matched only through nested administrator-group membership. Intune's licence-dependent nested-group behaviour was not evaluated, so its permissions are marked NotEvaluated.")
        }
        if ((Get-IntuneAccessProperty $assignment 'ScopeTagDataState' 'Available') -eq 'Missing') {
            $warnings.Add("Assignment '$($assignment.Name)' did not return the beta roleScopeTagIds property. Scope-tag applicability is NotEvaluated; an empty value was not assumed.")
        }
        if ((Get-IntuneAccessProperty $assignment 'ScopeTypeDataState' 'Available') -eq 'Missing' -or
            (Get-IntuneAccessProperty $assignment 'ScopeGroupDataState' 'Available') -eq 'Missing') {
            $warnings.Add("Assignment '$($assignment.Name)' returned incomplete scope-group data. Resource scope applicability is NotEvaluated where that data is required.")
        }
        if ($assignment.ScopeType -notin @('resourceScope', 'allDevices', 'allLicensedUsers', 'allDevicesAndLicensedUsers')) {
            $warnings.Add("Assignment '$($assignment.Name)' returned scopeType '$($assignment.ScopeType)', which this version does not evaluate.")
        }
        foreach ($group in @($assignment.AdminGroups) + @($assignment.ScopeGroups)) {
            if ((Get-IntuneAccessProperty $group 'ResolutionState' 'Resolved') -eq 'Unresolved') {
                $warnings.Add("Group '$($group.Id)' on assignment '$($assignment.Name)' could not be resolved. The raw ID was retained.")
            }
        }
        foreach ($tag in @($assignment.ScopeTags)) {
            if ($tag.DisplayName -eq '[Unresolved scope tag]') {
                $warnings.Add("Scope tag '$($tag.Id)' on assignment '$($assignment.Name)' could not be resolved. The raw ID was retained.")
            }
        }
        if (@($assignment.RawIds.ScopeMemberIds).Count -gt 0 -and
            (@($assignment.RawIds.ScopeMemberIds) -join ',') -ne (@($assignment.RawIds.ScopeGroupIds) -join ',')) {
            $warnings.Add("Assignment '$($assignment.Name)' returned beta scopeMembers data that differs from v1-compatible resourceScopes. Both raw ID sets were retained; resourceScopes is used as Scope (Groups).")
        }

        $relevantAssignments.Add($assignment)
    }

    if ($relevantAssignments.Count -eq 0) {
        $warnings.Add('No matching Intune RBAC role assignment was found for the observed group memberships.')
    }
    $warnings.Add('The tenant setting for the March 2026 Scoped permissions preview is not exposed by a documented Graph contract used here. Permission sources are retained per assignment; cross-tag permission merging is not asserted.')
    $warnings.Add('Hidden Microsoft Entra group membership is not evaluated because Member.Read.Hidden is not requested by the default connection. An assignment through a hidden Admin Group might be absent from this result.')
    $warnings.Add('Microsoft Entra administrative roles are outside the Intune RBAC model evaluated by this command. They can provide additional Intune access that is not shown here.')

    $effectivePermissions = @(Resolve-IntuneAccessPermissions -RoleAssignment $relevantAssignments.ToArray())
    $scopeGroups = @($relevantAssignments | ForEach-Object ScopeGroups | Group-Object Id | ForEach-Object { $_.Group[0] })
    $scopeTags = @($relevantAssignments | ForEach-Object ScopeTags | Group-Object Id | ForEach-Object { $_.Group[0] })
    $adminGroups = @($relevantAssignments | ForEach-Object AdminGroups | Group-Object Id | ForEach-Object { $_.Group[0] })
    $evidence = @($relevantAssignments | ForEach-Object {
        $assignment = $_
        foreach ($group in @($assignment.AdminGroupEvidence)) {
            [PSCustomObject] @{
                UserId             = $user.Id
                UserPrincipalName  = $user.UserPrincipalName
                AdminGroupId       = $group.GroupId
                AdminGroupName     = $group.GroupName
                MembershipType     = $group.MembershipType
                RoleAssignmentId   = $assignment.Id
                RoleAssignmentName = $assignment.Name
                RoleDefinitionId   = $assignment.RoleDefinition.Id
                RoleDefinitionName = $assignment.RoleDefinition.DisplayName
                Applicability      = $assignment.Applicability
            }
        }
    })

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.AdminAccess'
        User                 = $user
        Tenant               = $tenant
        RoleAssignments      = $relevantAssignments.ToArray()
        EffectivePermissions = $effectivePermissions
        AdminGroups          = $adminGroups
        ScopeGroups          = $scopeGroups
        ScopeTags            = $scopeTags
        Warnings             = $warnings.ToArray()
        Evidence             = $evidence
        PermissionModel      = [PSCustomObject] @{
            ScopedPermissionsMode = 'Unknown'
            UnionRule             = 'Confirmed assignments are unioned by exact Graph action; evidence stays assignment-specific.'
            DenyRule              = 'No cross-assignment deny rule is inferred.'
        }
        GraphPermissionsUsed = $analysisScopes
        GraphPermissionsGranted = @($context.Scopes)
        GeneratedAt          = [DateTimeOffset]::Now
        ToolVersion          = $script:IntuneAccessVersion
    }
}
