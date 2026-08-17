$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module $modulePath -Force

$hasTestUser = -not [string]::IsNullOrWhiteSpace($env:INTUNEACCESS_TEST_UPN)
$hasTestDevice = -not [string]::IsNullOrWhiteSpace($env:INTUNEACCESS_TEST_DEVICE)
$runScopeAudit = $env:INTUNEACCESS_TEST_SCOPE_AUDIT -eq '1'
$expectPositiveRbac = $env:INTUNEACCESS_EXPECT_POSITIVE_RBAC -eq '1'

Describe 'Live tenant administrator analysis' -Tag 'Integration' -Skip:(-not $hasTestUser) {
    BeforeAll {
        $context = Get-MgContext
        if ($null -eq $context -or [string]::IsNullOrWhiteSpace([string] $context.Account)) {
            throw 'Connect with Connect-IntuneAccess in this PowerShell process before running integration tests.'
        }
        $script:liveAccess = Get-IntuneAdminAccess -UserPrincipalName $env:INTUNEACCESS_TEST_UPN
    }

    It 'returns the complete structured contract' {
        $script:liveAccess.PSObject.TypeNames | Should -Contain 'IntuneAccess.AdminAccess'
        $script:liveAccess.User.UserPrincipalName | Should -Be $env:INTUNEACCESS_TEST_UPN
        $script:liveAccess.Tenant.Id | Should -Not -BeNullOrEmpty
        $script:liveAccess.PSObject.Properties.Name | Should -Contain 'RoleAssignments'
        $script:liveAccess.PSObject.Properties.Name | Should -Contain 'EffectivePermissions'
        $script:liveAccess.PSObject.Properties.Name | Should -Contain 'Evidence'
        $script:liveAccess.ToolVersion | Should -Be '1.0.0'
    }

    It 'retains source IDs and beta data state for every matching assignment' {
        foreach ($assignment in @($script:liveAccess.RoleAssignments)) {
            $assignment.Id | Should -Not -BeNullOrEmpty
            $assignment.RoleDefinition.Id | Should -Not -BeNullOrEmpty
            $assignment.RawIds | Should -Not -BeNull
            $assignment.AdminGroupDataState | Should -BeIn @('Available', 'Missing')
            $assignment.ScopeGroupDataState | Should -BeIn @('Available', 'Missing')
            $assignment.ScopeTagDataState | Should -BeIn @('Available', 'Missing')
            $assignment.ScopeTypeDataState | Should -BeIn @('Available', 'Missing')
        }
    }

    It 'retains granting evidence for every effective permission' {
        foreach ($permission in @($script:liveAccess.EffectivePermissions)) {
            $permission.RawAction | Should -Not -BeNullOrEmpty
            $permission.State | Should -BeIn @('Allowed', 'NotEvaluated')
            $permission.GrantedBy.Count | Should -BeGreaterThan 0
            foreach ($grant in @($permission.GrantedBy)) {
                $grant.RoleAssignmentId | Should -Not -BeNullOrEmpty
                $grant.RoleDefinitionId | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'matches the built-in and custom positive RBAC fixture' -Skip:(-not $expectPositiveRbac) {
        $assignments = @($script:liveAccess.RoleAssignments)
        $assignments.Name | Should -Contain 'IntuneAccess v1 Builtin Assignment'
        $assignments.Name | Should -Contain 'IntuneAccess v1 Custom Assignment'

        $builtIn = $assignments | Where-Object Name -EQ 'IntuneAccess v1 Builtin Assignment' | Select-Object -First 1
        $custom = $assignments | Where-Object Name -EQ 'IntuneAccess v1 Custom Assignment' | Select-Object -First 1
        $builtIn.RoleDefinition.DisplayName | Should -Be 'Help Desk Operator'
        $builtIn.RoleDefinition.IsBuiltIn | Should -BeTrue
        $custom.RoleDefinition.DisplayName | Should -Be 'IntuneAccess v1 Device Reader'
        $custom.RoleDefinition.IsBuiltIn | Should -BeFalse
        $builtIn.AdminGroups.DisplayName | Should -Contain 'IntuneAccess-v1-Admins-Builtin'
        $custom.AdminGroups.DisplayName | Should -Contain 'IntuneAccess-v1-Admins-Custom'
        $builtIn.ScopeGroups.DisplayName | Should -Contain 'IntuneAccess-v1-Device-Scope'
        $custom.ScopeGroups.DisplayName | Should -Contain 'IntuneAccess-v1-Device-Scope'
        $builtIn.ScopeTags.DisplayName | Should -Contain 'IntuneAccess-v1-Lab'
        $custom.ScopeTags.DisplayName | Should -Contain 'IntuneAccess-v1-Lab'

        $managedDeviceRead = $script:liveAccess.EffectivePermissions |
            Where-Object RawAction -EQ 'Microsoft.Intune_ManagedDevices_Read' |
            Select-Object -First 1
        $managedDeviceRead.State | Should -Be 'Allowed'
        $managedDeviceRead.GrantedBy.Count | Should -BeGreaterOrEqual 2
    }

    It 'exports an offline HTML report from the live result' {
        $reportPath = Join-Path $TestDrive 'IntuneAccess-live-validation.html'
        $file = $script:liveAccess | Export-IntuneAccessReport -Path $reportPath -WarningAction SilentlyContinue
        $file.Exists | Should -BeTrue
        $html = Get-Content -Raw -LiteralPath $reportPath
        $html | Should -Not -Match '<script\s+src='
        $html | Should -Not -Match '<link\s+[^>]*href='
        $html | Should -Not -Match 'https?://'
    }
}

Describe 'Live tenant managed-device explanation' -Tag 'Integration' -Skip:(-not ($hasTestUser -and $hasTestDevice)) {
    It 'returns only a proved path or NotEvaluated' {
        $result = Test-IntuneResourceAccess `
            -UserPrincipalName $env:INTUNEACCESS_TEST_UPN `
            -DeviceName $env:INTUNEACCESS_TEST_DEVICE
        $result.Result | Should -BeIn @('AccessPathFound', 'NotEvaluated')
        $result.Result | Should -Not -Be 'AccessDenied'
        $result.Resource.Id | Should -Not -BeNullOrEmpty
        $result.Resource.ScopeTagDataState | Should -BeIn @('Available', 'Missing')
        if ($expectPositiveRbac) {
            $matchingPaths = @($result.AccessPaths | Where-Object ScopeGroupState -EQ 'Matched')
            $matchingPaths.Count | Should -BeGreaterOrEqual 2
            $matchingPaths.ScopeMatchSource | Should -Contain 'DeviceGroup'
            $matchingPaths.ScopeGroups.DisplayName | Should -Contain 'IntuneAccess-v1-Device-Scope'
        }
    }
}

Describe 'Live tenant scope-tag audit' -Tag 'Integration' -Skip:(-not $runScopeAudit) {
    It 'returns only conservative finding severities and the required schema' {
        $findings = @(Get-IntuneScopeTagAudit)
        foreach ($finding in $findings) {
            $finding.Severity | Should -BeIn @('Information', 'Review', 'Warning')
            $finding.FindingId | Should -Not -BeNullOrEmpty
            $finding.Title | Should -Not -BeNullOrEmpty
            $finding.ObservedState | Should -Not -BeNullOrEmpty
            $finding.Recommendation | Should -Not -BeNullOrEmpty
            $finding.DocumentationUrl | Should -Match '^https://learn\.microsoft\.com/'
        }
    }
}
