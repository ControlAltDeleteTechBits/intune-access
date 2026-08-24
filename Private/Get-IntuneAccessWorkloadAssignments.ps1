function Get-IntuneAccessWorkloadAssignments {
    [CmdletBinding()]
    param(
        [switch] $ExcludeBeta
    )

    $context = Assert-IntuneAccessConnection
    $grantedScopes = @($context.Scopes)
    $workloads = [System.Collections.Generic.List[object]]::new()
    $assignments = [System.Collections.Generic.List[object]]::new()
    $collectionStatus = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $groupIds = [System.Collections.Generic.List[string]]::new()
    $filterIds = [System.Collections.Generic.List[string]]::new()

    $sources = @(
        [PSCustomObject] @{ Name = 'Device configuration'; Type = 'Configuration'; Uri = 'deviceManagement/deviceConfigurations'; ApiVersion = 'v1.0'; Permission = 'DeviceManagementConfiguration.Read.All' }
        [PSCustomObject] @{ Name = 'Compliance policies'; Type = 'Compliance'; Uri = 'deviceManagement/deviceCompliancePolicies'; ApiVersion = 'v1.0'; Permission = 'DeviceManagementConfiguration.Read.All' }
        [PSCustomObject] @{ Name = 'Applications'; Type = 'Applications'; Uri = 'deviceAppManagement/mobileApps'; ApiVersion = 'v1.0'; Permission = 'DeviceManagementApps.Read.All' }
        [PSCustomObject] @{ Name = 'Settings Catalog'; Type = 'Configuration'; Uri = 'deviceManagement/configurationPolicies'; ApiVersion = 'beta'; Permission = 'DeviceManagementConfiguration.Read.All' }
        [PSCustomObject] @{ Name = 'Endpoint security intents'; Type = 'Endpoint security'; Uri = 'deviceManagement/intents'; ApiVersion = 'beta'; Permission = 'DeviceManagementConfiguration.Read.All' }
        [PSCustomObject] @{ Name = 'PowerShell scripts'; Type = 'Scripts'; Uri = 'deviceManagement/deviceManagementScripts'; ApiVersion = 'beta'; Permission = 'DeviceManagementScripts.Read.All' }
        [PSCustomObject] @{ Name = 'Remediations'; Type = 'Remediations'; Uri = 'deviceManagement/deviceHealthScripts'; ApiVersion = 'beta'; Permission = 'DeviceManagementScripts.Read.All' }
        [PSCustomObject] @{ Name = 'Feature update policies'; Type = 'Updates'; Uri = 'deviceManagement/windowsFeatureUpdateProfiles'; ApiVersion = 'beta'; Permission = 'DeviceManagementConfiguration.Read.All' }
        [PSCustomObject] @{ Name = 'Quality update policies'; Type = 'Updates'; Uri = 'deviceManagement/windowsQualityUpdateProfiles'; ApiVersion = 'beta'; Permission = 'DeviceManagementConfiguration.Read.All' }
        [PSCustomObject] @{ Name = 'Driver update policies'; Type = 'Updates'; Uri = 'deviceManagement/windowsDriverUpdateProfiles'; ApiVersion = 'beta'; Permission = 'DeviceManagementConfiguration.Read.All' }
    )

    foreach ($source in $sources) {
        if ($source.ApiVersion -eq 'beta' -and $ExcludeBeta) {
            $collectionStatus.Add([PSCustomObject] @{ Source = $source.Name; State = 'Skipped'; ItemCount = 0; ApiVersion = $source.ApiVersion; Reason = 'Beta collection was disabled.' })
            continue
        }
        if ($source.Permission -notin $grantedScopes) {
            $reason = "The delegated session does not contain $($source.Permission)."
            $collectionStatus.Add([PSCustomObject] @{ Source = $source.Name; State = 'NotCollected'; ItemCount = 0; ApiVersion = $source.ApiVersion; Reason = $reason })
            $warnings.Add("$($source.Name) was not collected. $reason")
            continue
        }

        try {
            $sourceItems = @(Invoke-IntuneAccessGraphRequest -Uri $source.Uri -ApiVersion $source.ApiVersion)
        }
        catch {
            $reason = $_.Exception.Message
            $collectionStatus.Add([PSCustomObject] @{ Source = $source.Name; State = 'Unavailable'; ItemCount = 0; ApiVersion = $source.ApiVersion; Reason = $reason })
            $warnings.Add("$($source.Name) could not be collected. $reason")
            continue
        }

        $collectionStatus.Add([PSCustomObject] @{ Source = $source.Name; State = 'Available'; ItemCount = $sourceItems.Count; ApiVersion = $source.ApiVersion; Reason = '' })
        foreach ($sourceItem in $sourceItems) {
            $id = [string] (Get-IntuneAccessProperty $sourceItem 'id')
            if ([string]::IsNullOrWhiteSpace($id)) {
                $warnings.Add("$($source.Name) returned an object without an ID. The object was omitted.")
                continue
            }

            $name = [string] (Get-IntuneAccessProperty $sourceItem 'displayName' '')
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = [string] (Get-IntuneAccessProperty $sourceItem 'name' '[Unnamed object]')
            }
            $workloadType = Get-IntuneAccessWorkloadType -InputObject $sourceItem -DefaultType $source.Type
            $objectAssignments = @()
            $assignmentState = 'Available'
            try {
                $rawAssignments = @(Invoke-IntuneAccessGraphRequest -Uri "$($source.Uri)/$([uri]::EscapeDataString($id))/assignments" -ApiVersion $source.ApiVersion)
                $objectAssignments = @($rawAssignments | ForEach-Object {
                    ConvertTo-IntuneAccessWorkloadAssignment -Assignment $_ -WorkloadId $id -WorkloadName $name -WorkloadType $workloadType -ApiVersion $source.ApiVersion
                })
            }
            catch {
                $assignmentState = 'Unavailable'
                $warnings.Add("Assignments for $($source.Name) object '$name' could not be collected. $($_.Exception.Message)")
            }

            foreach ($assignment in $objectAssignments) {
                $assignments.Add($assignment)
                if (-not [string]::IsNullOrWhiteSpace($assignment.GroupId)) { $groupIds.Add($assignment.GroupId) }
                if (-not [string]::IsNullOrWhiteSpace($assignment.FilterId)) { $filterIds.Add($assignment.FilterId) }
            }

            $workloads.Add([PSCustomObject] @{
                PSTypeName          = 'IntuneAccess.WorkloadObject'
                Id                  = $id
                Name                = $name
                Description         = [string] (Get-IntuneAccessProperty $sourceItem 'description' '')
                WorkloadType        = $workloadType
                SourceCollection    = $source.Name
                Platform            = [string] (Get-IntuneAccessProperty $sourceItem 'platforms' (Get-IntuneAccessProperty $sourceItem 'operatingSystem' ''))
                Technologies        = [string] (Get-IntuneAccessProperty $sourceItem 'technologies' '')
                TargetVersion       = [string] (Get-IntuneAccessProperty $sourceItem 'featureUpdateVersion' (Get-IntuneAccessProperty $sourceItem 'releaseDateDisplayName' ''))
                DeadlineDateTime    = Get-IntuneAccessProperty $sourceItem 'rolloutSettings' (Get-IntuneAccessProperty $sourceItem 'deadlineDateTime')
                ODataType           = [string] (Get-IntuneAccessProperty $sourceItem '@odata.type' '')
                CreatedDateTime     = Get-IntuneAccessProperty $sourceItem 'createdDateTime'
                LastModifiedDateTime = Get-IntuneAccessProperty $sourceItem 'lastModifiedDateTime'
                ScopeTagIds         = @(Get-IntuneAccessProperty $sourceItem 'roleScopeTagIds' @())
                Assignments         = $objectAssignments
                AssignmentCount     = $objectAssignments.Count
                AssignmentDataState = $assignmentState
                SourceEndpoint      = $source.Uri
                SourceApiVersion    = $source.ApiVersion
            })
        }
    }

    $resolvedGroups = @(Resolve-IntuneAccessGroups -GroupId @($groupIds | Select-Object -Unique))
    $groupMap = @{}
    foreach ($group in $resolvedGroups) { $groupMap[[string] $group.Id] = $group }

    $filters = @()
    $filterState = 'NotRequired'
    if ($filterIds.Count -gt 0) {
        if ($ExcludeBeta) {
            $filterState = 'NotCollected'
            $warnings.Add('Assignment filter names were not collected because beta collection was disabled. Raw filter IDs are retained.')
        }
        elseif ('DeviceManagementConfiguration.Read.All' -notin $grantedScopes) {
            $filterState = 'NotCollected'
            $warnings.Add('Assignment filter names were not collected because DeviceManagementConfiguration.Read.All was not granted. Raw filter IDs are retained.')
        }
        else {
            try {
                $filters = @(Invoke-IntuneAccessGraphRequest -Uri 'deviceManagement/assignmentFilters' -ApiVersion beta | ForEach-Object {
                    [PSCustomObject] @{
                        PSTypeName       = 'IntuneAccess.AssignmentFilter'
                        Id               = [string] (Get-IntuneAccessProperty $_ 'id')
                        DisplayName      = [string] (Get-IntuneAccessProperty $_ 'displayName')
                        Description      = [string] (Get-IntuneAccessProperty $_ 'description')
                        Platform         = [string] (Get-IntuneAccessProperty $_ 'platform')
                        Rule             = [string] (Get-IntuneAccessProperty $_ 'rule')
                        SourceApiVersion = 'beta'
                    }
                })
                $filterState = 'Available'
            }
            catch {
                $filterState = 'Unavailable'
                $warnings.Add("Assignment filter names could not be collected. Raw filter IDs are retained. $($_.Exception.Message)")
            }
        }
    }

    $filterMap = @{}
    foreach ($filter in $filters) { $filterMap[[string] $filter.Id] = $filter }
    foreach ($assignment in $assignments) {
        if ($groupMap.ContainsKey([string] $assignment.GroupId)) { $assignment.Group = $groupMap[[string] $assignment.GroupId] }
        if ($filterMap.ContainsKey([string] $assignment.FilterId)) { $assignment.Filter = $filterMap[[string] $assignment.FilterId] }
    }

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.WorkloadInventory'
        Workloads            = $workloads.ToArray()
        Assignments          = $assignments.ToArray()
        Groups               = $resolvedGroups
        AssignmentFilters    = $filters
        AssignmentFilterState = $filterState
        CollectionStatus     = $collectionStatus.ToArray()
        Warnings             = $warnings.ToArray()
        GraphPermissionsUsed = @('DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All', 'DeviceManagementScripts.Read.All', 'GroupMember.Read.All')
        GeneratedAt          = [DateTimeOffset]::Now
        ToolVersion          = $script:IntuneAccessVersion
    }
}
