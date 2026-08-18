$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Tenant-wide Intune RBAC explorer' {
    InModuleScope IntuneAccess {
        It 'retains direct and nested user membership from an Admin Group' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('User.Read.All', 'GroupMember.Read.All') } }
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -match '/transitiveMembers/') {
                    return @(
                        [PSCustomObject] @{ id = 'user-direct'; displayName = 'Direct User'; userPrincipalName = 'direct@example.test'; accountEnabled = $true; userType = 'Member' }
                        [PSCustomObject] @{ id = 'user-nested'; displayName = 'Nested User'; userPrincipalName = 'nested@example.test'; accountEnabled = $true; userType = 'Member' }
                    )
                }
                return @([PSCustomObject] @{ id = 'user-direct'; displayName = 'Direct User'; userPrincipalName = 'direct@example.test'; accountEnabled = $true; userType = 'Member' })
            }
            $group = [PSCustomObject] @{ Id = 'group-1'; DisplayName = 'Intune Admins'; ResolutionState = 'Resolved' }

            $result = @(Get-IntuneAccessAdminGroupUsers -Group $group)

            $result.Count | Should -Be 2
            ($result | Where-Object { $_.User.Id -eq 'user-direct' }).MembershipType | Should -Be 'Direct'
            ($result | Where-Object { $_.User.Id -eq 'user-nested' }).MembershipType | Should -Be 'Nested'
            Should -Invoke Invoke-IntuneAccessGraphRequest -Times 2 -Exactly
        }

        It 'builds administrators and permissions from shared assignment evidence' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All') } }
            Mock Get-IntuneAccessTenant { [PSCustomObject] @{ Id = 'tenant-1'; DisplayName = 'Example tenant' } }
            $role = [PSCustomObject] @{ Id = 'role-1'; DisplayName = 'Help Desk Operator'; Description = 'Built-in helpdesk access'; IsBuiltIn = $true; RolePermissions = @(); PermissionDataState = 'Available' }
            $group = [PSCustomObject] @{ Id = 'group-1'; DisplayName = 'Intune Helpdesk'; Description = 'Intune administrators'; ResolutionState = 'Resolved' }
            $scope = [PSCustomObject] @{ Id = 'scope-1'; DisplayName = 'UK devices'; Description = 'United Kingdom devices'; ResolutionState = 'Resolved' }
            $tag = [PSCustomObject] @{ Id = 'tag-1'; DisplayName = 'UK'; Description = 'United Kingdom'; IsBuiltIn = $false; SourceApiVersion = 'beta' }
            $assignment = [PSCustomObject] @{
                Id = 'assignment-1'; Name = 'UK Helpdesk'; Description = 'Test assignment'; RoleDefinition = $role
                AdminGroups = @($group); ScopeGroups = @($scope); ScopeTags = @($tag); ScopeType = 'resourceScope'
                Permissions = @('Microsoft.Intune_ManagedDevices_Read'); SourceApiVersion = 'v1.0+beta'
                RawIds = [PSCustomObject] @{ AdminGroupIds = @('group-1'); ScopeGroupIds = @('scope-1'); ScopeTagIds = @('tag-1') }
            }
            Mock Get-IntuneAccessRoleDefinitions { @($role) }
            Mock Get-IntuneAccessRoleAssignments { @($assignment) }
            Mock Get-IntuneAccessAdminGroupUsers {
                @(
                    [PSCustomObject] @{ GroupId = 'group-1'; GroupName = 'Intune Helpdesk'; MembershipType = 'Direct'; User = [PSCustomObject] @{ Id = 'user-1'; DisplayName = 'Alex Wilber'; UserPrincipalName = 'alex@example.test'; UserType = 'Member' } }
                    [PSCustomObject] @{ GroupId = 'group-1'; GroupName = 'Intune Helpdesk'; MembershipType = 'Nested'; User = [PSCustomObject] @{ Id = 'user-2'; DisplayName = 'Nestor Wilke'; UserPrincipalName = 'nestor@example.test'; UserType = 'Member' } }
                )
            }

            $result = Get-IntuneAccessTenantRbac -InitialUserPrincipalName 'alex@example.test'

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.TenantRbac'
            $result.Administrators.Count | Should -Be 2
            $result.AdminGroups.Count | Should -Be 1
            $result.RoleAssignments.Count | Should -Be 1
            $result.RoleDefinitions.Count | Should -Be 1
            $result.ScopeGroups.Count | Should -Be 1
            $result.ScopeTags.Count | Should -Be 1
            $result.Permissions.Count | Should -Be 1
            ($result.Administrators | Where-Object { $_.User.Id -eq 'user-1' }).ConfirmedAssignments | Should -Be 1
            ($result.Administrators | Where-Object { $_.User.Id -eq 'user-2' }).ReviewAssignments | Should -Be 1
            $result.Permissions[0].AdministratorCount | Should -Be 2

            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $result
            $html | Should -Match 'Intune Helpdesk'
            $html | Should -Match 'UK Helpdesk'
            $html | Should -Match 'Help Desk Operator'
            $html | Should -Match 'UK devices'
            $html | Should -Match 'Microsoft\.Intune_ManagedDevices_Read'
            $html | Should -Match 'data-object-panel="admin-group-1"'
            $html | Should -Match 'data-object-panel="assignment-1"'
            $html | Should -Match 'data-object-panel="role-1"'
        }

        It 'renders encoded tenant data, navigation, relationships and long identity wrapping' {
            $administrator = [PSCustomObject] @{
                User = [PSCustomObject] @{ Id = 'user-1'; DisplayName = 'CADTB <Admin>'; UserPrincipalName = 'CADTB-Intune-Administration@controlaltdeletetechbits.onmicrosoft.com'; UserType = 'Member' }
                AdminGroupMemberships = @()
                RoleAssignments = @()
                EffectivePermissions = @()
                ConfirmedAssignments = 0
                ReviewAssignments = 0
            }
            $tenantRbac = [PSCustomObject] @{
                PSTypeName = 'IntuneAccess.TenantRbac'
                Tenant = [PSCustomObject] @{ Id = 'tenant-1'; DisplayName = 'Example & Sons' }
                Administrators = @($administrator)
                AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
                Warnings = @('Review <tenant>')
                InitialUserPrincipalName = $administrator.User.UserPrincipalName
                GraphPermissionsUsed = @('DeviceManagementRBAC.Read.All')
                GeneratedAt = [DateTimeOffset]::Parse('2026-08-18T10:16:00+01:00')
                ToolVersion = '1.3.0'
            }

            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $tenantRbac

            $html | Should -Match 'data-view="administrators"'
            $html | Should -Match 'data-view="admin-groups"'
            $html | Should -Match 'data-view="assignments"'
            $html | Should -Match 'data-view="scope-tags"'
            $html | Should -Match 'data-view="permissions"'
            $html | Should -Match 'data-inspect="administrator-1"'
            $html | Should -Match 'Example &amp; Sons'
            $html | Should -Match 'CADTB &lt;Admin&gt;'
            $html | Should -Not -Match 'https?://'
            $html | Should -Match 'overflow-wrap:anywhere'
            $html | Should -Match 'Content-Security-Policy'
        }
    }
}
