function Get-IntuneAccessOperationalEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Workload
    )

    $context = Assert-IntuneAccessConnection
    $warnings = [System.Collections.Generic.List[string]]::new()
    $collectionStatus = [System.Collections.Generic.List[object]]::new()
    $outcomes = [System.Collections.Generic.List[object]]::new()

    if ('DeviceManagementManagedDevices.Read.All' -notin @($context.Scopes)) {
        throw 'Operational evidence requires DeviceManagementManagedDevices.Read.All. Reconnect with the OperationalEvidence feature.'
    }

    # managedDevice uses managedDeviceOwnerType and deviceRegistrationState in the
    # documented v1.0 contract. Older internal fixtures used ownerType and
    # managementState, so the normalisation below keeps those names as fallbacks.
    $rawDevices = @(Invoke-IntuneAccessGraphRequest -Uri 'deviceManagement/managedDevices?$select=id,deviceName,userId,userPrincipalName,userDisplayName,azureADDeviceId,operatingSystem,osVersion,complianceState,managementAgent,deviceEnrollmentType,lastSyncDateTime,model,manufacturer,serialNumber,managedDeviceOwnerType,deviceRegistrationState,enrolledDateTime,isEncrypted,jailBroken,deviceCategoryDisplayName,totalStorageSpaceInBytes,freeStorageSpaceInBytes,imei,meid,wiFiMacAddress,ethernetMacAddress,phoneNumber,subscriberCarrier' -ApiVersion v1.0)
    $devices = @($rawDevices | ForEach-Object {
        [PSCustomObject] @{
            PSTypeName          = 'IntuneAccess.ManagedDevice'
            Id                  = [string] (Get-IntuneAccessProperty $_ 'id')
            DeviceName          = [string] (Get-IntuneAccessProperty $_ 'deviceName')
            UserId              = [string] (Get-IntuneAccessProperty $_ 'userId')
            UserPrincipalName   = [string] (Get-IntuneAccessProperty $_ 'userPrincipalName')
            UserDisplayName     = [string] (Get-IntuneAccessProperty $_ 'userDisplayName')
            EntraDeviceId       = [string] (Get-IntuneAccessProperty $_ 'azureADDeviceId')
            OperatingSystem     = [string] (Get-IntuneAccessProperty $_ 'operatingSystem')
            OsVersion           = [string] (Get-IntuneAccessProperty $_ 'osVersion')
            ComplianceState     = [string] (Get-IntuneAccessProperty $_ 'complianceState')
            ManagementAgent     = [string] (Get-IntuneAccessProperty $_ 'managementAgent')
            EnrollmentType      = [string] (Get-IntuneAccessProperty $_ 'deviceEnrollmentType')
            LastSyncDateTime    = Get-IntuneAccessProperty $_ 'lastSyncDateTime'
            EnrolledDateTime    = Get-IntuneAccessProperty $_ 'enrolledDateTime'
            Manufacturer        = [string] (Get-IntuneAccessProperty $_ 'manufacturer')
            Model               = [string] (Get-IntuneAccessProperty $_ 'model')
            SerialNumber        = [string] (Get-IntuneAccessProperty $_ 'serialNumber')
            Ownership           = [string] (Get-IntuneAccessProperty $_ 'managedDeviceOwnerType' (Get-IntuneAccessProperty $_ 'ownerType' ''))
            ManagementState     = [string] (Get-IntuneAccessProperty $_ 'deviceRegistrationState' (Get-IntuneAccessProperty $_ 'managementState' ''))
            IsEncrypted         = Get-IntuneAccessProperty $_ 'isEncrypted'
            JailBroken          = [string] (Get-IntuneAccessProperty $_ 'jailBroken')
            DeviceCategory      = [string] (Get-IntuneAccessProperty $_ 'deviceCategoryDisplayName')
            TotalStorageBytes   = Get-IntuneAccessProperty $_ 'totalStorageSpaceInBytes'
            FreeStorageBytes    = Get-IntuneAccessProperty $_ 'freeStorageSpaceInBytes'
            Imei                = [string] (Get-IntuneAccessProperty $_ 'imei')
            Meid                = [string] (Get-IntuneAccessProperty $_ 'meid')
            WifiMacAddress      = [string] (Get-IntuneAccessProperty $_ 'wiFiMacAddress')
            EthernetMacAddress  = [string] (Get-IntuneAccessProperty $_ 'ethernetMacAddress')
            PhoneNumber         = [string] (Get-IntuneAccessProperty $_ 'phoneNumber')
            SubscriberCarrier   = [string] (Get-IntuneAccessProperty $_ 'subscriberCarrier')
            SourceApiVersion    = 'v1.0'
        }
    })

    $users = @($devices | Where-Object { -not [string]::IsNullOrWhiteSpace($_.UserPrincipalName) } | Group-Object { $_.UserPrincipalName.ToLowerInvariant() } | ForEach-Object {
        $first = $_.Group[0]
        [PSCustomObject] @{
            PSTypeName        = 'IntuneAccess.ManagedUser'
            Id                = [string] $first.UserId
            DisplayName       = [string] $first.UserDisplayName
            UserPrincipalName = [string] $first.UserPrincipalName
            ManagedDeviceIds  = @($_.Group.Id)
            ManagedDeviceCount = $_.Count
        }
    })

    foreach ($workloadObject in $Workload) {
        $statusEndpoint = ''
        $apiVersion = 'v1.0'
        $reason = ''
        switch ([string] $workloadObject.SourceCollection) {
            'Device configuration' { $statusEndpoint = "$($workloadObject.SourceEndpoint)/$([uri]::EscapeDataString([string] $workloadObject.Id))/deviceStatuses" }
            'Compliance policies' { $statusEndpoint = "$($workloadObject.SourceEndpoint)/$([uri]::EscapeDataString([string] $workloadObject.Id))/deviceStatuses" }
            'Applications' { $statusEndpoint = "$($workloadObject.SourceEndpoint)/$([uri]::EscapeDataString([string] $workloadObject.Id))/deviceStatuses"; $apiVersion = 'beta' }
            'PowerShell scripts' { $statusEndpoint = "$($workloadObject.SourceEndpoint)/$([uri]::EscapeDataString([string] $workloadObject.Id))/deviceRunStates?`$expand=managedDevice(`$select=id,deviceName,userPrincipalName)"; $apiVersion = 'beta' }
            'Remediations' { $statusEndpoint = "$($workloadObject.SourceEndpoint)/$([uri]::EscapeDataString([string] $workloadObject.Id))/deviceRunStates?`$expand=managedDevice(`$select=id,deviceName,userPrincipalName)"; $apiVersion = 'beta' }
            default { $reason = 'No documented GET outcome contract is adopted for this workload family.' }
        }

        if ([string]::IsNullOrWhiteSpace($statusEndpoint)) {
            $collectionStatus.Add([PSCustomObject] @{ WorkloadId = $workloadObject.Id; WorkloadName = $workloadObject.Name; State = 'NotSupported'; RecordCount = 0; ApiVersion = ''; Reason = $reason })
            continue
        }

        try {
            $rawOutcomes = @(Invoke-IntuneAccessGraphRequest -Uri $statusEndpoint -ApiVersion $apiVersion)
            foreach ($rawOutcome in $rawOutcomes) {
                $outcomes.Add((ConvertTo-IntuneAccessDeploymentOutcome -InputObject $rawOutcome -Workload $workloadObject -ApiVersion $apiVersion -ManagedDevice $devices))
            }
            $collectionStatus.Add([PSCustomObject] @{ WorkloadId = $workloadObject.Id; WorkloadName = $workloadObject.Name; State = 'Available'; RecordCount = $rawOutcomes.Count; ApiVersion = $apiVersion; Reason = '' })
        }
        catch {
            $reason = $_.Exception.Message
            $collectionStatus.Add([PSCustomObject] @{ WorkloadId = $workloadObject.Id; WorkloadName = $workloadObject.Name; State = 'Unavailable'; RecordCount = 0; ApiVersion = $apiVersion; Reason = $reason })
            $warnings.Add("Deployment outcomes for '$($workloadObject.Name)' could not be collected. $reason")
        }
    }

    foreach ($user in $users) {
        $userOutcomes = @($outcomes | Where-Object UserPrincipalName -EQ $user.UserPrincipalName)
        $user | Add-Member -NotePropertyName OutcomeCount -NotePropertyValue $userOutcomes.Count -Force
        $user | Add-Member -NotePropertyName ErrorCount -NotePropertyValue @($userOutcomes | Where-Object Category -EQ 'Error').Count -Force
    }

    [PSCustomObject] @{
        PSTypeName          = 'IntuneAccess.OperationalEvidence'
        ManagedDevices      = $devices
        ManagedUsers        = $users
        DeploymentOutcomes  = $outcomes.ToArray()
        CollectionStatus    = $collectionStatus.ToArray()
        Warnings            = $warnings.ToArray()
        GraphPermissionsUsed = @('DeviceManagementManagedDevices.Read.All', 'DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All', 'DeviceManagementScripts.Read.All')
        GeneratedAt         = [DateTimeOffset]::Now
        ToolVersion         = $script:IntuneAccessVersion
    }
}
