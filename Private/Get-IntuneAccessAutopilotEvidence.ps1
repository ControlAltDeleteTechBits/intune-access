function Get-IntuneAccessDurationSeconds {
    [CmdletBinding()]
    param([AllowNull()] [object] $Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) { return $null }
    try { return [math]::Round(([TimeSpan]::Parse([string] $Value)).TotalSeconds) } catch { return $null }
}

function Get-IntuneAccessAutopilotEvidence {
    [CmdletBinding()]
    param([AllowEmptyCollection()] [object[]] $ManagedDevice = @())

    $null = Assert-IntuneAccessConnection -RequiredScope @('DeviceManagementManagedDevices.Read.All', 'DeviceManagementServiceConfig.Read.All')
    $warnings = [System.Collections.Generic.List[string]]::new()
    $statuses = [System.Collections.Generic.List[object]]::new()
    $identities = @()
    $events = @()
    $profiles = @()
    $espProfiles = @()
    foreach ($source in @(
        [PSCustomObject] @{ Name = 'Autopilot identities'; Uri = 'deviceManagement/windowsAutopilotDeviceIdentities'; Target = 'identities' }
        [PSCustomObject] @{ Name = 'Autopilot events'; Uri = 'deviceManagement/autopilotEvents'; Target = 'events' }
        [PSCustomObject] @{ Name = 'Autopilot deployment profiles'; Uri = 'deviceManagement/windowsAutopilotDeploymentProfiles'; Target = 'profiles' }
        [PSCustomObject] @{ Name = 'Enrolment Status Page profiles'; Uri = 'deviceManagement/deviceEnrollmentConfigurations'; Target = 'espProfiles' }
    )) {
        try {
            $records = @(Invoke-IntuneAccessGraphRequest -Uri $source.Uri -ApiVersion beta)
            Set-Variable -Name $source.Target -Value $records
            $statuses.Add([PSCustomObject] @{ Source = $source.Name; State = 'Available'; RecordCount = $records.Count; ApiVersion = 'beta'; Reason = '' })
        }
        catch {
            $reason = $_.Exception.Message
            $statuses.Add([PSCustomObject] @{ Source = $source.Name; State = 'Unavailable'; RecordCount = 0; ApiVersion = 'beta'; Reason = $reason })
            $warnings.Add("$($source.Name) could not be collected. $reason")
        }
    }

    $managedById = @{}; $managedBySerial = @{}; $managedByEntra = @{}
    foreach ($device in $ManagedDevice) {
        if (-not [string]::IsNullOrWhiteSpace([string] $device.Id)) { $managedById[[string] $device.Id] = $device }
        if (-not [string]::IsNullOrWhiteSpace([string] $device.SerialNumber)) { $managedBySerial[([string] $device.SerialNumber).ToLowerInvariant()] = $device }
        if (-not [string]::IsNullOrWhiteSpace([string] $device.EntraDeviceId)) { $managedByEntra[([string] $device.EntraDeviceId).ToLowerInvariant()] = $device }
    }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($identity in $identities) {
        $managedId = [string] (Get-IntuneAccessProperty $identity 'managedDeviceId')
        $serial = [string] (Get-IntuneAccessProperty $identity 'serialNumber')
        $entraId = [string] (Get-IntuneAccessProperty $identity 'azureActiveDirectoryDeviceId' (Get-IntuneAccessProperty $identity 'azureAdDeviceId' ''))
        $device = if ($managedById.ContainsKey($managedId)) { $managedById[$managedId] } elseif (-not [string]::IsNullOrWhiteSpace($serial) -and $managedBySerial.ContainsKey($serial.ToLowerInvariant())) { $managedBySerial[$serial.ToLowerInvariant()] } elseif (-not [string]::IsNullOrWhiteSpace($entraId) -and $managedByEntra.ContainsKey($entraId.ToLowerInvariant())) { $managedByEntra[$entraId.ToLowerInvariant()] } else { $null }
        $identityId = [string] (Get-IntuneAccessProperty $identity 'id')
        $matchingEvents = @($events | Where-Object {
            ([string] (Get-IntuneAccessProperty $_ 'managedDeviceId')) -eq $managedId -or
            ([string] (Get-IntuneAccessProperty $_ 'deviceSerialNumber' (Get-IntuneAccessProperty $_ 'serialNumber' ''))) -eq $serial -or
            ([string] (Get-IntuneAccessProperty $_ 'windowsAutopilotDeviceIdentityId')) -eq $identityId
        })
        $timeline = [System.Collections.Generic.List[object]]::new()
        $profileAssigned = Get-IntuneAccessProperty $identity 'deploymentProfileAssignedDateTime'
        if ($null -ne $profileAssigned) { $timeline.Add([PSCustomObject] @{ Stage = 'Profile assignment'; State = [string] (Get-IntuneAccessProperty $identity 'deploymentProfileAssignmentStatus'); StartedAt = $profileAssigned; EndedAt = $profileAssigned; DurationSeconds = 0; Evidence = 'Autopilot identity'; ApiVersion = 'beta' }) }
        foreach ($autopilotEvent in $matchingEvents) {
            $start = Get-IntuneAccessProperty $autopilotEvent 'enrollmentStartDateTime' (Get-IntuneAccessProperty $autopilotEvent 'eventDateTime')
            $end = Get-IntuneAccessProperty $autopilotEvent 'enrollmentEndDateTime'
            $timeline.Add([PSCustomObject] @{ Stage = 'Enrolment'; State = [string] (Get-IntuneAccessProperty $autopilotEvent 'enrollmentState' (Get-IntuneAccessProperty $autopilotEvent 'enrollmentType' 'Observed')); StartedAt = $start; EndedAt = $end; DurationSeconds = if ($null -ne $start -and $null -ne $end) { [math]::Round(((ConvertTo-IntuneAccessDateTimeOffset $end) - (ConvertTo-IntuneAccessDateTimeOffset $start)).TotalSeconds) } else { $null }; Evidence = 'Autopilot event'; ApiVersion = 'beta' })
            foreach ($stage in @(
                [PSCustomObject] @{ Name = 'Device preparation'; Duration = 'devicePreparationDuration'; State = 'devicePreparationState' }
                [PSCustomObject] @{ Name = 'Device setup'; Duration = 'deviceSetupDuration'; State = 'deviceSetupState' }
                [PSCustomObject] @{ Name = 'Account setup'; Duration = 'accountSetupDuration'; State = 'accountSetupState' }
            )) {
                $timeline.Add([PSCustomObject] @{ Stage = $stage.Name; State = [string] (Get-IntuneAccessProperty $autopilotEvent $stage.State 'NotReturned'); StartedAt = $null; EndedAt = $null; DurationSeconds = Get-IntuneAccessDurationSeconds (Get-IntuneAccessProperty $autopilotEvent $stage.Duration); Evidence = 'Autopilot event'; ApiVersion = 'beta' })
            }
        }
        $records.Add([PSCustomObject] @{
            PSTypeName                 = 'IntuneAccess.AutopilotTimeline'
            AutopilotIdentityId        = $identityId
            ManagedDeviceId            = if ($null -eq $device) { $managedId } else { [string] $device.Id }
            DeviceName                 = if ($null -eq $device) { [string] (Get-IntuneAccessProperty $identity 'displayName') } else { [string] $device.DeviceName }
            SerialNumber               = $serial
            EntraDeviceId              = $entraId
            GroupTag                   = [string] (Get-IntuneAccessProperty $identity 'groupTag')
            EnrollmentState            = [string] (Get-IntuneAccessProperty $identity 'enrollmentState')
            DeploymentProfileName      = [string] (Get-IntuneAccessProperty $identity 'deploymentProfileDisplayName' (Get-IntuneAccessProperty $identity 'profileDisplayName' ''))
            ProfileAssignmentState     = [string] (Get-IntuneAccessProperty $identity 'deploymentProfileAssignmentStatus')
            ProfileAssignmentDetail    = [string] (Get-IntuneAccessProperty $identity 'deploymentProfileAssignmentDetailedStatus')
            LastContactedDateTime      = Get-IntuneAccessProperty $identity 'lastContactedDateTime'
            Timeline                   = $timeline.ToArray()
            EventCount                 = $matchingEvents.Count
            FailureDetails             = @($matchingEvents | ForEach-Object { [string] (Get-IntuneAccessProperty $_ 'deploymentState' (Get-IntuneAccessProperty $_ 'enrollmentFailureDetails' '')) } | Where-Object { $_ -and $_ -notmatch '^(success|succeeded)$' } | Select-Object -Unique)
            CorrelationState            = if ($null -eq $device) { 'NotMatched' } else { 'Matched' }
            EvidenceBoundary           = 'Autopilot and ESP evidence uses Microsoft Graph beta. Missing stages are unavailable evidence, not proof that the stage did not run.'
            SourceApiVersion           = 'beta'
        })
    }

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.AutopilotEvidence'
        Timelines            = $records.ToArray()
        DeploymentProfiles   = $profiles
        EspProfiles          = $espProfiles
        CollectionStatus     = $statuses.ToArray()
        Warnings             = $warnings.ToArray()
        GraphPermissionsUsed = @('DeviceManagementManagedDevices.Read.All', 'DeviceManagementServiceConfig.Read.All')
        GeneratedAt          = [DateTimeOffset]::Now
        ToolVersion          = $script:IntuneAccessVersion
    }
}
