$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module $modulePath -Force

Describe 'End-to-end mocked Graph correlation' {
    InModuleScope IntuneAccess {
        It 'correlates raw Graph responses into a complete administrator access result' {
            $FixturePath = Join-Path $script:IntuneAccessModuleRoot 'Tests\Fixtures\basic-rbac.json'
            $fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json -Depth 20
            Mock Assert-IntuneAccessConnection {
                [PSCustomObject] @{
                    Account = 'analyst@example.test'
                    Scopes = @('User.Read', 'User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All')
                }
            }
            Mock Invoke-MgGraphRequest {
                switch -Wildcard ($Uri) {
                    '*/organization?*' {
                        return [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'tenant-1'; displayName = 'Example tenant'; verifiedDomains = @([PSCustomObject] @{ name = 'example.test'; isDefault = $true }) }) }
                    }
                    '*/roleScopeTags*' {
                        return [PSCustomObject] @{ value = @($fixture.scopeTag) }
                    }
                    '*/roleDefinitions/*/roleAssignments/60000000-0000-0000-0000-000000000001' {
                        return $fixture.roleAssignment
                    }
                    '*/roleDefinitions/*/roleAssignments*' {
                        return [PSCustomObject] @{ value = @($fixture.roleAssignment) }
                    }
                    '*/roleDefinitions' {
                        return [PSCustomObject] @{ value = @($fixture.roleDefinition) }
                    }
                    '*/memberOf/microsoft.graph.group*' {
                        return [PSCustomObject] @{ value = @($fixture.adminGroup) }
                    }
                    '*/transitiveMemberOf/microsoft.graph.group*' {
                        return [PSCustomObject] @{ value = @($fixture.adminGroup) }
                    }
                    "*/groups/$($fixture.adminGroup.id)?*" {
                        return $fixture.adminGroup
                    }
                    "*/groups/$($fixture.scopeGroup.id)?*" {
                        return $fixture.scopeGroup
                    }
                    '*/users/*' {
                        return $fixture.user
                    }
                    default {
                        throw "Unexpected mocked Graph URI: $Uri"
                    }
                }
            }

            $result = Get-IntuneAdminAccess -UserPrincipalName $fixture.user.userPrincipalName

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.AdminAccess'
            $result.User.Id | Should -Be $fixture.user.id
            $result.Tenant.DisplayName | Should -Be 'Example tenant'
            $result.RoleAssignments.Count | Should -Be 1
            $result.RoleAssignments[0].Applicability | Should -Be 'Confirmed'
            $result.RoleAssignments[0].AdminGroups[0].DisplayName | Should -Be $fixture.adminGroup.displayName
            $result.RoleAssignments[0].ScopeGroups[0].DisplayName | Should -Be $fixture.scopeGroup.displayName
            $result.RoleAssignments[0].ScopeTags[0].DisplayName | Should -Be $fixture.scopeTag.displayName
            $result.EffectivePermissions.Count | Should -Be 2
            $result.EffectivePermissions.State | Should -Not -Contain 'NotEvaluated'
            $result.Evidence[0].RoleAssignmentId | Should -Be $fixture.roleAssignment.id
        }
    }
}
