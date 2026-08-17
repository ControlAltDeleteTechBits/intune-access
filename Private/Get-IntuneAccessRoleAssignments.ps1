function Get-IntuneAccessRoleAssignments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $RoleDefinition,
        [switch] $ResolveNames
    )

    $null = Assert-IntuneAccessConnection -RequiredScope 'DeviceManagementRBAC.Read.All'
    $rawAssignments = [System.Collections.Generic.List[object]]::new()
    foreach ($definition in $RoleDefinition) {
        $definitionId = [string] (Get-IntuneAccessProperty $definition 'Id')
        if ([string]::IsNullOrWhiteSpace($definitionId)) {
            Write-Warning "A role definition did not return an ID. Its assignments cannot be retrieved, so that role is not evaluated."
            continue
        }

        # v1.0 is authoritative for stable assignment data. Beta is isolated enrichment
        # for roleScopeTagIds, scopeMembers and scopeType, which v1.0 does not expose.
        $uri = "deviceManagement/roleDefinitions/$definitionId/roleAssignments"
        $listedAssignments = @(Invoke-IntuneAccessGraphRequest -Uri $uri)

        foreach ($listedAssignment in $listedAssignments) {
            $assignment = $listedAssignment
            $assignmentId = [string] (Get-IntuneAccessProperty $listedAssignment 'id')
            $betaAssignment = $null

            # Graph's assignment collection can return the assignment identities with
            # empty members and scope arrays. Hydrate each item from its detail endpoint
            # before evaluating access so a valid positive assignment is not omitted.
            if (-not [string]::IsNullOrWhiteSpace($assignmentId)) {
                try {
                    $stableDetail = @(Invoke-IntuneAccessGraphRequest -Uri "$uri/$assignmentId")
                    if ($stableDetail.Count -gt 0) {
                        $assignment = $stableDetail[0]
                    }
                }
                catch {
                    Write-Warning "Stable detail retrieval failed for role assignment '$assignmentId'. Collection data is retained, but member and scope data may be incomplete. $($_.Exception.Message)"
                }

                try {
                    $betaDetail = @(Invoke-IntuneAccessGraphRequest -Uri "$uri/$assignmentId" -ApiVersion beta)
                    if ($betaDetail.Count -gt 0) {
                        $betaAssignment = $betaDetail[0]
                    }
                }
                catch {
                    Write-Warning "Beta enrichment failed for role assignment '$assignmentId'. Stable v1.0 assignment data is retained, while scope type and scope tags are marked missing. $($_.Exception.Message)"
                }
            }

            $rawAssignments.Add([PSCustomObject] @{
                Stable         = $assignment
                Beta           = $betaAssignment
                RoleDefinition = $definition
            })
        }
    }

    $allTags = @()
    $allGroups = @()
    if ($ResolveNames) {
        try {
            $allTags = @(Get-IntuneAccessScopeTags)
        }
        catch {
            Write-Warning "Scope tag names could not be retrieved from beta. Assignment tag IDs are retained with unresolved display names. $($_.Exception.Message)"
        }
        $allGroupIds = @($rawAssignments | ForEach-Object {
            @(Get-IntuneAccessProperty $_.Stable 'members' @())
            @(Get-IntuneAccessProperty $_.Stable 'resourceScopes' @())
        } | ForEach-Object { [string] $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        $allGroups = @(Resolve-IntuneAccessGroups -GroupId $allGroupIds)
    }

    $output = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $rawAssignments) {
        $assignment = $entry.Stable
        $betaAssignment = $entry.Beta
        $definition = $entry.RoleDefinition
        $missingValue = [object]::new()
        $adminGroupValue = Get-IntuneAccessProperty $assignment 'members' $missingValue
        $scopeGroupValue = Get-IntuneAccessProperty $assignment 'resourceScopes' $missingValue
        $scopeMemberValue = Get-IntuneAccessProperty $betaAssignment 'scopeMembers' $missingValue
        $scopeTagValue = Get-IntuneAccessProperty $betaAssignment 'roleScopeTagIds' $missingValue
        $scopeTypeValue = Get-IntuneAccessProperty $betaAssignment 'scopeType' $missingValue
        $adminGroupIds = @(
            $(if ([object]::ReferenceEquals($adminGroupValue, $missingValue)) { @() } else { @($adminGroupValue) }) |
                ForEach-Object { [string] $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $scopeGroupIds = @(
            $(if ([object]::ReferenceEquals($scopeGroupValue, $missingValue)) { @() } else { @($scopeGroupValue) }) |
                ForEach-Object { [string] $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $scopeMemberIds = @(
            $(if ([object]::ReferenceEquals($scopeMemberValue, $missingValue)) { @() } else { @($scopeMemberValue) }) |
                ForEach-Object { [string] $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $scopeTagIds = @(
            $(if ([object]::ReferenceEquals($scopeTagValue, $missingValue)) { @() } else { @($scopeTagValue) }) |
                ForEach-Object { [string] $_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $scopeType = if ([object]::ReferenceEquals($scopeTypeValue, $missingValue)) { 'unknown' } else { [string] $scopeTypeValue }

        $adminGroups = if ($ResolveNames) {
            @($adminGroupIds | ForEach-Object {
                $groupId = $_
                $allGroups | Where-Object Id -EQ $groupId | Select-Object -First 1
            })
        }
        else { @() }
        $scopeGroups = if ($ResolveNames) {
            @($scopeGroupIds | ForEach-Object {
                $groupId = $_
                $allGroups | Where-Object Id -EQ $groupId | Select-Object -First 1
            })
        }
        else { @() }
        $scopeTags = if ($ResolveNames) {
            @($scopeTagIds | ForEach-Object {
                $tagId = $_
                $resolved = $allTags | Where-Object Id -EQ $tagId | Select-Object -First 1
                if ($null -ne $resolved) {
                    $resolved
                }
                else {
                    [PSCustomObject] @{ Id = $tagId; DisplayName = '[Unresolved scope tag]'; IsBuiltIn = $null; SourceApiVersion = 'beta' }
                }
            })
        }
        else { @() }

        $output.Add([PSCustomObject] @{
            PSTypeName          = 'IntuneAccess.RoleAssignment'
            Id                  = [string] (Get-IntuneAccessProperty $assignment 'id')
            Name                = [string] (Get-IntuneAccessProperty $assignment 'displayName')
            Description         = [string] (Get-IntuneAccessProperty $assignment 'description')
            RoleDefinition      = $definition
            AdminGroups         = $adminGroups
            AdminGroupDataState = if ([object]::ReferenceEquals($adminGroupValue, $missingValue)) { 'Missing' } else { 'Available' }
            ScopeGroups         = $scopeGroups
            ScopeType           = $scopeType
            ScopeTypeDataState  = if ([object]::ReferenceEquals($scopeTypeValue, $missingValue)) { 'Missing' } else { 'Available' }
            ScopeTags           = $scopeTags
            ScopeTagDataState   = if ([object]::ReferenceEquals($scopeTagValue, $missingValue)) { 'Missing' } else { 'Available' }
            ScopeGroupDataState = if ([object]::ReferenceEquals($scopeGroupValue, $missingValue)) { 'Missing' } else { 'Available' }
            Permissions         = @(Get-IntuneAccessAllowedActions -RoleDefinition $definition)
            Applicability       = 'NotAssessed'
            AdminGroupEvidence  = @()
            SourceApiVersion    = 'v1.0+beta'
            PropertySource      = [PSCustomObject] @{
                IdentityAndMembers = 'v1.0'
                ScopeGroups       = 'v1.0'
                ScopeType         = if ([object]::ReferenceEquals($scopeTypeValue, $missingValue)) { 'Missing' } else { 'beta' }
                ScopeMembers      = if ([object]::ReferenceEquals($scopeMemberValue, $missingValue)) { 'Missing' } else { 'beta' }
                ScopeTags         = if ([object]::ReferenceEquals($scopeTagValue, $missingValue)) { 'Missing' } else { 'beta' }
            }
            RawIds              = [PSCustomObject] @{
                AdminGroupIds  = $adminGroupIds
                ScopeGroupIds  = $scopeGroupIds
                ScopeMemberIds = $scopeMemberIds
                ScopeTagIds    = $scopeTagIds
            }
        })
    }

    return $output.ToArray()
}
