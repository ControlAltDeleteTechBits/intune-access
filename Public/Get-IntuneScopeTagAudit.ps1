function Get-IntuneScopeTagAudit {
    <#
    .SYNOPSIS
    Finds evidence-led Intune scope-tag conditions worth reviewing.
    .DESCRIPTION
    Examines role assignments, device configurations and mobile apps. Findings are
    observations, not compliance failures or vulnerability claims.
    .PARAMETER IncludeExtendedResources
    Also examines compliance policies, Settings Catalog and endpoint security policies,
    remediations and device health scripts. Connect with ExtendedScopeTagAudit first.
    .EXAMPLE
    Get-IntuneScopeTagAudit
    #>
    [CmdletBinding()]
    param(
        [switch] $IncludeExtendedResources
    )

    $requiredScopes = @(
        'DeviceManagementRBAC.Read.All',
        'GroupMember.Read.All',
        'DeviceManagementConfiguration.Read.All',
        'DeviceManagementApps.Read.All'
    )
    if ($IncludeExtendedResources) { $requiredScopes += 'DeviceManagementScripts.Read.All' }
    $null = Assert-IntuneAccessConnection -RequiredScope $requiredScopes

    $definitions = @(Get-IntuneAccessRoleDefinitions)
    $assignments = @(Get-IntuneAccessRoleAssignments -RoleDefinition $definitions -ResolveNames)
    $tags = @()
    $tagCollectionError = $null
    try {
        $tags = @(Get-IntuneAccessScopeTags)
    }
    catch {
        $tagCollectionError = $_.Exception.Message
    }
    $resources = @(Get-IntuneAccessAuditedResources -IncludeExtended:$IncludeExtendedResources)
    $findings = [System.Collections.Generic.List[object]]::new()
    $sequence = 0

    $assignmentTagIds = @($assignments | ForEach-Object { $_.RawIds.ScopeTagIds } | Select-Object -Unique)
    $resourceTagIds = @($resources | ForEach-Object ScopeTagIds | Select-Object -Unique)
    $customAssignmentTagIds = @($assignmentTagIds | Where-Object { $_ -ne '0' })

    if ($null -ne $tagCollectionError) {
        $sequence++
        $findings.Add([PSCustomObject] @{
            PSTypeName              = 'IntuneAccess.ScopeTagFinding'
            FindingId               = 'IA-ST-{0:d3}' -f $sequence
            Title                   = 'Scope tag collection unavailable'
            Severity                = 'Warning'
            ResourceType            = 'Audit data source'
            ResourceName            = 'Intune role scope tags'
            ResourceId              = $null
            ObservedState           = "The beta scope tag collection could not be read. $tagCollectionError"
            ExpectedOrComparedState = 'Assignment and resource tag IDs are retained where their enrichment calls succeeded.'
            Evidence                = @()
            Recommendation          = 'Check the current beta API contract and rerun the audit before acting on unresolved or unused-tag findings.'
            DocumentationUrl        = 'https://learn.microsoft.com/en-us/graph/api/intune-rbac-rolescopetag-list?view=graph-rest-beta'
        })
    }

    foreach ($assignment in $assignments | Where-Object { (Get-IntuneAccessProperty $_ 'ScopeTagDataState' 'Available') -eq 'Missing' }) {
        $sequence++
        $findings.Add([PSCustomObject] @{
            PSTypeName              = 'IntuneAccess.ScopeTagFinding'
            FindingId               = 'IA-ST-{0:d3}' -f $sequence
            Title                   = 'Assignment scope-tag data unavailable'
            Severity                = 'Review'
            ResourceType            = 'Role assignment'
            ResourceName            = $assignment.Name
            ResourceId              = $assignment.Id
            ObservedState           = 'The beta roleScopeTagIds property was missing from the Graph response.'
            ExpectedOrComparedState = 'No empty or all-tags value was inferred.'
            Evidence                = @("Assignment:$($assignment.Id)")
            Recommendation          = 'Recheck the beta API response and current Microsoft Graph documentation.'
            DocumentationUrl        = 'https://learn.microsoft.com/en-us/graph/api/resources/intune-rbac-deviceandappmanagementroleassignment?view=graph-rest-beta'
        })
    }

    foreach ($resource in $resources) {
        if ((Get-IntuneAccessProperty $resource 'ScopeTagDataState' 'Available') -eq 'Missing') {
            $sequence++
            $findings.Add([PSCustomObject] @{
                PSTypeName              = 'IntuneAccess.ScopeTagFinding'
                FindingId               = 'IA-ST-{0:d3}' -f $sequence
                Title                   = 'Resource scope-tag data unavailable'
                Severity                = 'Review'
                ResourceType            = $resource.ResourceType
                ResourceName            = $resource.ResourceName
                ResourceId              = $resource.ResourceId
                ObservedState           = 'The beta roleScopeTagIds property was missing from the Graph response.'
                ExpectedOrComparedState = 'The resource was not treated as Default-tagged.'
                Evidence                = @("Resource:$($resource.ResourceId)")
                Recommendation          = 'Recheck the beta API response before drawing a visibility conclusion.'
                DocumentationUrl        = 'https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags'
            })
            continue
        }
        if ($resource.ScopeTagIds.Count -gt 1) {
            $sequence++
            $findings.Add([PSCustomObject] @{
                PSTypeName              = 'IntuneAccess.ScopeTagFinding'
                FindingId               = 'IA-ST-{0:d3}' -f $sequence
                Title                   = 'Several scope tags observed'
                Severity                = 'Information'
                ResourceType            = $resource.ResourceType
                ResourceName            = $resource.ResourceName
                ResourceId              = $resource.ResourceId
                ObservedState           = "Scope tag IDs: $($resource.ScopeTagIds -join ', ')"
                ExpectedOrComparedState = 'No organisational baseline supplied.'
                Evidence                = @($resource.ScopeTagIds)
                Recommendation          = 'Confirm that the combined visibility is intentional.'
                DocumentationUrl        = 'https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags'
            })
        }

        if ($resource.ScopeTagIds.Count -eq 1 -and $resource.ScopeTagIds[0] -eq '0' -and $customAssignmentTagIds.Count -gt 0) {
            $sequence++
            $findings.Add([PSCustomObject] @{
                PSTypeName              = 'IntuneAccess.ScopeTagFinding'
                FindingId               = 'IA-ST-{0:d3}' -f $sequence
                Title                   = 'Potential visibility mismatch'
                Severity                = 'Review'
                ResourceType            = $resource.ResourceType
                ResourceName            = $resource.ResourceName
                ResourceId              = $resource.ResourceId
                ObservedState           = 'The resource uses only the Default scope tag.'
                ExpectedOrComparedState = "Observed role assignments reference custom tag IDs: $($customAssignmentTagIds -join ', ')."
                Evidence                = @("Resource:$($resource.ResourceId)", "Tags:$($resource.ScopeTagIds -join ',')")
                Recommendation          = 'Check whether administrators limited to custom scope tags are expected to see this resource.'
                DocumentationUrl        = 'https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags'
            })
        }
    }

    foreach ($tagId in $assignmentTagIds) {
        if ($tagId -notin $resourceTagIds) {
            $tag = $tags | Where-Object Id -EQ $tagId | Select-Object -First 1
            $assignmentNames = @($assignments | Where-Object { $tagId -in $_.RawIds.ScopeTagIds } | ForEach-Object Name)
            $sequence++
            $findings.Add([PSCustomObject] @{
                PSTypeName              = 'IntuneAccess.ScopeTagFinding'
                FindingId               = 'IA-ST-{0:d3}' -f $sequence
                Title                   = 'Assignment scope tag not observed on examined resources'
                Severity                = 'Review'
                ResourceType            = 'Role assignment'
                ResourceName            = if ($null -ne $tag) { $tag.DisplayName } else { '[Unresolved scope tag]' }
                ResourceId              = $tagId
                ObservedState           = "Referenced by assignment(s): $($assignmentNames -join ', ')."
                ExpectedOrComparedState = 'No matching tag was found on the supported resources examined by this run.'
                Evidence                = @($assignmentNames)
                Recommendation          = 'Confirm whether the tag is intended for another supported Intune object type before changing anything.'
                DocumentationUrl        = 'https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags'
            })
        }
    }

    foreach ($tag in $tags | Where-Object { -not $_.IsBuiltIn }) {
        if ($tag.Id -notin $assignmentTagIds -and $tag.Id -notin $resourceTagIds) {
            $sequence++
            $findings.Add([PSCustomObject] @{
                PSTypeName              = 'IntuneAccess.ScopeTagFinding'
                FindingId               = 'IA-ST-{0:d3}' -f $sequence
                Title                   = 'Custom scope tag appears unused in the examined data'
                Severity                = 'Information'
                ResourceType            = 'Scope tag'
                ResourceName            = $tag.DisplayName
                ResourceId              = $tag.Id
                ObservedState           = 'No reference was observed in role assignments or the supported resources examined by this run.'
                ExpectedOrComparedState = 'The audit does not examine every Intune object type.'
                Evidence                = @("ScopeTag:$($tag.Id)")
                Recommendation          = 'Review its purpose and check other Intune object types before considering removal.'
                DocumentationUrl        = 'https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags'
            })
        }
    }

    if ($findings.Count -eq 0) {
        $findings.Add([PSCustomObject] @{
            PSTypeName              = 'IntuneAccess.ScopeTagFinding'
            FindingId               = 'IA-ST-000'
            Title                   = 'No review conditions found in supported object types'
            Severity                = 'Information'
            ResourceType            = 'Audit summary'
            ResourceName            = 'Scope tag audit'
            ResourceId              = $null
            ObservedState           = "Examined $($assignments.Count) role assignments and $($resources.Count) supported resources."
            ExpectedOrComparedState = if ($IncludeExtendedResources) { 'The extended supported resource set was examined.' } else { 'The base audit examines device configurations and mobile apps.' }
            Evidence                = @()
            Recommendation          = 'No action suggested.'
            DocumentationUrl        = 'https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags'
        })
    }

    return $findings.ToArray()
}
