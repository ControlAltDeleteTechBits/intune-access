[CmdletBinding()]
param([Parameter(Mandatory)] [string] $Path)
$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $moduleRoot 'IntuneAccess.psd1') -Force
$at = [DateTimeOffset]::Parse('2026-09-15T12:00:00Z')
$device = [pscustomobject] @{
    Id = 'synthetic-device-1'; DeviceName = 'CONTOSO-LAPTOP-001'; UserId = 'synthetic-user'; UserPrincipalName = 'alex.wilber.long-administration-name@contoso.example'; UserDisplayName = 'Alex Wilber'
    EntraDeviceId = 'synthetic-entra-device'; OperatingSystem = 'Windows'; OsVersion = '10.0.26100'; ComplianceState = 'unknown'; ManagementAgent = 'mdm'; EnrollmentType = 'windowsAutopilot'
    LastSyncDateTime = '2026-08-01T10:00:00Z'; EnrolledDateTime = '2026-05-01T10:00:00Z'; Manufacturer = 'Contoso'; Model = 'Test laptop'; SerialNumber = 'SYNTHETIC-001'; Ownership = 'company'; ManagementState = 'registered'
}
$package = [pscustomobject] @{ Id = 'synthetic-remediation'; Name = 'Example application health detection'; Description = 'Synthetic evidence only'; WorkloadType = 'Scripts'; SourceCollection = 'Remediations'; SourceEndpoint = 'deviceManagement/deviceHealthScripts'; ScopeTagIds = @(); AssignmentDataState = 'Available'; SourceApiVersion = 'beta'; AssignmentCount = 0 }
$outcome = [pscustomobject] @{ Id = 'synthetic-run'; WorkloadId = $package.Id; WorkloadName = $package.Name; WorkloadType = 'Scripts'; DeviceId = $device.Id; DeviceName = $device.DeviceName; UserPrincipalName = $device.UserPrincipalName; State = 'fail'; Category = 'Error'; StateDetail = 'Synthetic detection failure'; ErrorCode = 0; ErrorCodeHex = ''; LastReportedDateTime = '2026-09-15T10:00:00Z'; LastStateUpdateDateTime = '2026-09-15T10:00:00Z'; DeviceMatchState = 'MatchedById'; SourceApiVersion = 'beta'; EvidenceState = 'Reported'; DetectionState = 'fail'; RemediationState = 'remediationFailed'; RemediationScriptError = 'Synthetic prerequisite missing. No script was executed to create this example.' }
$earlier = $outcome.PSObject.Copy(); $earlier.LastStateUpdateDateTime = '2026-09-14T10:00:00Z'
$finding = [pscustomobject] @{ FindingId = "DEV-CHECKIN-STALE/$($device.Id)"; DeviceId = $device.Id; DeviceName = $device.DeviceName; SourceType = 'DeviceHygiene'; SourceId = 'DEV-CHECKIN-STALE'; Title = 'Stale Intune check-in'; PriorityScore = 75; Severity = 'High'; Category = 'Hygiene'; Explanation = 'Synthetic example: the last recorded check-in is old.'; ReviewRecommendation = 'Confirm whether the device is in service.'; CauseState = 'NotAsserted'; EvidenceTimestamp = $device.LastSyncDateTime; Evidence = @{ LastSyncDateTime = $device.LastSyncDateTime } }
$model = [pscustomobject] @{
    PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [pscustomobject] @{ Id = 'intuneaccess-v4-synthetic-lab'; DisplayName = 'Contoso V4 Synthetic Lab' }; GeneratedAt = $at; ToolVersion = '4.0.0'
    InitialUserPrincipalName = ''; Administrators = @(); AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
    WorkloadObjects = @($package); WorkloadAssignments = @(); WorkloadGroups = @(); AssignmentFilters = @(); WorkloadCollectionStatus = @()
    ManagedDevices = @($device); ManagedUsers = @(); DeploymentOutcomes = @($outcome); OutcomeCollectionStatus = @([pscustomobject] @{ WorkloadId = $package.Id; WorkloadName = $package.Name; State = 'Available'; RecordCount = 1; ApiVersion = 'beta'; Reason = '' })
    EstateFindings = @($finding); Warnings = @('All identities, results and findings in this preview are synthetic. No tenant was accessed.'); GraphPermissionsUsed = @()
    ApplicationDefinitions=@([pscustomobject]@{
        Id='synthetic-win32-app';DisplayName='Contoso example application';ODataType='#microsoft.graph.win32LobApp';SourceApiVersion='Synthetic fixture';InstallExperience=@{runAsAccount='system'}
        Rules=@([pscustomobject]@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';keyPath='HKLM\SOFTWARE\Contoso\Example';valueName='Version';operationType='string';operator='equal';comparisonValue='1.0';check32BitOn64System=$false})
    })
}
$module = Get-Module IntuneAccess
$centre = & $module { param($Collection, $Previous, $Time) Get-IntuneAccessActionCentre -Collection $Collection -PreviousOutcome @($Previous) -AsOf $Time } $model $earlier $at
$model | Add-Member -NotePropertyName ActionCentre -NotePropertyValue $centre
$model | Add-Member -NotePropertyName FindingVerification -NotePropertyValue @([pscustomobject] @{
    FindingId = 'synthetic-prior-stale'; Title = 'Example of a later check-in'; DeviceId = 'synthetic-device-2'; DeviceName = 'CONTOSO-LAPTOP-002'; VerificationState = 'ObservationCleared'
    Explanation = 'Synthetic example: a later positive check-in clears the stale observation, not every possible device issue.'; BeforeCollectedAt = '2026-09-14T12:00:00Z'; AfterCollectedAt = $at
    BeforeEvidenceTimestamp = '2026-08-01T10:00:00Z'; BeforeEvidence = @{ LastSyncDateTime = '2026-08-01T10:00:00Z' }; AfterEvidence = @{ LastSyncDateTime = '2026-09-15T10:00:00Z' }; CauseState = 'NotAsserted'
})
$model | Export-IntuneAccessReport -Path $Path -Force
