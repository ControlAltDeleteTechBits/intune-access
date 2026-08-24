$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Device inventory and hygiene evidence' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('DeviceManagementManagedDevices.Read.All', 'Device.Read.All') } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{ id = 'entra-object-1'; deviceId = '11111111-1111-1111-1111-111111111111'; displayName = 'PC-001'; accountEnabled = $true; operatingSystem = 'Windows'; operatingSystemVersion = '10.0.26100'; trustType = 'AzureAd' })
            }
        }

        It 'reconciles an exact Intune and Microsoft Entra device identity' {
            $device = [PSCustomObject] @{ Id = 'intune-1'; DeviceName = 'PC-001'; EntraDeviceId = '11111111-1111-1111-1111-111111111111'; SerialNumber = 'ABC1'; UserId = 'user-1'; UserPrincipalName = 'a@example.test'; OperatingSystem = 'Windows'; OsVersion = '10.0.26100'; ComplianceState = 'compliant'; LastSyncDateTime = '2026-08-23T12:00:00Z'; EnrolledDateTime = '2026-08-01T12:00:00Z' }
            $result = Get-IntuneAccessDeviceIntelligence -ManagedDevice @($device) -AsOf ([DateTimeOffset]::Parse('2026-08-24T12:00:00Z'))
            $result.Inventory[0].EntraCorrelationState | Should -Be 'Matched'
            @($result.Findings).Count | Should -Be 0
        }

        It 'finds stale check-in, missing user, unknown compliance and identity gaps' {
            Mock Invoke-IntuneAccessGraphRequest { @() }
            $device = [PSCustomObject] @{ Id = 'intune-1'; DeviceName = 'PC-001'; EntraDeviceId = '11111111-1111-1111-1111-111111111111'; SerialNumber = 'ABC1'; UserId = ''; OperatingSystem = 'Windows'; OsVersion = '10.0.26100'; ComplianceState = 'unknown'; LastSyncDateTime = '2026-06-01T12:00:00Z'; EnrolledDateTime = '2026-05-01T12:00:00Z' }
            $result = Get-IntuneAccessDeviceIntelligence -ManagedDevice @($device) -AsOf ([DateTimeOffset]::Parse('2026-08-24T12:00:00Z'))
            $result.Findings.RuleId | Should -Contain 'DEV-CHECKIN-STALE'
            $result.Findings.RuleId | Should -Contain 'DEV-PRIMARY-USER-MISSING'
            $result.Findings.RuleId | Should -Contain 'DEV-COMPLIANCE-UNKNOWN'
            $result.Findings.RuleId | Should -Contain 'DEV-ENTRA-CORRELATION'
            ($result.Findings | Where-Object RuleId -EQ 'DEV-CHECKIN-STALE').ReviewRecommendation | Should -Match 'lifecycle action'
        }

        It 'finds duplicate serial and Microsoft Entra identifiers without selecting a record to remove' {
            $base = @{ EntraDeviceId = '11111111-1111-1111-1111-111111111111'; SerialNumber = 'DUPLICATE'; UserId = 'user-1'; OperatingSystem = 'Windows'; OsVersion = '10.0.26100'; ComplianceState = 'compliant'; LastSyncDateTime = '2026-08-23T12:00:00Z' }
            $devices = @([PSCustomObject] ($base + @{ Id = 'one'; DeviceName = 'PC-ONE' }), [PSCustomObject] ($base + @{ Id = 'two'; DeviceName = 'PC-TWO' }))
            $result = Get-IntuneAccessDeviceIntelligence -ManagedDevice $devices -AsOf ([DateTimeOffset]::Parse('2026-08-24T12:00:00Z'))
            @($result.Findings | Where-Object RuleId -EQ 'DEV-DUPLICATE-SERIAL').Count | Should -Be 2
            @($result.Findings | Where-Object RuleId -EQ 'DEV-DUPLICATE-ENTRA-ID').Count | Should -Be 2
            $result.Findings.ReviewRecommendation -join ' ' | Should -Not -Match '(?i)delete this record'
        }

        It 'retains a Microsoft Entra collection failure as partial evidence' {
            Mock Invoke-IntuneAccessGraphRequest { throw 'simulated Entra failure' }
            $result = Get-IntuneAccessDeviceIntelligence -ManagedDevice @()
            $result.CollectionStatus.State | Should -Be 'Partial'
            $result.Warnings -join ' ' | Should -Match 'simulated Entra failure'
        }
    }
}

