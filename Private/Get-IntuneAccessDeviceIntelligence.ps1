function ConvertTo-IntuneAccessDateTimeOffset {
    [CmdletBinding()]
    [OutputType([DateTimeOffset])]
    param([AllowNull()] [object] $Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string] $Value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string] $Value, [ref] $parsed)) { return $parsed }
    return $null
}

function New-IntuneAccessDeviceFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Device,
        [Parameter(Mandatory)] [string] $RuleId,
        [Parameter(Mandatory)] [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Information')] [string] $Severity,
        [Parameter(Mandatory)] [string] $Category,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Explanation,
        [Parameter(Mandatory)] [string] $Recommendation,
        [AllowNull()] [object] $ObservedAt,
        [hashtable] $Evidence = @{}
    )

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.DeviceFinding'
        FindingId            = "$RuleId/$([string] $Device.Id)"
        RuleId               = $RuleId
        Severity             = $Severity
        Category             = $Category
        Title                = $Title
        DeviceId             = [string] $Device.Id
        DeviceName           = [string] $Device.DeviceName
        SerialNumber         = [string] $Device.SerialNumber
        EntraDeviceId        = [string] $Device.EntraDeviceId
        Explanation          = $Explanation
        ReviewRecommendation = $Recommendation
        Evidence             = [PSCustomObject] $Evidence
        EvidenceTimestamp    = $ObservedAt
        EvidenceState        = 'Observed'
        ReadOnly             = $true
    }
}

