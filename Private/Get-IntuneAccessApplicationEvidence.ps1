function Get-IntuneAccessApplicationEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Workload,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Assignment,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $ManagedDevice,
        [AllowEmptyCollection()] [object[]] $DeploymentOutcome = @(),
        [ValidateRange(1, 5000)] [int] $MaximumRelationshipQueries = 500
    )

    $null = Assert-IntuneAccessConnection -RequiredScope @('DeviceManagementApps.Read.All', 'DeviceManagementManagedDevices.Read.All')
    $warnings = [System.Collections.Generic.List[string]]::new()
    $statuses = [System.Collections.Generic.List[object]]::new()
    $detectedApps = @()
    try {
        $detectedApps = @(Invoke-IntuneAccessGraphRequest -Uri 'deviceManagement/detectedApps?$select=id,displayName,version,sizeInByte,deviceCount,publisher,platform' -ApiVersion v1.0)
        $statuses.Add([PSCustomObject] @{ Source = 'Detected applications'; State = 'Available'; RecordCount = $detectedApps.Count; ApiVersion = 'v1.0'; Reason = '' })
    }
    catch {
        $warnings.Add("Detected applications could not be collected. $($_.Exception.Message)")
        $statuses.Add([PSCustomObject] @{ Source = 'Detected applications'; State = 'Unavailable'; RecordCount = 0; ApiVersion = 'v1.0'; Reason = $_.Exception.Message })
    }

    $detectedRecords = [System.Collections.Generic.List[object]]::new()
    $queryCandidates = @($detectedApps | Where-Object { [int64] (Get-IntuneAccessProperty $_ 'deviceCount' 0) -gt 0 })
    $queryCount = 0
    foreach ($detected in $queryCandidates) {
        $deviceLinks = @()
        $state = 'Available'
        if ($queryCount -ge $MaximumRelationshipQueries) { $state = 'NotCollected' }
        else {
            try {
                $queryCount++
                $deviceLinks = @(Invoke-IntuneAccessGraphRequest -Uri "deviceManagement/detectedApps/$([uri]::EscapeDataString([string] (Get-IntuneAccessProperty $detected 'id')))/managedDevices?`$select=id,deviceName,lastSyncDateTime" -ApiVersion v1.0)
            }
            catch {
                $state = 'Unavailable'
                $warnings.Add("Device relationships for detected application '$([string] (Get-IntuneAccessProperty $detected 'displayName'))' could not be collected. $($_.Exception.Message)")
            }
        }
        $detectedRecords.Add([PSCustomObject] @{
            PSTypeName       = 'IntuneAccess.DetectedApplication'
            Id               = [string] (Get-IntuneAccessProperty $detected 'id')
            DisplayName      = [string] (Get-IntuneAccessProperty $detected 'displayName')
            Publisher        = [string] (Get-IntuneAccessProperty $detected 'publisher')
            Version          = [string] (Get-IntuneAccessProperty $detected 'version')
            Platform         = [string] (Get-IntuneAccessProperty $detected 'platform')
            SizeInBytes      = Get-IntuneAccessProperty $detected 'sizeInByte'
            ReportedDeviceCount = Get-IntuneAccessProperty $detected 'deviceCount' 0
            ManagedDevices   = @($deviceLinks | ForEach-Object { [PSCustomObject] @{ Id = [string] (Get-IntuneAccessProperty $_ 'id'); DeviceName = [string] (Get-IntuneAccessProperty $_ 'deviceName'); LastSyncDateTime = Get-IntuneAccessProperty $_ 'lastSyncDateTime' } })
            RelationshipState = $state
            SourceApiVersion = 'v1.0'
        })
    }
    if ($queryCandidates.Count -gt $MaximumRelationshipQueries) {
        $warnings.Add("Detected-application device relationships were limited to $MaximumRelationshipQueries queries. Remaining records are labelled NotCollected.")
    }

    $appDefinitions = @()
    try {
        $rawApps = @(Invoke-IntuneAccessGraphRequest -Uri 'deviceAppManagement/mobileApps' -ApiVersion beta)
        $appDefinitions = @($rawApps | ForEach-Object {
            $app = $_
            $appId = [string] (Get-IntuneAccessProperty $app 'id')
            $relationships = @()
            $relationshipState = 'Available'
            try { $relationships = @(Invoke-IntuneAccessGraphRequest -Uri "deviceAppManagement/mobileApps/$([uri]::EscapeDataString($appId))/relationships" -ApiVersion beta) }
            catch { $relationshipState = 'Unavailable' }
            [PSCustomObject] @{
                PSTypeName       = 'IntuneAccess.ApplicationDefinitionEvidence'
                Id               = $appId
                DisplayName      = [string] (Get-IntuneAccessProperty $app 'displayName')
                Publisher        = [string] (Get-IntuneAccessProperty $app 'publisher')
                ODataType        = [string] (Get-IntuneAccessProperty $app '@odata.type')
                InstallCommandLine = [string] (Get-IntuneAccessProperty $app 'installCommandLine')
                UninstallCommandLine = [string] (Get-IntuneAccessProperty $app 'uninstallCommandLine')
                DetectionRules   = @(Get-IntuneAccessProperty $app 'detectionRules' @())
                RequirementRules = @(Get-IntuneAccessProperty $app 'requirementRules' @())
                Rules = @((Get-IntuneAccessProperty $app 'rules' @()) | ForEach-Object {
                    $rule=$_;$safe=[ordered]@{}
                    foreach($field in @('@odata.type','ruleType','check32BitOn64System','keyPath','valueName','operationType','operator','comparisonValue','path','fileOrFolderName','productCode','productVersion')){
                        $value=Get-IntuneAccessProperty $rule $field
                        if($null -ne $value){$safe[$field]=$value}
                    }
                    [pscustomobject]$safe
                })
                InstallExperience = [pscustomobject]@{runAsAccount=Get-IntuneAccessProperty (Get-IntuneAccessProperty $app 'installExperience') 'runAsAccount'}
                MinimumSupportedOperatingSystem = Get-IntuneAccessProperty $app 'minimumSupportedOperatingSystem'
                Relationships    = @($relationships | ForEach-Object { [PSCustomObject] @{ Id = [string] (Get-IntuneAccessProperty $_ 'id'); TargetId = [string] (Get-IntuneAccessProperty $_ 'targetId'); RelationshipType = [string] (Get-IntuneAccessProperty $_ '@odata.type') } })
                RelationshipState = $relationshipState
                SourceApiVersion = 'beta'
            }
        })
        $statuses.Add([PSCustomObject] @{ Source = 'Application definitions'; State = 'Available'; RecordCount = $appDefinitions.Count; ApiVersion = 'beta'; Reason = '' })
    }
    catch {
        $warnings.Add("Application definitions could not be enriched. $($_.Exception.Message)")
        $statuses.Add([PSCustomObject] @{ Source = 'Application definitions'; State = 'Unavailable'; RecordCount = 0; ApiVersion = 'beta'; Reason = $_.Exception.Message })
    }

    $applicationWorkloads = @($Workload | Where-Object WorkloadType -EQ 'Applications')
    $deviceEvidence = [System.Collections.Generic.List[object]]::new()
    foreach ($app in $applicationWorkloads) {
        $appAssignments = @($Assignment | Where-Object WorkloadId -EQ $app.Id)
        $appOutcomes = @($DeploymentOutcome | Where-Object WorkloadId -EQ $app.Id)
        $detectedByName = @($detectedRecords | Where-Object DisplayName -EQ $app.Name)
        $definition = $appDefinitions | Where-Object Id -EQ $app.Id | Select-Object -First 1
        $detectedDeviceIds = @($detectedByName | ForEach-Object { @($_.ManagedDevices) | ForEach-Object { [string] $_.Id } })
        $deviceIds = @(@($appOutcomes | ForEach-Object { [string] $_.DeviceId }) + $detectedDeviceIds | Where-Object { $_ } | Select-Object -Unique)
        foreach ($deviceId in $deviceIds) {
            $device = $ManagedDevice | Where-Object Id -EQ $deviceId | Select-Object -First 1
            $outcomes = @($appOutcomes | Where-Object DeviceId -EQ $deviceId)
            $detections = @($detectedByName | Where-Object { $candidateIds = @($_.ManagedDevices | ForEach-Object { [string] $_.Id }); $deviceId -in $candidateIds })
            $deviceEvidence.Add([PSCustomObject] @{
                PSTypeName          = 'IntuneAccess.DeviceApplicationEvidence'
                ApplicationId      = [string] $app.Id
                ApplicationName    = [string] $app.Name
                DeviceId           = [string] $deviceId
                DeviceName         = if ($null -eq $device) { [string] (Get-IntuneAccessProperty ($outcomes | Select-Object -First 1) 'DeviceName') } else { [string] (Get-IntuneAccessProperty $device 'DeviceName') }
                ConfiguredIntents  = @($appAssignments.Intent | Select-Object -Unique)
                AssignmentEvidence = $appAssignments
                InstallResults    = $outcomes
                DetectedSoftware  = $detections
                DetectionState    = if ($detections.Count -gt 0) { 'DetectedByName' } elseif ($detectedRecords.Count -eq 0) { 'NotEvaluated' } else { 'NotDetectedByExactName' }
                Requirements      = if ($null -eq $definition) { @() } else { @($definition.RequirementRules) }
                DetectionRules    = if ($null -eq $definition) { @() } else { @($definition.DetectionRules) }
                Relationships     = if ($null -eq $definition) { @() } else { @($definition.Relationships) }
                EvidenceBoundary  = 'Assignment intent, reported installation state and detected software are separate. Exact-name detection is not proof that an Intune detection rule passed. Client logs can be required for root-cause analysis.'
            })
        }
    }

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.ApplicationEvidence'
        ApplicationDefinitions = $appDefinitions
        DetectedApplications = $detectedRecords.ToArray()
        DeviceApplicationEvidence = $deviceEvidence.ToArray()
        CollectionStatus     = $statuses.ToArray()
        Warnings             = $warnings.ToArray()
        GraphPermissionsUsed = @('DeviceManagementApps.Read.All', 'DeviceManagementManagedDevices.Read.All')
        GeneratedAt          = [DateTimeOffset]::Now
        ToolVersion          = $script:IntuneAccessVersion
    }
}
