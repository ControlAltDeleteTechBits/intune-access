$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Feature-scoped connection permissions' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Connect-MgGraph {}
            Mock Get-IntuneAccessTenant { [PSCustomObject] @{ DisplayName = 'Example tenant' } }
            Mock Assert-IntuneAccessConnection {
                [PSCustomObject] @{
                    Account = 'admin@example.test'
                    TenantId = 'tenant-1'
                    Environment = 'Global'
                    AuthType = 'Delegated'
                    Scopes = @($RequiredScope)
                }
            }
        }

        It 'keeps the base scope-tag audit free of script permissions' {
            $result = Connect-IntuneAccess -Feature Core, ScopeTagAudit

            $result.Scopes | Should -Contain 'DeviceManagementConfiguration.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementApps.Read.All'
            $result.Scopes | Should -Not -Contain 'DeviceManagementScripts.Read.All'
        }

        It 'adds the script read permission only for the extended audit' {
            $result = Connect-IntuneAccess -Feature Core, ExtendedScopeTagAudit

            $result.Scopes | Should -Contain 'DeviceManagementScripts.Read.All'
            @($result.Scopes | Where-Object { $_ -match 'ReadWrite' }).Count | Should -Be 0
        }

        It 'adds only read permissions for the assignment explorer' {
            $result = Connect-IntuneAccess -Feature Core, AssignmentExplorer

            $result.Scopes | Should -Contain 'DeviceManagementConfiguration.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementApps.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementScripts.Read.All'
            @($result.Scopes | Where-Object { $_ -match 'ReadWrite' }).Count | Should -Be 0
        }

        It 'adds managed-device and workload read permissions for operational evidence' {
            $result = Connect-IntuneAccess -Feature Core, OperationalEvidence

            $result.Scopes | Should -Contain 'DeviceManagementManagedDevices.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementConfiguration.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementApps.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementScripts.Read.All'
            @($result.Scopes | Where-Object { $_ -match 'ReadWrite' }).Count | Should -Be 0
        }

        It 'uses only the configuration read permission for policy analysis' {
            $result = Connect-IntuneAccess -Feature Core, PolicyAnalysis

            $result.Scopes | Should -Contain 'DeviceManagementConfiguration.Read.All'
            $result.Scopes | Should -Not -Contain 'DeviceManagementApps.Read.All'
            $result.Scopes | Should -Not -Contain 'DeviceManagementScripts.Read.All'
            @($result.Scopes | Where-Object { $_ -match 'ReadWrite' }).Count | Should -Be 0
        }

        It 'uses the documented application read permission for Intune audit evidence' {
            $result = Connect-IntuneAccess -Feature Core, AuditEvidence

            $result.Scopes | Should -Contain 'DeviceManagementApps.Read.All'
            @($result.Scopes | Where-Object { $_ -match 'ReadWrite' }).Count | Should -Be 0
        }
    }
}