function Get-IntuneAccessDeviceIntelligence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $ManagedDevice,
        [ValidateRange(1, 3650)] [int] $StaleAfterDays = 30,
        [ValidateRange(1, 3650)] [int] $NewEnrollmentGraceDays = 7,
        [datetimeoffset] $AsOf = [DateTimeOffset]::Now
    )

    $null = Assert-IntuneAccessConnection -RequiredScope @('DeviceManagementManagedDevices.Read.All', 'Device.Read.All')
    $warnings = [System.Collections.Generic.List[string]]::new()
    $entraDevices = @()
    try {
        $entraDevices = @(Invoke-IntuneAccessGraphRequest -Uri 'devices?$select=id,deviceId,displayName,accountEnabled,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime,registrationDateTime' -ApiVersion v1.0)
    }
    catch {
        $warnings.Add("Microsoft Entra device records could not be collected. $($_.Exception.Message)")
    }

    $entraByDeviceId = @{}
    foreach ($entra in $entraDevices) {
        $deviceId = [string] (Get-IntuneAccessProperty $entra 'deviceId')
        if (-not [string]::IsNullOrWhiteSpace($deviceId)) {
            if (-not $entraByDeviceId.ContainsKey($deviceId.ToLowerInvariant())) { $entraByDeviceId[$deviceId.ToLowerInvariant()] = [System.Collections.Generic.List[object]]::new() }
            $entraByDeviceId[$deviceId.ToLowerInvariant()].Add($entra)
        }
    }

    $inventory = [System.Collections.Generic.List[object]]::new()
    foreach ($device in $ManagedDevice) {
        $entraMatches = @()
        $entraDeviceId = [string] (Get-IntuneAccessProperty $device 'EntraDeviceId')
        if (-not [string]::IsNullOrWhiteSpace($entraDeviceId) -and $entraByDeviceId.ContainsKey($entraDeviceId.ToLowerInvariant())) {
            $entraMatches = @($entraByDeviceId[$entraDeviceId.ToLowerInvariant()])
        }
        $entra = if ($entraMatches.Count -eq 1) { $entraMatches[0] } else { $null }
        $lastSync = ConvertTo-IntuneAccessDateTimeOffset (Get-IntuneAccessProperty $device 'LastSyncDateTime')
        $enrolled = ConvertTo-IntuneAccessDateTimeOffset (Get-IntuneAccessProperty $device 'EnrolledDateTime')
        $evidenceAge = if ($null -eq $lastSync) { $null } else { [math]::Max(0, [math]::Floor(($AsOf - $lastSync).TotalDays)) }
        $inventory.Add([PSCustomObject] @{
            PSTypeName                    = 'IntuneAccess.DeviceInventoryRecord'
            Id                            = [string] (Get-IntuneAccessProperty $device 'Id')
            DeviceName                    = [string] (Get-IntuneAccessProperty $device 'DeviceName')
            SerialNumber                  = [string] (Get-IntuneAccessProperty $device 'SerialNumber')
            EntraDeviceId                 = $entraDeviceId
            UserId                        = [string] (Get-IntuneAccessProperty $device 'UserId')
            UserPrincipalName             = [string] (Get-IntuneAccessProperty $device 'UserPrincipalName')
            PrimaryUserState              = if ([string]::IsNullOrWhiteSpace([string] (Get-IntuneAccessProperty $device 'UserId'))) { 'Missing' } else { 'Observed' }
            Manufacturer                  = [string] (Get-IntuneAccessProperty $device 'Manufacturer')
            Model                         = [string] (Get-IntuneAccessProperty $device 'Model')
            OperatingSystem               = [string] (Get-IntuneAccessProperty $device 'OperatingSystem')
            OsVersion                     = [string] (Get-IntuneAccessProperty $device 'OsVersion')
            Ownership                     = [string] (Get-IntuneAccessProperty $device 'Ownership')
            ManagementAgent               = [string] (Get-IntuneAccessProperty $device 'ManagementAgent')
            EnrollmentType                = [string] (Get-IntuneAccessProperty $device 'EnrollmentType')
            ComplianceState               = [string] (Get-IntuneAccessProperty $device 'ComplianceState')
            ManagementState               = [string] (Get-IntuneAccessProperty $device 'ManagementState')
            EnrolledDateTime              = $enrolled
            LastSyncDateTime              = $lastSync
            EvidenceAgeDays               = $evidenceAge
            EntraCorrelationState         = if ([string]::IsNullOrWhiteSpace($entraDeviceId)) { 'MissingIdentifier' } elseif ($entraMatches.Count -eq 0) { 'NotFound' } elseif ($entraMatches.Count -gt 1) { 'Ambiguous' } else { 'Matched' }
            EntraObjectId                 = if ($null -eq $entra) { '' } else { [string] (Get-IntuneAccessProperty $entra 'id') }
            EntraDisplayName              = if ($null -eq $entra) { '' } else { [string] (Get-IntuneAccessProperty $entra 'displayName') }
            EntraAccountEnabled           = if ($null -eq $entra) { $null } else { Get-IntuneAccessProperty $entra 'accountEnabled' }
            EntraOperatingSystem          = if ($null -eq $entra) { '' } else { [string] (Get-IntuneAccessProperty $entra 'operatingSystem') }
            EntraOperatingSystemVersion   = if ($null -eq $entra) { '' } else { [string] (Get-IntuneAccessProperty $entra 'operatingSystemVersion') }
            EntraTrustType                = if ($null -eq $entra) { '' } else { [string] (Get-IntuneAccessProperty $entra 'trustType') }
            EntraApproximateLastSignIn    = if ($null -eq $entra) { $null } else { ConvertTo-IntuneAccessDateTimeOffset (Get-IntuneAccessProperty $entra 'approximateLastSignInDateTime') }
            SourceApiVersion              = 'v1.0'
            GeneratedAt                   = $AsOf
        })
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    $serialGroups = @($inventory | Where-Object { -not [string]::IsNullOrWhiteSpace($_.SerialNumber) } | Group-Object { $_.SerialNumber.Trim().ToLowerInvariant() } | Where-Object Count -GT 1)
    $entraGroups = @($inventory | Where-Object { -not [string]::IsNullOrWhiteSpace($_.EntraDeviceId) } | Group-Object { $_.EntraDeviceId.Trim().ToLowerInvariant() } | Where-Object Count -GT 1)
    $duplicateSerialIds = @($serialGroups | ForEach-Object { @($_.Group) | ForEach-Object { [string] $_.Id } })
    $duplicateEntraIds = @($entraGroups | ForEach-Object { @($_.Group) | ForEach-Object { [string] $_.Id } })

    foreach ($device in $inventory) {
        if ($null -eq $device.LastSyncDateTime) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-CHECKIN-MISSING' -Severity Medium -Category Hygiene -Title 'No confirmed Intune check-in timestamp' -Explanation 'The managed-device record did not return a last sync timestamp.' -Recommendation 'Review the device record and client state before deciding whether it is active.' -ObservedAt $AsOf -Evidence @{ LastSyncDateTime = $null }))
        }
        elseif ($device.EvidenceAgeDays -ge $StaleAfterDays) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-CHECKIN-STALE' -Severity High -Category Hygiene -Title 'Stale Intune check-in' -Explanation "The last confirmed Intune check-in is $($device.EvidenceAgeDays) days old." -Recommendation 'Confirm whether the device is still in service and investigate client connectivity before considering lifecycle action.' -ObservedAt $device.LastSyncDateTime -Evidence @{ EvidenceAgeDays = $device.EvidenceAgeDays; ThresholdDays = $StaleAfterDays }))
        }
        if ($null -ne $device.EnrolledDateTime -and ($AsOf - $device.EnrolledDateTime).TotalDays -ge $NewEnrollmentGraceDays -and ($null -eq $device.LastSyncDateTime -or $device.LastSyncDateTime -lt $device.EnrolledDateTime)) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-ENROLMENT-NO-HEALTHY-CHECKIN' -Severity High -Category Enrolment -Title 'Enrolment has no later healthy check-in evidence' -Explanation 'The enrolment timestamp is older than the grace period and no later Intune check-in was observed.' -Recommendation 'Review the enrolment record, device connectivity and management client state.' -ObservedAt $device.EnrolledDateTime -Evidence @{ GraceDays = $NewEnrollmentGraceDays; EnrolledDateTime = $device.EnrolledDateTime; LastSyncDateTime = $device.LastSyncDateTime }))
        }
        if ([string]::IsNullOrWhiteSpace($device.UserId)) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-PRIMARY-USER-MISSING' -Severity Low -Category Identity -Title 'No primary user evidence' -Explanation 'The managed-device record did not return an associated Microsoft Entra user.' -Recommendation 'Confirm whether this is expected for a shared, kiosk or userless device.' -ObservedAt $device.LastSyncDateTime -Evidence @{ EnrollmentType = $device.EnrollmentType }))
        }
        if ($device.EntraCorrelationState -ne 'Matched') {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-ENTRA-CORRELATION' -Severity Medium -Category Identity -Title 'Intune and Microsoft Entra device identity did not reconcile exactly' -Explanation "The correlation state is $($device.EntraCorrelationState)." -Recommendation 'Review the raw Intune and Microsoft Entra identifiers before removing or merging any record.' -ObservedAt $device.LastSyncDateTime -Evidence @{ CorrelationState = $device.EntraCorrelationState; EntraDeviceId = $device.EntraDeviceId }))
        }
        if ($device.Id -in $duplicateSerialIds) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-DUPLICATE-SERIAL' -Severity High -Category Duplicate -Title 'Duplicate serial number' -Explanation 'More than one Intune managed-device record returned the same non-empty serial number.' -Recommendation 'Compare enrolment and check-in timestamps before deciding which record, if any, is stale.' -ObservedAt $device.LastSyncDateTime -Evidence @{ SerialNumber = $device.SerialNumber; MatchingRecordCount = @($inventory | Where-Object SerialNumber -EQ $device.SerialNumber).Count }))
        }
        if ($device.Id -in $duplicateEntraIds) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-DUPLICATE-ENTRA-ID' -Severity High -Category Duplicate -Title 'Duplicate Microsoft Entra device identifier' -Explanation 'More than one Intune managed-device record returned the same Microsoft Entra device identifier.' -Recommendation 'Review the related Intune records and enrolment history before taking lifecycle action.' -ObservedAt $device.LastSyncDateTime -Evidence @{ EntraDeviceId = $device.EntraDeviceId; MatchingRecordCount = @($inventory | Where-Object EntraDeviceId -EQ $device.EntraDeviceId).Count }))
        }
        if ($device.ComplianceState -match '^(unknown|notEvaluated|)$') {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-COMPLIANCE-UNKNOWN' -Severity Medium -Category Compliance -Title 'No confirmed compliance result' -Explanation "The current managed-device compliance state is '$($device.ComplianceState)'." -Recommendation 'Review compliance targeting, policy status and evidence age before treating the device as compliant or non-compliant.' -ObservedAt $device.LastSyncDateTime -Evidence @{ ComplianceState = $device.ComplianceState }))
        }
        if (-not [string]::IsNullOrWhiteSpace($device.EntraOperatingSystemVersion) -and -not [string]::IsNullOrWhiteSpace($device.OsVersion) -and $device.EntraOperatingSystemVersion -ne $device.OsVersion) {
            $findings.Add((New-IntuneAccessDeviceFinding -Device $device -RuleId 'DEV-OS-VERSION-MISMATCH' -Severity Low -Category Mismatch -Title 'Intune and Microsoft Entra OS versions differ' -Explanation 'The two services returned different operating system versions for the correlated device.' -Recommendation 'Compare evidence timestamps; service reporting intervals can differ.' -ObservedAt $device.LastSyncDateTime -Evidence @{ IntuneOsVersion = $device.OsVersion; EntraOsVersion = $device.EntraOperatingSystemVersion }))
        }
    }

    [PSCustomObject] @{
        PSTypeName           = 'IntuneAccess.DeviceIntelligence'
        Inventory            = $inventory.ToArray()
        Findings             = @($findings | Sort-Object @{ Expression = { @('Critical','High','Medium','Low','Information').IndexOf($_.Severity) } }, DeviceName, RuleId)
        EntraDevices         = $entraDevices
        CollectionStatus     = [PSCustomObject] @{ State = if ($warnings.Count -eq 0) { 'Available' } else { 'Partial' }; IntuneRecordCount = $ManagedDevice.Count; EntraRecordCount = $entraDevices.Count; FindingCount = $findings.Count; ApiVersion = 'v1.0' }
        Warnings             = $warnings.ToArray()
        GraphPermissionsUsed = @('DeviceManagementManagedDevices.Read.All', 'Device.Read.All')
        GeneratedAt          = $AsOf
        ToolVersion          = $script:IntuneAccessVersion
    }
}
