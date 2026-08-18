function ConvertTo-IntuneAccessWorkloadAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Assignment,
        [Parameter(Mandatory)] [string] $WorkloadId,
        [Parameter(Mandatory)] [string] $WorkloadName,
        [Parameter(Mandatory)] [string] $WorkloadType,
        [Parameter(Mandatory)] [string] $ApiVersion
    )

    $target = Get-IntuneAccessProperty $Assignment 'target'
    $rawTargetType = [string] (Get-IntuneAccessProperty $target '@odata.type' '')
    $targetTypeKey = $rawTargetType.ToLowerInvariant()
    $groupId = [string] (Get-IntuneAccessProperty $target 'groupId' '')
    if ([string]::IsNullOrWhiteSpace($groupId)) {
        $groupId = [string] (Get-IntuneAccessProperty $target 'entraObjectId' '')
    }
    $collectionId = [string] (Get-IntuneAccessProperty $target 'collectionId' '')
    $filterId = [string] (Get-IntuneAccessProperty $target 'deviceAndAppManagementAssignmentFilterId' '')
    $filterMode = [string] (Get-IntuneAccessProperty $target 'deviceAndAppManagementAssignmentFilterType' 'none')

    $targetType = switch -Regex ($targetTypeKey) {
        'exclusiongroupassignmenttarget' { 'Excluded group'; break }
        'groupassignmenttarget' { 'Included group'; break }
        'alllicensedusersassignmenttarget' { 'All licensed users'; break }
        'allusersassignmenttarget' { 'All users'; break }
        'alldevicesassignmenttarget' { 'All devices'; break }
        'configurationmanagercollectionassignmenttarget' { 'Configuration Manager collection'; break }
        'scopetaggroupassignmenttarget' { 'Scope tag group'; break }
        default {
            $legacyTargetType = [string] (Get-IntuneAccessProperty $target 'targetType' '')
            if (-not [string]::IsNullOrWhiteSpace($legacyTargetType)) { $legacyTargetType } else { 'Unknown target' }
        }
    }

    $isExclusion = $targetType -eq 'Excluded group'
    $evidenceState = if ($isExclusion) {
        'ExcludedTarget'
    }
    elseif ($targetType -eq 'Unknown target') {
        'NotEvaluated'
    }
    else {
        'ConfirmedAssignment'
    }

    $intent = [string] (Get-IntuneAccessProperty $Assignment 'intent' '')
    if ([string]::IsNullOrWhiteSpace($intent)) {
        $intent = if ($isExclusion) { 'Exclude' } else { 'Assign' }
    }

    [PSCustomObject] @{
        PSTypeName       = 'IntuneAccess.WorkloadAssignment'
        Id               = [string] (Get-IntuneAccessProperty $Assignment 'id')
        WorkloadId       = $WorkloadId
        WorkloadName     = $WorkloadName
        WorkloadType     = $WorkloadType
        Intent           = $intent
        TargetType       = $targetType
        RawTargetType    = $rawTargetType
        GroupId          = $groupId
        Group            = $null
        CollectionId     = $collectionId
        FilterId         = $filterId
        FilterMode       = $filterMode
        Filter           = $null
        Source           = [string] (Get-IntuneAccessProperty $Assignment 'source' 'direct')
        SourceId         = [string] (Get-IntuneAccessProperty $Assignment 'sourceId' '')
        EvidenceState    = $evidenceState
        SourceApiVersion = $ApiVersion
    }
}
