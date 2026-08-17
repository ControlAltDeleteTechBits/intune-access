$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Administrator access analysis' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All'); Account = 'analyst@example.test' } }
            Mock Resolve-IntuneAccessUser { [PSCustomObject] @{ Id = '10000000-0000-0000-0000-000000000001'; DisplayName = 'Alex'; UserPrincipalName = 'alex@example.test' } }
            Mock Get-IntuneAccessTenant { [PSCustomObject] @{ Id = 'tenant'; DisplayName = 'Example'; DefaultDomain = 'example.test' } }
            Mock Get-IntuneAccessRoleDefinitions { @() }
            Mock Get-IntuneAccessRoleAssignments { @() }
        }

        It 'scenario 5: gives a clean result when no role assignment matches' {
            Mock Get-IntuneAccessGroupMembership { @() }
            $result = Get-IntuneAdminAccess -UserPrincipalName 'alex@example.test'
            $result.RoleAssignments.Count | Should -Be 0
            $result.EffectivePermissions.Count | Should -Be 0
            $result.Warnings -join ' ' | Should -Match 'No matching Intune RBAC role assignment'
        }

        It 'marks nested-only administrator-group evidence as NotEvaluated' {
            Mock Get-IntuneAccessGroupMembership {
                @([PSCustomObject] @{ Id = 'group-1'; DisplayName = 'Nested admins'; MembershipType = 'Nested' })
            }
            Mock Get-IntuneAccessRoleAssignments {
                @([PSCustomObject] @{
                    Id = 'assignment-1'; Name = 'Nested assignment'; Description = ''
                    RoleDefinition = [PSCustomObject] @{ Id = 'role-1'; DisplayName = 'Custom role'; IsBuiltIn = $false }
                    AdminGroups = @(); ScopeGroups = @(); ScopeTags = @(); ScopeType = 'resourceScope'
                    Permissions = @('Microsoft.Intune_ManagedDevices_Read')
                    Applicability = 'NotAssessed'; AdminGroupEvidence = @(); SourceApiVersion = 'beta'
                    RawIds = [PSCustomObject] @{ AdminGroupIds = @('group-1'); ScopeGroupIds = @(); ScopeMemberIds = @(); ScopeTagIds = @() }
                })
            }
            $result = Get-IntuneAdminAccess -UserPrincipalName 'alex@example.test'
            $result.RoleAssignments[0].Applicability | Should -Be 'NotEvaluated'
            $result.EffectivePermissions[0].State | Should -Be 'NotEvaluated'
        }

        It 'warns when assignment member data is missing instead of treating it as no access' {
            Mock Get-IntuneAccessGroupMembership { @() }
            Mock Get-IntuneAccessRoleAssignments {
                @([PSCustomObject] @{
                    Id = 'assignment-incomplete'; Name = 'Incomplete assignment'; Description = ''
                    RoleDefinition = [PSCustomObject] @{ Id = 'role-1'; DisplayName = 'Role'; IsBuiltIn = $true; PermissionDataState = 'Available' }
                    AdminGroups = @(); AdminGroupDataState = 'Missing'; ScopeGroups = @(); ScopeTags = @(); ScopeType = 'unknown'
                    Permissions = @(); Applicability = 'NotAssessed'; AdminGroupEvidence = @(); SourceApiVersion = 'beta'
                    RawIds = [PSCustomObject] @{ AdminGroupIds = @(); ScopeGroupIds = @(); ScopeMemberIds = @(); ScopeTagIds = @() }
                })
            }
            $result = Get-IntuneAdminAccess -UserPrincipalName 'alex@example.test'
            $result.Warnings -join ' ' | Should -Match 'did not return the members property'
            $result.Warnings -join ' ' | Should -Match 'could not be evaluated'
        }
    }
}
