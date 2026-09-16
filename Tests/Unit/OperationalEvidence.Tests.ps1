$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Device and User 360 operational evidence' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Assert-IntuneAccessConnection {
                [PSCustomObject] @{ Scopes = @('DeviceManagementManagedDevices.Read.All', 'DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All', 'DeviceManagementScripts.Read.All') }
            }
        }

        It 'normalises managed devices, users, reported states and error evidence' {
            $configuration = [PSCustomObject] @{ Id = 'config-1'; Name = 'Secure configuration'; WorkloadType = 'Configuration'; SourceCollection = 'Device configuration'; SourceEndpoint = 'deviceManagement/deviceConfigurations' }
            $application = [PSCustomObject] @{ Id = 'app-1'; Name = 'Support app'; WorkloadType = 'Applications'; SourceCollection = 'Applications'; SourceEndpoint = 'deviceAppManagement/mobileApps' }
            $settings = [PSCustomObject] @{ Id = 'settings-1'; Name = 'Endpoint policy'; WorkloadType = 'Endpoint security'; SourceCollection = 'Settings Catalog'; SourceEndpoint = 'deviceManagement/configurationPolicies' }
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -like 'deviceManagement/managedDevices*') {
                    return @([PSCustomObject] @{ id = 'device-1'; deviceName = 'PC-001'; userId = 'user-1'; userPrincipalName = 'alex@example.test'; userDisplayName = 'Alex Wilber'; azureADDeviceId = 'entra-device-1'; operatingSystem = 'Windows'; osVersion = '10.0.26100'; complianceState = 'noncompliant'; lastSyncDateTime = '2026-08-18T10:00:00Z'; model = 'Virtual Machine'; manufacturer = 'Contoso'; serialNumber = 'ABC123'; ownerType = 'company'; managementState = 'managed' })
                }
                if ($Uri -eq 'deviceManagement/deviceConfigurations/config-1/deviceStatuses') {
                    return @([PSCustomObject] @{ id = 'status-1'; deviceDisplayName = 'PC-001'; userPrincipalName = 'alex@example.test'; status = 'nonCompliant'; lastReportedDateTime = '2026-08-18T09:00:00Z' })
                }
                if ($Uri -eq 'deviceAppManagement/mobileApps/app-1/deviceStatuses') {
                    return @([PSCustomObject] @{ id = 'status-2'; deviceId = 'device-1'; deviceName = 'PC-001'; userPrincipalName = 'alex@example.test'; installState = 'failed'; installStateDetail = 'dependencyFailedToInstall'; errorCode = 5; lastSyncDateTime = '2026-08-18T09:30:00Z' })
                }
                return @()
            }

            $result = Get-IntuneAccessOperationalEvidence -Workload @($configuration, $application, $settings)

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.OperationalEvidence'
            $result.ManagedDevices.Count | Should -Be 1
            $result.ManagedUsers.Count | Should -Be 1
            $result.ManagedUsers[0].ManagedDeviceCount | Should -Be 1
            $result.ManagedUsers[0].ErrorCount | Should -Be 2
            $result.DeploymentOutcomes.Count | Should -Be 2
            @($result.DeploymentOutcomes | Where-Object DeviceMatchState -EQ 'MatchedById').Count | Should -Be 1
            @($result.DeploymentOutcomes | Where-Object DeviceMatchState -EQ 'MatchedByName').Count | Should -Be 1
            ($result.DeploymentOutcomes | Where-Object WorkloadId -EQ 'app-1').ErrorCodeHex | Should -Be '0x00000005'
            ($result.CollectionStatus | Where-Object WorkloadId -EQ 'settings-1').State | Should -Be 'NotSupported'
        }

        It 'retains device inventory when an outcome endpoint fails' {
            $workload = [PSCustomObject] @{ Id = 'config-1'; Name = 'Secure configuration'; WorkloadType = 'Configuration'; SourceCollection = 'Device configuration'; SourceEndpoint = 'deviceManagement/deviceConfigurations' }
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -like 'deviceManagement/managedDevices*') { return @([PSCustomObject] @{ id = 'device-1'; deviceName = 'PC-001' }) }
                throw 'Simulated status failure'
            }

            $result = Get-IntuneAccessOperationalEvidence -Workload @($workload)

            $result.ManagedDevices.Count | Should -Be 1
            $result.DeploymentOutcomes.Count | Should -Be 0
            $result.CollectionStatus[0].State | Should -Be 'Unavailable'
            $result.Warnings[0] | Should -Match 'could not be collected'
        }

        It 'formats signed Intune error codes as unsigned hexadecimal values' -TestCases @(
            @{Code=-2016345060;Hex='0x87D1041C'},
            @{Code=-1;Hex='0xFFFFFFFF'},
            @{Code=-2147483648;Hex='0x80000000'},
            @{Code=2147483647;Hex='0x7FFFFFFF'}
        ) {
            param($Code,$Hex)
            $workload = [PSCustomObject] @{ Id = 'app-1'; Name = 'Support app'; WorkloadType = 'Applications' }
            $device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; UserPrincipalName = 'alex@example.test' }
            $rawOutcome = [PSCustomObject] @{ id = 'status-1'; deviceId = 'device-1'; installState = 'failed'; errorCode = $Code }

            $result = ConvertTo-IntuneAccessDeploymentOutcome -InputObject $rawOutcome -Workload $workload -ApiVersion 'beta' -ManagedDevice @($device)

            $result.ErrorCode | Should -Be $Code
            $result.ErrorCodeHex | Should -Be $Hex
        }

        It 'builds a selected device 360 view from shared evidence' {
            $device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; UserPrincipalName = 'alex@example.test' }
            $user = [PSCustomObject] @{ Id = 'user-1'; UserPrincipalName = 'alex@example.test' }
            $outcome = [PSCustomObject] @{ Id = 'status-1'; WorkloadId = 'app-1'; DeviceId = 'device-1'; UserPrincipalName = 'alex@example.test'; Category = 'Error' }
            Mock Get-IntuneAccessWorkloadAssignments {
                [PSCustomObject] @{ Workloads = @([PSCustomObject] @{ Id = 'app-1'; Name = 'Support app' }); Assignments = @([PSCustomObject] @{ Id = 'assignment-1'; WorkloadId = 'app-1' }); Warnings = @() }
            }
            Mock Get-IntuneAccessOperationalEvidence {
                [PSCustomObject] @{ ManagedDevices = @($device); ManagedUsers = @($user); DeploymentOutcomes = @($outcome); CollectionStatus = @(); Warnings = @() }
            }
            Mock Get-IntuneAccessDeviceIntelligence { [PSCustomObject] @{ Inventory = @(); Findings = @(); Warnings = @() } }
            Mock Get-IntuneAccessDeviceMembership { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @() } }
            Mock Get-IntuneAccessManagedDeviceUserMembership { [PSCustomObject] @{ State = 'NotEvaluated'; GroupIds = @(); Groups = @() } }
            Mock Resolve-IntuneAccessDeviceAssignment { @() }
            Mock Get-IntuneAccessApplicationEvidence { [PSCustomObject] @{ DeviceApplicationEvidence = @(); Warnings = @() } }
            Mock Get-IntuneAccessUpdateComplianceEvidence { [PSCustomObject] @{ Investigations = @(); Warnings = @() } }

            $result = Get-IntuneDevice360 -DeviceName 'PC-001'

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.Device360'
            $result.Device.Id | Should -Be 'device-1'
            $result.DeploymentOutcomes.Count | Should -Be 1
            $result.Workloads.Count | Should -Be 1
            $result.ErrorCount | Should -Be 1
        }

        It 'builds a selected user 360 view across managed devices' {
            $device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; UserPrincipalName = 'alex@example.test' }
            $user = [PSCustomObject] @{ Id = 'user-1'; UserPrincipalName = 'alex@example.test' }
            $outcome = [PSCustomObject] @{ Id = 'status-1'; WorkloadId = 'config-1'; DeviceId = 'device-1'; UserPrincipalName = 'alex@example.test'; Category = 'Pending' }
            Mock Get-IntuneAccessWorkloadAssignments {
                [PSCustomObject] @{ Workloads = @([PSCustomObject] @{ Id = 'config-1'; Name = 'Configuration' }); Assignments = @(); Warnings = @() }
            }
            Mock Get-IntuneAccessOperationalEvidence {
                [PSCustomObject] @{ ManagedDevices = @($device); ManagedUsers = @($user); DeploymentOutcomes = @($outcome); CollectionStatus = @(); Warnings = @() }
            }

            $result = Get-IntuneUser360 -UserPrincipalName 'alex@example.test'

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.User360'
            $result.ManagedDevices.Count | Should -Be 1
            $result.DeploymentOutcomes.Count | Should -Be 1
            $result.PendingCount | Should -Be 1
        }

        It 'renders Device 360, User 360 and reported outcome relationships' {
            $device = [PSCustomObject] @{
                Id = 'device-1'; DeviceName = 'PC <001>'; UserPrincipalName = 'alex@example.test'; UserDisplayName = 'Alex Wilber'; EntraDeviceId = 'entra-1'
                OperatingSystem = 'Windows'; OsVersion = '10.0.26100'; ComplianceState = 'noncompliant'; LastSyncDateTime = '2026-08-18T10:00:00Z'
                Manufacturer = 'Contoso'; Model = 'Virtual'; SerialNumber = 'ABC&123'; Ownership = 'company'; ManagementState = 'managed'
            }
            $user = [PSCustomObject] @{ Id = 'user-1'; DisplayName = 'Alex Wilber'; UserPrincipalName = 'alex@example.test'; ManagedDeviceCount = 1; OutcomeCount = 1; ErrorCount = 1 }
            $workload = [PSCustomObject] @{ Id = 'app-1'; Name = 'Support app'; Description = ''; WorkloadType = 'Applications'; ScopeTagIds = @(); AssignmentDataState = 'Available'; SourceApiVersion = 'v1.0' }
            $outcome = [PSCustomObject] @{
                Id = 'status-1'; WorkloadId = 'app-1'; WorkloadName = 'Support app'; WorkloadType = 'Applications'; DeviceId = 'device-1'; DeviceName = 'PC <001>'; UserPrincipalName = 'alex@example.test'
                State = 'failed'; Category = 'Error'; StateDetail = 'dependencyFailedToInstall'; ErrorCode = 5; ErrorCodeHex = '0x00000005'; LastReportedDateTime = '2026-08-18T09:00:00Z'
                DeviceMatchState = 'MatchedById'; SourceApiVersion = 'beta'; EvidenceState = 'Reported'
            }
            $model = [PSCustomObject] @{
                PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }
                Administrators = @(); AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
                WorkloadObjects = @($workload); WorkloadAssignments = @(); WorkloadGroups = @(); AssignmentFilters = @(); WorkloadCollectionStatus = @()
                ManagedDevices = @($device); ManagedUsers = @($user); DeploymentOutcomes = @($outcome)
                OutcomeCollectionStatus = @([PSCustomObject] @{ WorkloadId = 'app-1'; WorkloadName = 'Support app'; State = 'Available'; RecordCount = 1; ApiVersion = 'beta'; Reason = '' })
                Warnings = @(); GraphPermissionsUsed = @('DeviceManagementManagedDevices.Read.All'); GeneratedAt = [DateTimeOffset]::Now; ToolVersion = '1.3.0'
            }

            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $model

            $html | Should -Match 'data-view="managed-devices"'
            $html | Should -Match 'data-view="managed-users"'
            $html | Should -Match 'data-view="deployment-outcomes"'
            $html | Should -Match 'data-object-panel="managed-device-1"'
            $html | Should -Match 'data-object-panel="managed-user-1"'
            $html | Should -Match 'data-object-panel="deployment-outcome-1"'
            $html | Should -Match 'PC &lt;001&gt;'
            $html | Should -Match 'ABC&amp;123'
            $html | Should -Match '0x00000005'
            $html | Should -Match 'Missing outcome data is never presented as success'
        }
    }
}