Describe 'Device assignment explanation' {
    InModuleScope IntuneAccess {
        BeforeEach {
            $script:device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; UserId = 'user-1'; Manufacturer = 'Contoso'; Model = 'Virtual'; OsVersion = '10.0.26100'; Ownership = 'Corporate' }
            $script:workload = [PSCustomObject] @{ Id = 'policy-1'; Name = 'Secure policy'; WorkloadType = 'Configuration' }
            $script:evaluatedDevice = [PSCustomObject] @{ State = 'Evaluated'; GroupIds = @('device-group'); Groups = @() }
            $script:evaluatedUser = [PSCustomObject] @{ State = 'Evaluated'; GroupIds = @('user-group'); Groups = @() }
        }

        It 'separates a broad device target from reported outcome evidence' {
            $assignment = [PSCustomObject] @{ Id = 'a1'; WorkloadId = 'policy-1'; Intent = 'assign'; TargetType = 'All devices'; GroupId = ''; FilterId = ''; FilterMode = 'none'; SourceApiVersion = 'v1.0' }
            $result = Resolve-IntuneAccessDeviceAssignment -Device $device -Workload @($workload) -Assignment @($assignment) -DeviceMembership $evaluatedDevice -UserMembership $evaluatedUser
            $result.AssignmentState | Should -Be 'Included'
            $result.ReportedOutcomeState | Should -Be 'NoReportedEvidence'
            $result.EvidenceBoundary | Should -Match 'does not prove delivery'
        }

        It 'lets an observed exclusion take precedence over inclusion' {
            $assignments = @(
                [PSCustomObject] @{ Id = 'a1'; WorkloadId = 'policy-1'; Intent = 'assign'; TargetType = 'All devices'; GroupId = ''; FilterId = ''; FilterMode = 'none'; SourceApiVersion = 'v1.0' },
                [PSCustomObject] @{ Id = 'a2'; WorkloadId = 'policy-1'; Intent = 'exclude'; TargetType = 'Excluded group'; GroupId = 'device-group'; FilterId = ''; FilterMode = 'none'; SourceApiVersion = 'v1.0'; Group = [PSCustomObject] @{ DisplayName = 'Excluded devices' } }
            )
            $result = Resolve-IntuneAccessDeviceAssignment -Device $device -Workload @($workload) -Assignment $assignments -DeviceMembership $evaluatedDevice -UserMembership $evaluatedUser
            $result.AssignmentState | Should -Be 'Excluded'
            $result.AssignmentPaths.PathState | Should -Contain 'Excluded'
        }

        It 'evaluates a supported simple include filter' {
            $filter = [PSCustomObject] @{ Rule = '(device.manufacturer -eq "Contoso")' }
            $assignment = [PSCustomObject] @{ Id = 'a1'; WorkloadId = 'policy-1'; Intent = 'assign'; TargetType = 'All devices'; GroupId = ''; FilterId = 'f1'; FilterMode = 'include'; Filter = $filter; SourceApiVersion = 'beta' }
            $result = Resolve-IntuneAccessDeviceAssignment -Device $device -Workload @($workload) -Assignment @($assignment) -DeviceMembership $evaluatedDevice -UserMembership $evaluatedUser
            $result.AssignmentPaths.FilterState | Should -Be 'Passed'
            $result.AssignmentState | Should -Be 'Included'
        }

        It 'uses NotEvaluated for a compound filter rather than guessing' {
            $filter = [PSCustomObject] @{ Rule = '(device.manufacturer -eq "Contoso") and (device.model -eq "Virtual")' }
            $assignment = [PSCustomObject] @{ Id = 'a1'; WorkloadId = 'policy-1'; Intent = 'assign'; TargetType = 'All devices'; GroupId = ''; FilterId = 'f1'; FilterMode = 'include'; Filter = $filter; SourceApiVersion = 'beta' }
            $result = Resolve-IntuneAccessDeviceAssignment -Device $device -Workload @($workload) -Assignment @($assignment) -DeviceMembership $evaluatedDevice -UserMembership $evaluatedUser
            $result.AssignmentState | Should -Be 'NotEvaluated'
            $result.AssignmentPaths.FilterRule | Should -Match 'and'
        }

        It 'retains independent associated-user group evidence' {
            $assignment = [PSCustomObject] @{ Id = 'a1'; WorkloadId = 'policy-1'; Intent = 'assign'; TargetType = 'Included group'; GroupId = 'user-group'; FilterId = ''; FilterMode = 'none'; SourceApiVersion = 'v1.0'; Group = [PSCustomObject] @{ DisplayName = 'Users' } }
            $result = Resolve-IntuneAccessDeviceAssignment -Device $device -Workload @($workload) -Assignment @($assignment) -DeviceMembership $evaluatedDevice -UserMembership $evaluatedUser
            $result.AssignmentPaths.DeviceTargetState | Should -Be 'NotMatched'
            $result.AssignmentPaths.UserTargetState | Should -Be 'Matched'
            $result.AssignmentState | Should -Be 'Included'
        }
    }
}
