$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Local IntuneAccess snapshots' {
    InModuleScope IntuneAccess {
        It 'preserves nested string tokens using the compatibility parser' {
            $json='{"stamp":"2026-09-15T10:00:00.0000000+00:00","items":["2026-09-15T14:00:00+03:00",{"stamp":"2026-09-15T10:00:00Z"}],"number":12,"empty":[]}'
            $result=ConvertFrom-IntuneAccessSnapshotJson -Json $json -CompatibilityParser
            $result.stamp | Should -BeExactly '2026-09-15T10:00:00.0000000+00:00'
            $result.items[0] | Should -BeExactly '2026-09-15T14:00:00+03:00'
            $result.items[1].stamp | Should -BeExactly '2026-09-15T10:00:00Z'
            $result.number | Should -Be 12
            @($result.empty).Count | Should -Be 0
        }
    }
    BeforeEach {
        $script:baseModel = [PSCustomObject] @{
            PSTypeName = 'IntuneAccess.TenantRbac'
            Tenant = [PSCustomObject] @{ Id = 'tenant-1'; DisplayName = 'Example tenant' }
            Administrators = @([PSCustomObject] @{ User = [PSCustomObject] @{ Id = 'user-1'; DisplayName = 'Alex Wilber'; UserPrincipalName = 'alex@example.test' } })
            AdminGroups = @([PSCustomObject] @{ Id = 'group-1'; DisplayName = 'Intune Admins' })
            RoleAssignments = @([PSCustomObject] @{ Id = 'role-assignment-1'; Name = 'Help desk access'; RawIds = [PSCustomObject] @{ AdminGroupIds = @('group-1'); ScopeGroupIds = @('scope-1'); ScopeTagIds = @('tag-1') } })
            RoleDefinitions = @()
            ScopeGroups = @()
            ScopeTags = @([PSCustomObject] @{ Id = 'tag-1'; DisplayName = 'UK' })
            Permissions = @()
            Memberships = @()
            WorkloadObjects = @([PSCustomObject] @{ Id = 'policy-1'; Name = 'Secure configuration'; WorkloadType = 'Configuration'; ScopeTagIds = @('tag-1') })
            WorkloadAssignments = @([PSCustomObject] @{ Id = 'assignment-1'; WorkloadId = 'policy-1'; WorkloadName = 'Secure configuration'; TargetType = 'All devices'; TargetId = 'allDevices'; Intent = 'Include' })
            WorkloadGroups = @()
            AssignmentFilters = @()
            ManagedDevices = @([PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; UserPrincipalName = 'alex@example.test'; SerialNumber = 'ABC123' })
            ManagedUsers = @([PSCustomObject] @{ Id = 'user-1'; UserPrincipalName = 'alex@example.test' })
            DeploymentOutcomes = @()
            WorkloadCollectionStatus = @()
            OutcomeCollectionStatus = @()
            AuditEvents = @([PSCustomObject] @{ Id = 'audit-1'; Activity = 'Update policy assignment'; ActivityDateTime = '2026-08-18T10:00:00Z'; ActorIpAddress = '192.0.2.10'; ResourceIds = @('policy-1') })
            GraphPermissionsGranted = @('DeviceManagementRBAC.Read.All')
            AccessToken = 'must-not-be-exported'
            GeneratedAt = [DateTimeOffset]::Now
        }
    }

    It 'exports only allow-listed evidence and validates its integrity during comparison' {
        $beforePath = Join-Path $TestDrive 'before.json'
        $afterPath = Join-Path $TestDrive 'after.json'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $beforePath
        $script:baseModel.WorkloadAssignments[0].Intent = 'Exclude'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $afterPath

        $raw = Get-Content -LiteralPath $beforePath -Raw
        $raw | Should -Not -Match 'must-not-be-exported'
        $raw | Should -Not -Match 'GraphPermissionsGranted'
        $comparison = Compare-IntuneAccessSnapshot -ReferencePath $beforePath -DifferencePath $afterPath

        $comparison.PSObject.TypeNames | Should -Contain 'IntuneAccess.SnapshotComparison'
        $comparison.ModifiedCount | Should -Be 1
        $comparison.Changes[0].EntityType | Should -Be 'WorkloadAssignment'
        $comparison.Changes[0].ChangedProperties | Should -Contain 'Intent'
        $comparison.Changes[0].ImpactState | Should -Be 'BroadTarget'
        $comparison.Changes[0].PotentialDeviceCount | Should -Be 1
        $comparison.Changes[0].AuditEvidenceState | Should -Be 'ObservedRelatedEvent'
        $comparison.Changes[0].AuditEvents[0].Id | Should -Be 'audit-1'

        $reportModel = [PSCustomObject] @{
            PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }
            Administrators = @(); AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
            WorkloadObjects = @(); WorkloadAssignments = @(); WorkloadGroups = @(); AssignmentFilters = @(); WorkloadCollectionStatus = @()
            ManagedDevices = @(); ManagedUsers = @(); DeploymentOutcomes = @(); OutcomeCollectionStatus = @(); Warnings = @(); GraphPermissionsUsed = @()
            SnapshotComparison = $comparison; GeneratedAt = [DateTimeOffset]::Now; ToolVersion = '1.4.0'
        }
        $htmlPath = Join-Path $TestDrive 'changes.html'
        $null = $reportModel | Export-IntuneAccessReport -Path $htmlPath
        $html = Get-Content -LiteralPath $htmlPath -Raw
        $html | Should -Match 'data-view="snapshot-changes"'
        $html | Should -Match 'Modified: Secure configuration'
        $html | Should -Match 'All devices target; 1 managed device records were present'
    }

    It 'preserves timestamp strings with UTC and non-local offsets during integrity validation' {
        $beforePath=Join-Path $TestDrive 'offset-before.json'
        $afterPath=Join-Path $TestDrive 'offset-after.json'
        $script:baseModel.GeneratedAt='2026-09-15T10:00:00.0000000+00:00'
        $script:baseModel.AuditEvents[0].ActivityDateTime='2026-09-15T14:00:00+03:00'
        $null=$script:baseModel|Export-IntuneAccessSnapshot -Path $beforePath
        $script:baseModel.GeneratedAt='2026-09-15T11:00:00.0000000+00:00'
        $null=$script:baseModel|Export-IntuneAccessSnapshot -Path $afterPath
        {Compare-IntuneAccessSnapshot -ReferencePath $beforePath -DifferencePath $afterPath} | Should -Not -Throw
    }

    It 'uses stable pseudonyms while removing clear tenant and identity values' {
        $firstPath = Join-Path $TestDrive 'redacted-1.json'
        $secondPath = Join-Path $TestDrive 'redacted-2.json'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $firstPath -RedactIdentity
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $secondPath -RedactIdentity

        $first = Get-Content -LiteralPath $firstPath -Raw
        $second = Get-Content -LiteralPath $secondPath -Raw
        $first | Should -Not -Match 'alex@example\.test|Example tenant|PC-001|ABC123|192\.0\.2\.10'
        (ConvertFrom-Json $first).Data.ManagedDevices[0].Id | Should -Be (ConvertFrom-Json $second).Data.ManagedDevices[0].Id
        (ConvertFrom-Json $first).IdentityMode | Should -Be 'Pseudonymised'
    }

    It 'rejects an edited snapshot' {
        $beforePath = Join-Path $TestDrive 'original.json'
        $afterPath = Join-Path $TestDrive 'edited.json'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $beforePath
        (Get-Content -LiteralPath $beforePath -Raw).Replace('PC-001', 'PC-999') | Set-Content -LiteralPath $afterPath

        { Compare-IntuneAccessSnapshot -ReferencePath $beforePath -DifferencePath $afterPath } | Should -Throw '*integrity*'
    }
    It 'rejects different tenants even when both snapshots have valid integrity' {
        $beforePath = Join-Path $TestDrive 'tenant-before.json'
        $afterPath = Join-Path $TestDrive 'tenant-after.json'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $beforePath
        $script:baseModel.Tenant.Id = 'different-tenant'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $afterPath
        { Compare-IntuneAccessSnapshot -ReferencePath $beforePath -DifferencePath $afterPath } | Should -Throw '*same tenant*'
    }
    It 'rejects reverse chronological comparison' {
        $beforePath = Join-Path $TestDrive 'chronology-before.json'
        $afterPath = Join-Path $TestDrive 'chronology-after.json'
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $beforePath
        $null = $script:baseModel | Export-IntuneAccessSnapshot -Path $afterPath
        { Compare-IntuneAccessSnapshot -ReferencePath $afterPath -DifferencePath $beforePath } | Should -Throw '*later than*'
    }
}
