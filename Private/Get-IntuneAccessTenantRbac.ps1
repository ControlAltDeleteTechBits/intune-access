function Get-IntuneAccessTenantRbac {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $InitialUserPrincipalName,

        [switch] $IncludeWorkloadAssignments,

        [switch] $IncludeOperationalEvidence,
        [switch] $IncludePolicyAnalysis,

        [switch] $IncludeDeviceIntelligence,
        [switch] $IncludeAssignmentExplanations,
        [switch] $IncludeAutopilot,
        [switch] $IncludeApplicationEvidence,
        [switch] $IncludeUpdateCompliance,
        [switch] $IncludeEstateIntelligence,

        [switch] $IncludeAuditEvidence
    )

    $analysisScopes = @('User.Read', 'User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All')
    $context = Assert-IntuneAccessConnection -RequiredScope $analysisScopes
    $tenant = Get-IntuneAccessTenant
    $allDefinitions = @(Get-IntuneAccessRoleDefinitions)
    $assignments = @(Get-IntuneAccessRoleAssignments -RoleDefinition $allDefinitions -ResolveNames)
    $adminGroups = @($assignments | ForEach-Object AdminGroups | Where-Object { $null -ne $_ } | Group-Object Id | ForEach-Object { $_.Group[0] })
    $scopeGroups = @($assignments | ForEach-Object ScopeGroups | Where-Object { $null -ne $_ } | Group-Object Id | ForEach-Object { $_.Group[0] })
    $scopeTags = @($assignments | ForEach-Object ScopeTags | Where-Object { $null -ne $_ } | Group-Object Id | ForEach-Object { $_.Group[0] })
    $connectedRoleIds = @($assignments | ForEach-Object { [string] $_.RoleDefinition.Id } | Where-Object { $_ } | Select-Object -Unique)
    $roleDefinitions = @($allDefinitions | Where-Object Id -In $connectedRoleIds)
    $memberships = @(Get-IntuneAccessAdminGroupUsers -Group $adminGroups)
    $administrators = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $workloadInventory = $null
    $operationalEvidence = $null
    $policyAnalysis = $null
    $auditEvidence = $null
    $deviceIntelligence = $null
    $assignmentExplanations = $null
    $autopilotEvidence = $null
    $applicationEvidence = $null
    $updateComplianceEvidence = $null
    $estateInsight = $null

    foreach ($userGroup in @($memberships | Group-Object { $_.User.Id })) {
        $userMemberships = @($userGroup.Group)
        $user = $userMemberships[0].User
        $membershipByGroupId = @{}
        foreach ($membership in $userMemberships) {
            $membershipByGroupId[$membership.GroupId] = $membership
        }

        $userAssignments = [System.Collections.Generic.List[object]]::new()
        foreach ($assignment in $assignments) {
            $matchingMemberships = @($assignment.RawIds.AdminGroupIds | Where-Object { $membershipByGroupId.ContainsKey([string] $_) } | ForEach-Object { $membershipByGroupId[[string] $_] })
            if ($matchingMemberships.Count -eq 0) {
                continue
            }

            $assignmentView = $assignment | Select-Object *
            $hasDirectMembership = @($matchingMemberships | Where-Object MembershipType -EQ 'Direct').Count -gt 0
            $assignmentView | Add-Member -NotePropertyName Applicability -NotePropertyValue $(if ($hasDirectMembership) { 'Confirmed' } else { 'NotEvaluated' }) -Force
            $assignmentView | Add-Member -NotePropertyName AdminGroupEvidence -NotePropertyValue @($matchingMemberships | ForEach-Object {
                [PSCustomObject] @{
                    GroupId        = $_.GroupId
                    GroupName      = $_.GroupName
                    MembershipType = $_.MembershipType
                    EvidenceState  = if ($_.MembershipType -eq 'Direct') { 'Observed' } else { 'ObservedNested' }
                }
            }) -Force
            $assignmentView.PSObject.TypeNames.Insert(0, 'IntuneAccess.RoleAssignment')
            $userAssignments.Add($assignmentView)
        }

        $effectivePermissions = @(Resolve-IntuneAccessPermissions -RoleAssignment $userAssignments.ToArray())
        $administrators.Add([PSCustomObject] @{
            PSTypeName           = 'IntuneAccess.TenantAdministrator'
            User                 = $user
            AdminGroupMemberships = $userMemberships
            RoleAssignments      = $userAssignments.ToArray()
            EffectivePermissions = $effectivePermissions
            ConfirmedAssignments = @($userAssignments | Where-Object Applicability -EQ 'Confirmed').Count
            ReviewAssignments    = @($userAssignments | Where-Object Applicability -NE 'Confirmed').Count
        })
    }

    $permissionRows = @($assignments | ForEach-Object {
        $assignment = $_
        foreach ($action in @($assignment.Permissions)) {
            $friendly = ConvertFrom-IntuneAccessActionName -Action ([string] $action)
            [PSCustomObject] @{
                RawAction          = [string] $action
                Resource           = $friendly.Resource
                Operation          = $friendly.Operation
                RoleAssignmentId   = $assignment.Id
                RoleAssignmentName = $assignment.Name
                RoleDefinitionId   = $assignment.RoleDefinition.Id
                RoleDefinitionName = $assignment.RoleDefinition.DisplayName
            }
        }
    })
    $permissions = @($permissionRows | Group-Object RawAction | ForEach-Object {
        $sources = @($_.Group)
        $assignmentIds = @($sources.RoleAssignmentId | Select-Object -Unique)
        $administratorCount = @($administrators | Where-Object {
            @($_.RoleAssignments.Id | Where-Object { $_ -in $assignmentIds }).Count -gt 0
        }).Count
        [PSCustomObject] @{
            PSTypeName       = 'IntuneAccess.TenantPermission'
            RawAction        = $_.Name
            Resource         = $sources[0].Resource
            Operation        = $sources[0].Operation
            RoleAssignments  = @($sources | Sort-Object RoleAssignmentName -Unique)
            RoleDefinitions  = @($sources | Select-Object RoleDefinitionId, RoleDefinitionName -Unique)
            AdministratorCount = $administratorCount
        }
    } | Sort-Object Resource, Operation)

    if ($assignments.Count -eq 0) {
        $warnings.Add('No Intune RBAC role assignments were returned by Microsoft Graph.')
    }
    elseif ($administrators.Count -eq 0) {
        $warnings.Add('Intune role assignments were found, but no users were returned from their resolved Admin Groups.')
    }
    if (@($memberships | Where-Object MembershipType -EQ 'Nested').Count -gt 0) {
        $warnings.Add('Nested Admin Group memberships are shown as NotEvaluated because Intune behaviour can depend on tenant configuration and licensing.')
    }
    if (@($adminGroups | Where-Object ResolutionState -EQ 'Unresolved').Count -gt 0) {
        $warnings.Add('One or more Admin Groups could not be resolved. Their raw IDs remain available in role assignment evidence.')
    }
    $warnings.Add('Hidden Microsoft Entra group membership is not evaluated because Member.Read.Hidden is not requested.')
    $warnings.Add('Microsoft Entra administrative roles are outside the Intune RBAC model and can provide additional Intune access not shown here.')
    $warnings.Add('The active March 2026 Scoped permissions model is not exposed by a documented Microsoft Graph contract used here.')

    if ($IncludeWorkloadAssignments -or $IncludeOperationalEvidence -or $IncludePolicyAnalysis -or $IncludeAssignmentExplanations -or $IncludeApplicationEvidence -or $IncludeUpdateCompliance -or $IncludeEstateIntelligence) {
        $workloadInventory = Get-IntuneAccessWorkloadAssignments
        foreach ($warning in @($workloadInventory.Warnings)) {
            $warnings.Add([string] $warning)
        }
    }

    if ($IncludeOperationalEvidence -or $IncludeDeviceIntelligence -or $IncludeAssignmentExplanations -or $IncludeAutopilot -or $IncludeApplicationEvidence -or $IncludeUpdateCompliance -or $IncludeEstateIntelligence) {
        $operationalEvidence = Get-IntuneAccessOperationalEvidence -Workload $workloadInventory.Workloads
        foreach ($warning in @($operationalEvidence.Warnings)) {
            $warnings.Add([string] $warning)
        }
    }

    if ($IncludeDeviceIntelligence -or $IncludeEstateIntelligence) {
        $deviceIntelligence = Get-IntuneAccessDeviceIntelligence -ManagedDevice $operationalEvidence.ManagedDevices
        foreach ($warning in @($deviceIntelligence.Warnings)) { $warnings.Add([string] $warning) }
    }
    if ($IncludeAssignmentExplanations) {
        $assignmentExplanations = Get-IntuneAccessFleetAssignmentExplanation -ManagedDevice $operationalEvidence.ManagedDevices -Workload $workloadInventory.Workloads -Assignment $workloadInventory.Assignments -DeploymentOutcome $operationalEvidence.DeploymentOutcomes
        foreach ($warning in @($assignmentExplanations.Warnings)) { $warnings.Add([string] $warning) }
    }
    if ($IncludeAutopilot) {
        $autopilotEvidence = Get-IntuneAccessAutopilotEvidence -ManagedDevice $operationalEvidence.ManagedDevices
        foreach ($warning in @($autopilotEvidence.Warnings)) { $warnings.Add([string] $warning) }
    }
    if ($IncludeApplicationEvidence -or $IncludeEstateIntelligence) {
        $applicationEvidence = Get-IntuneAccessApplicationEvidence -Workload $workloadInventory.Workloads -Assignment $workloadInventory.Assignments -ManagedDevice $operationalEvidence.ManagedDevices -DeploymentOutcome $operationalEvidence.DeploymentOutcomes
        foreach ($warning in @($applicationEvidence.Warnings)) { $warnings.Add([string] $warning) }
    }
    if ($IncludeUpdateCompliance -or $IncludeEstateIntelligence) {
        $updateComplianceEvidence = Get-IntuneAccessUpdateComplianceEvidence -Workload $workloadInventory.Workloads -Assignment $workloadInventory.Assignments -ManagedDevice $operationalEvidence.ManagedDevices -DeploymentOutcome $operationalEvidence.DeploymentOutcomes
        foreach ($warning in @($updateComplianceEvidence.Warnings)) { $warnings.Add([string] $warning) }
    }
    if ($IncludeEstateIntelligence) {
        $estateInsight = Get-IntuneAccessEstateInsight -DeviceIntelligence $deviceIntelligence -ApplicationEvidence $applicationEvidence -UpdateComplianceEvidence $updateComplianceEvidence -AutopilotEvidence $autopilotEvidence -DeploymentOutcome $operationalEvidence.DeploymentOutcomes
    }

    if ($IncludePolicyAnalysis) {
        $policyAnalysis = Get-IntunePolicyConflict -Workload @($workloadInventory.Workloads) -Assignment @($workloadInventory.Assignments)
        foreach ($warning in @($policyAnalysis.Warnings)) { $warnings.Add([string] $warning) }
    }
    if ($IncludeAuditEvidence) {
        $auditEvidence = Get-IntuneAccessAuditEvents
        foreach ($warning in @($auditEvidence.Warnings)) { $warnings.Add([string] $warning) }
    }

    $workloadObjects = if ($null -eq $workloadInventory) { @() } else { @($workloadInventory.Workloads) }
    $workloadAssignments = if ($null -eq $workloadInventory) { @() } else { @($workloadInventory.Assignments) }
    $workloadGroups = if ($null -eq $workloadInventory) { @() } else { @($workloadInventory.Groups) }
    $assignmentFilters = if ($null -eq $workloadInventory) { @() } else { @($workloadInventory.AssignmentFilters) }
    $workloadCollectionStatus = if ($null -eq $workloadInventory) { @() } else { @($workloadInventory.CollectionStatus) }
    $managedDevices = if ($null -eq $operationalEvidence) { @() } else { @($operationalEvidence.ManagedDevices) }
    $managedUsers = if ($null -eq $operationalEvidence) { @() } else { @($operationalEvidence.ManagedUsers) }
    $deploymentOutcomes = if ($null -eq $operationalEvidence) { @() } else { @($operationalEvidence.DeploymentOutcomes) }
    $outcomeCollectionStatus = if ($null -eq $operationalEvidence) { @() } else { @($operationalEvidence.CollectionStatus) }
    $policySettings = if ($null -eq $policyAnalysis) { @() } else { @($policyAnalysis.PolicySettings) }
    $policyConflictFindings = if ($null -eq $policyAnalysis) { @() } else { @($policyAnalysis.Findings) }
    $policyConflictCollectionStatus = if ($null -eq $policyAnalysis) { @() } else { @($policyAnalysis.CollectionStatus) }
    $auditEvents = if ($null -eq $auditEvidence) { @() } else { @($auditEvidence.Events) }
    $auditCollectionStatus = if ($null -eq $auditEvidence) { $null } else { $auditEvidence.CollectionStatus }
    $deviceInventory = if ($null -eq $deviceIntelligence) { @() } else { @($deviceIntelligence.Inventory) }
    $deviceFindings = if ($null -eq $deviceIntelligence) { @() } else { @($deviceIntelligence.Findings) }
    $deviceIntelligenceStatus = if ($null -eq $deviceIntelligence) { $null } else { $deviceIntelligence.CollectionStatus }
    $deviceAssignmentExplanations = if ($null -eq $assignmentExplanations) { @() } else { @($assignmentExplanations.Explanations) }
    $assignmentExplanationStatus = if ($null -eq $assignmentExplanations) { $null } else { $assignmentExplanations.CollectionStatus }
    $autopilotTimelines = if ($null -eq $autopilotEvidence) { @() } else { @($autopilotEvidence.Timelines) }
    $autopilotProfiles = if ($null -eq $autopilotEvidence) { @() } else { @($autopilotEvidence.DeploymentProfiles) }
    $espProfiles = if ($null -eq $autopilotEvidence) { @() } else { @($autopilotEvidence.EspProfiles) }
    $autopilotCollectionStatus = if ($null -eq $autopilotEvidence) { @() } else { @($autopilotEvidence.CollectionStatus) }
    $applicationDefinitions = if ($null -eq $applicationEvidence) { @() } else { @($applicationEvidence.ApplicationDefinitions) }
    $detectedApplications = if ($null -eq $applicationEvidence) { @() } else { @($applicationEvidence.DetectedApplications) }
    $deviceApplicationEvidence = if ($null -eq $applicationEvidence) { @() } else { @($applicationEvidence.DeviceApplicationEvidence) }
    $applicationCollectionStatus = if ($null -eq $applicationEvidence) { @() } else { @($applicationEvidence.CollectionStatus) }
    $updateComplianceInvestigations = if ($null -eq $updateComplianceEvidence) { @() } else { @($updateComplianceEvidence.Investigations) }
    $updateComplianceCollectionStatus = if ($null -eq $updateComplianceEvidence) { $null } else { $updateComplianceEvidence.CollectionStatus }
    $estateFindings = if ($null -eq $estateInsight) { @() } else { @($estateInsight.PrioritisedFindings) }
    $recurringFailures = if ($null -eq $estateInsight) { @() } else { @($estateInsight.RecurringFailures) }
    $deviceCohorts = if ($null -eq $estateInsight) { @() } else { @($estateInsight.Cohorts) }
    $crossDeviceInvestigations = if ($null -eq $estateInsight) { @() } else { @($estateInsight.CrossDeviceInvestigations) }
    $estateHistoricalTrend = if ($null -eq $estateInsight) { $null } else { $estateInsight.HistoricalTrend }
    $shareSafeBundle = if ($null -eq $estateInsight) { $null } else { $estateInsight.ShareSafeBundle }
    $permissionsUsed = @($analysisScopes)
    if ($null -ne $workloadInventory) {
        $permissionsUsed = @($permissionsUsed + @($workloadInventory.GraphPermissionsUsed) | Select-Object -Unique)
    }
    if ($null -ne $operationalEvidence) {
        $permissionsUsed = @($permissionsUsed + @($operationalEvidence.GraphPermissionsUsed) | Select-Object -Unique)
    }
    if ($null -ne $auditEvidence) {
        $permissionsUsed = @($permissionsUsed + @($auditEvidence.GraphPermissionsUsed) | Select-Object -Unique)
    }
    foreach ($evidenceSource in @($deviceIntelligence, $autopilotEvidence, $applicationEvidence, $updateComplianceEvidence)) {
        if ($null -ne $evidenceSource) { $permissionsUsed = @($permissionsUsed + @($evidenceSource.GraphPermissionsUsed) | Select-Object -Unique) }
    }

    $result = [PSCustomObject] @{
        PSTypeName              = 'IntuneAccess.TenantRbac'
        Tenant                 = $tenant
        Administrators         = @($administrators | Sort-Object { $_.User.UserPrincipalName })
        AdminGroups            = @($adminGroups | Sort-Object DisplayName)
        RoleAssignments        = @($assignments | Sort-Object Name)
        RoleDefinitions        = @($roleDefinitions | Sort-Object DisplayName)
        ScopeGroups            = @($scopeGroups | Sort-Object DisplayName)
        ScopeTags              = @($scopeTags | Sort-Object DisplayName)
        Permissions            = $permissions
        Memberships            = $memberships
        WorkloadObjects        = $workloadObjects
        WorkloadAssignments    = $workloadAssignments
        WorkloadGroups         = $workloadGroups
        AssignmentFilters      = $assignmentFilters
        WorkloadCollectionStatus = $workloadCollectionStatus
        ManagedDevices         = $managedDevices
        ManagedUsers           = $managedUsers
        DeploymentOutcomes     = $deploymentOutcomes
        OutcomeCollectionStatus = $outcomeCollectionStatus
        PolicySettings          = $policySettings
        PolicyConflictFindings  = $policyConflictFindings
        PolicyConflictCollectionStatus = $policyConflictCollectionStatus
        AuditEvents             = $auditEvents
        AuditCollectionStatus   = $auditCollectionStatus
        DeviceInventory         = $deviceInventory
        DeviceFindings          = $deviceFindings
        DeviceIntelligenceStatus = $deviceIntelligenceStatus
        DeviceAssignmentExplanations = $deviceAssignmentExplanations
        AssignmentExplanationStatus = $assignmentExplanationStatus
        AutopilotTimelines      = $autopilotTimelines
        AutopilotProfiles       = $autopilotProfiles
        EspProfiles             = $espProfiles
        AutopilotCollectionStatus = $autopilotCollectionStatus
        ApplicationDefinitions = $applicationDefinitions
        DetectedApplications    = $detectedApplications
        DeviceApplicationEvidence = $deviceApplicationEvidence
        ApplicationCollectionStatus = $applicationCollectionStatus
        UpdateComplianceInvestigations = $updateComplianceInvestigations
        UpdateComplianceCollectionStatus = $updateComplianceCollectionStatus
        EstateFindings          = $estateFindings
        RecurringFailures       = $recurringFailures
        DeviceCohorts           = $deviceCohorts
        CrossDeviceInvestigations = $crossDeviceInvestigations
        EstateHistoricalTrend   = $estateHistoricalTrend
        ShareSafeBundle         = $shareSafeBundle
        Warnings               = $warnings.ToArray()
        InitialUserPrincipalName = $InitialUserPrincipalName
        GraphPermissionsUsed   = $permissionsUsed
        GraphPermissionsGranted = @($context.Scopes)
        GeneratedAt            = [DateTimeOffset]::Now
        ToolVersion            = $script:IntuneAccessVersion
    }
    $result | Add-Member -NotePropertyName ActionCentre -NotePropertyValue (Get-IntuneAccessActionCentre -Collection $result)
    $result
}
