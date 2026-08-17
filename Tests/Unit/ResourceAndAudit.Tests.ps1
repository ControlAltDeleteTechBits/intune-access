$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Resource access and scope-tag audit safeguards' {
    InModuleScope IntuneAccess {
        It 'scenario 9: refuses to select between duplicate managed-device names' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @(
                    [PSCustomObject] @{ id = 'device-1'; deviceName = 'PC-001' }
                    [PSCustomObject] @{ id = 'device-2'; deviceName = 'PC-001' }
                )
            }
            { Test-IntuneResourceAccess -UserPrincipalName 'admin@example.test' -DeviceName 'PC-001' } | Should -Throw '*Several Intune managed devices*'
        }

        It 'scenario 10: treats an empty resource tag list as the Default scope tag' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{ id = 'config-1'; displayName = 'Baseline'; roleScopeTagIds = @(); supportsScopeTags = $true })
            } -ParameterFilter { $Uri -like 'deviceManagement/deviceConfigurations*' }
            Mock Invoke-IntuneAccessGraphRequest { @() } -ParameterFilter { $Uri -like 'deviceAppManagement/mobileApps*' }
            $resource = @(Get-IntuneAccessAuditedResources)
            $resource[0].ScopeTagIds | Should -Be @('0')
        }

        It 'does not treat a missing beta scope-tag property as Default' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{ id = 'config-2'; displayName = 'Incomplete response'; supportsScopeTags = $true })
            } -ParameterFilter { $Uri -like 'deviceManagement/deviceConfigurations*' }
            Mock Invoke-IntuneAccessGraphRequest { @() } -ParameterFilter { $Uri -like 'deviceAppManagement/mobileApps*' }
            $resource = @(Get-IntuneAccessAuditedResources)
            $resource[0].ScopeTagDataState | Should -Be 'Missing'
            $resource[0].ScopeTagIds.Count | Should -Be 0
        }

        It 'collects extended scope-tag resource families only when requested' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest { @() } -ParameterFilter { $Uri -like 'deviceManagement/deviceConfigurations*' -or $Uri -like 'deviceAppManagement/mobileApps*' }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{ id = 'compliance-1'; displayName = 'Compliance'; roleScopeTagIds = @('tag-1') })
            } -ParameterFilter { $Uri -like 'deviceManagement/deviceCompliancePolicies*' }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{ id = 'settings-1'; name = 'Settings'; roleScopeTagIds = @('tag-2') })
            } -ParameterFilter { $Uri -like 'deviceManagement/configurationPolicies*' }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{ id = 'script-1'; displayName = 'Remediation'; roleScopeTagIds = @('tag-3') })
            } -ParameterFilter { $Uri -like 'deviceManagement/deviceHealthScripts*' }

            $resources = @(Get-IntuneAccessAuditedResources -IncludeExtended)

            $resources.ResourceType | Should -Contain 'Compliance policy'
            $resources.ResourceType | Should -Contain 'Settings Catalog or endpoint security policy'
            $resources.ResourceType | Should -Contain 'Remediation or device health script'
            $resources.ResourceName | Should -Contain 'Settings'
        }

        It 'marks missing assignment beta properties instead of inferring scope' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'assignment-incomplete'
                    displayName = 'Incomplete assignment'
                    members = @('group-1')
                    resourceScopes = @('scope-1')
                })
            }
            $definition = [PSCustomObject] @{
                Id = 'role-1'; DisplayName = 'Role'; IsBuiltIn = $true
                RolePermissions = @(); PermissionDataState = 'Available'
            }
            $assignment = @(Get-IntuneAccessRoleAssignments -RoleDefinition $definition)
            $assignment[0].ScopeTagDataState | Should -Be 'Missing'
            $assignment[0].ScopeTypeDataState | Should -Be 'Missing'
            $assignment[0].ScopeType | Should -Be 'unknown'
        }

        It 'retains stable v1.0 assignment data when beta enrichment fails' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest { throw 'Simulated beta failure' } -ParameterFilter { $ApiVersion -eq 'beta' }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'assignment-stable'; displayName = 'Stable assignment'
                    members = @('admin-group-1'); resourceScopes = @('scope-group-1')
                })
            } -ParameterFilter { $ApiVersion -ne 'beta' }
            $definition = [PSCustomObject] @{
                Id = 'role-1'; DisplayName = 'Role'; IsBuiltIn = $true
                RolePermissions = @(); PermissionDataState = 'Available'
            }

            $assignment = @(Get-IntuneAccessRoleAssignments -RoleDefinition $definition -WarningAction SilentlyContinue)
            $assignment.Count | Should -Be 1
            $assignment[0].Id | Should -Be 'assignment-stable'
            $assignment[0].RawIds.AdminGroupIds | Should -Be @('admin-group-1')
            $assignment[0].RawIds.ScopeGroupIds | Should -Be @('scope-group-1')
            $assignment[0].ScopeTagDataState | Should -Be 'Missing'
            $assignment[0].PropertySource.IdentityAndMembers | Should -Be 'v1.0'
        }

        It 'hydrates assignment members and scope data from the detail endpoints' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'assignment-hydrated'; displayName = 'Hydrated assignment'
                    members = @(); resourceScopes = @()
                })
            } -ParameterFilter { $Uri -eq 'deviceManagement/roleDefinitions/role-1/roleAssignments' }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'assignment-hydrated'; displayName = 'Hydrated assignment'
                    members = @('admin-group-1'); resourceScopes = @('scope-group-1')
                })
            } -ParameterFilter {
                $Uri -eq 'deviceManagement/roleDefinitions/role-1/roleAssignments/assignment-hydrated' -and
                $ApiVersion -ne 'beta'
            }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'assignment-hydrated'; scopeType = 'resourceScope'
                    scopeMembers = @('scope-group-1'); roleScopeTagIds = @('tag-1')
                })
            } -ParameterFilter {
                $Uri -eq 'deviceManagement/roleDefinitions/role-1/roleAssignments/assignment-hydrated' -and
                $ApiVersion -eq 'beta'
            }
            $definition = [PSCustomObject] @{
                Id = 'role-1'; DisplayName = 'Role'; IsBuiltIn = $true
                RolePermissions = @(); PermissionDataState = 'Available'
            }

            $assignment = @(Get-IntuneAccessRoleAssignments -RoleDefinition $definition)

            $assignment.Count | Should -Be 1
            $assignment[0].RawIds.AdminGroupIds | Should -Be @('admin-group-1')
            $assignment[0].RawIds.ScopeGroupIds | Should -Be @('scope-group-1')
            $assignment[0].RawIds.ScopeMemberIds | Should -Be @('scope-group-1')
            $assignment[0].RawIds.ScopeTagIds | Should -Be @('tag-1')
            $assignment[0].ScopeType | Should -Be 'resourceScope'
            Should -Invoke Invoke-IntuneAccessGraphRequest -Times 2 -ParameterFilter {
                $Uri -eq 'deviceManagement/roleDefinitions/role-1/roleAssignments/assignment-hydrated'
            }
        }

        It 'finds a managed-device path through the associated user scope group' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'managed-device-1'
                    deviceName = 'PC-USER-SCOPED'
                    azureADDeviceId = '70000000-0000-0000-0000-000000000001'
                    userId = '10000000-0000-0000-0000-000000000002'
                    roleScopeTagIds = @('tag-uk')
                })
            }
            Mock Get-IntuneAccessDeviceMembership {
                [PSCustomObject] @{ State = 'Evaluated'; GroupIds = @(); Groups = @(); Explanation = 'No device groups.' }
            }
            Mock Get-IntuneAccessManagedDeviceUserMembership {
                [PSCustomObject] @{
                    State = 'Evaluated'
                    UserId = '10000000-0000-0000-0000-000000000002'
                    GroupIds = @('scope-user-group')
                    Groups = @([PSCustomObject] @{ Id = 'scope-user-group'; DisplayName = 'Scoped users' })
                }
            }
            Mock Get-IntuneAdminAccess {
                [PSCustomObject] @{
                    User = [PSCustomObject] @{ Id = 'admin-1'; UserPrincipalName = 'admin@example.test' }
                    Warnings = @()
                    RoleAssignments = @([PSCustomObject] @{
                        Id = 'assignment-1'; Name = 'User-scoped support'; Applicability = 'Confirmed'
                        RoleDefinition = [PSCustomObject] @{ DisplayName = 'Help Desk Operator' }
                        Permissions = @('Microsoft.Intune_ManagedDevices_Read')
                        AdminGroupEvidence = @([PSCustomObject] @{ GroupId = 'admin-group-1'; MembershipType = 'Direct' })
                        ScopeType = 'resourceScope'; ScopeTypeDataState = 'Available'; ScopeGroupDataState = 'Available'
                        ScopeTagDataState = 'Available'; ScopeGroups = @([PSCustomObject] @{ Id = 'scope-user-group'; DisplayName = 'Scoped users' })
                        ScopeTags = @([PSCustomObject] @{ Id = 'tag-uk'; DisplayName = 'UK' })
                        RawIds = [PSCustomObject] @{ ScopeGroupIds = @('scope-user-group'); ScopeTagIds = @('tag-uk') }
                    })
                }
            }

            $result = Test-IntuneResourceAccess -UserPrincipalName 'admin@example.test' -DeviceName 'PC-USER-SCOPED'
            $result.Result | Should -Be 'AccessPathFound'
            $result.AccessPaths[0].ScopeMatchSource | Should -Be 'AssociatedUserGroup'
            $result.AccessPaths[0].ScopeMatchGroupIds | Should -Be @('scope-user-group')
        }

        It 'finds a managed-device path through direct device group scope evidence' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'managed-device-2'; deviceName = 'PC-DEVICE-SCOPED'
                    azureADDeviceId = '70000000-0000-0000-0000-000000000002'
                    userId = $null; roleScopeTagIds = @()
                })
            }
            Mock Get-IntuneAccessDeviceMembership {
                [PSCustomObject] @{ State = 'Evaluated'; GroupIds = @('scope-device-group'); Groups = @(); Explanation = 'Device group resolved.' }
            }
            Mock Get-IntuneAccessManagedDeviceUserMembership {
                [PSCustomObject] @{ State = 'NotApplicable'; UserId = $null; GroupIds = @(); Groups = @(); Explanation = 'No associated user.' }
            }
            Mock Get-IntuneAdminAccess {
                [PSCustomObject] @{
                    User = [PSCustomObject] @{ Id = 'admin-1'; UserPrincipalName = 'admin@example.test' }; Warnings = @()
                    RoleAssignments = @([PSCustomObject] @{
                        Id = 'assignment-2'; Name = 'Device-scoped support'; Applicability = 'Confirmed'
                        RoleDefinition = [PSCustomObject] @{ DisplayName = 'Help Desk Operator' }
                        Permissions = @('Microsoft.Intune_ManagedDevices_Read'); AdminGroupEvidence = @()
                        ScopeType = 'resourceScope'; ScopeTypeDataState = 'Available'; ScopeGroupDataState = 'Available'; ScopeTagDataState = 'Available'
                        ScopeGroups = @([PSCustomObject] @{ Id = 'scope-device-group'; DisplayName = 'Scoped devices' }); ScopeTags = @()
                        RawIds = [PSCustomObject] @{ ScopeGroupIds = @('scope-device-group'); ScopeTagIds = @() }
                    })
                }
            }

            $result = Test-IntuneResourceAccess -UserPrincipalName 'admin@example.test' -DeviceName 'PC-DEVICE-SCOPED'
            $result.Result | Should -Be 'AccessPathFound'
            $result.AccessPaths[0].ScopeMatchSource | Should -Be 'DeviceGroup'
            $result.AccessPaths[0].ScopeTagState | Should -Be 'MatchedAllTags'
        }

        It 'returns NotEvaluated rather than access denied when no complete path is proved' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'managed-device-3'; deviceName = 'PC-OUTSIDE-SCOPE'
                    azureADDeviceId = '70000000-0000-0000-0000-000000000003'
                    userId = $null; roleScopeTagIds = @('tag-one')
                })
            }
            Mock Get-IntuneAccessDeviceMembership {
                [PSCustomObject] @{ State = 'Evaluated'; GroupIds = @('different-group'); Groups = @() }
            }
            Mock Get-IntuneAccessManagedDeviceUserMembership {
                [PSCustomObject] @{ State = 'NotApplicable'; UserId = $null; GroupIds = @(); Groups = @() }
            }
            Mock Get-IntuneAdminAccess {
                [PSCustomObject] @{
                    User = [PSCustomObject] @{ Id = 'admin-1'; UserPrincipalName = 'admin@example.test' }; Warnings = @()
                    RoleAssignments = @([PSCustomObject] @{
                        Id = 'assignment-3'; Name = 'Other scope'; Applicability = 'Confirmed'
                        RoleDefinition = [PSCustomObject] @{ DisplayName = 'Help Desk Operator' }
                        Permissions = @('Microsoft.Intune_ManagedDevices_Read'); AdminGroupEvidence = @()
                        ScopeType = 'resourceScope'; ScopeTypeDataState = 'Available'; ScopeGroupDataState = 'Available'; ScopeTagDataState = 'Available'
                        ScopeGroups = @(); ScopeTags = @(); RawIds = [PSCustomObject] @{ ScopeGroupIds = @('expected-group'); ScopeTagIds = @('tag-one') }
                    })
                }
            }

            $result = Test-IntuneResourceAccess -UserPrincipalName 'admin@example.test' -DeviceName 'PC-OUTSIDE-SCOPE'
            $result.Result | Should -Be 'NotEvaluated'
            $result.AccessPaths[0].ScopeGroupState | Should -Be 'NotMatched'
            $result.Reason | Should -Match 'not an access-denied decision'
        }

        It 'retains stable managed-device data when beta tag enrichment fails' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Invoke-IntuneAccessGraphRequest { throw 'Simulated device beta failure' } -ParameterFilter { $ApiVersion -eq 'beta' }
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'managed-device-stable'; deviceName = 'PC-BETA-FAILURE'
                    azureADDeviceId = '70000000-0000-0000-0000-000000000004'; userId = $null
                })
            } -ParameterFilter { $ApiVersion -ne 'beta' }
            Mock Get-IntuneAccessDeviceMembership {
                [PSCustomObject] @{ State = 'Evaluated'; GroupIds = @('scope-device-group'); Groups = @() }
            }
            Mock Get-IntuneAccessManagedDeviceUserMembership {
                [PSCustomObject] @{ State = 'NotApplicable'; UserId = $null; GroupIds = @(); Groups = @() }
            }
            Mock Get-IntuneAdminAccess {
                [PSCustomObject] @{
                    User = [PSCustomObject] @{ Id = 'admin-1'; UserPrincipalName = 'admin@example.test' }; Warnings = @()
                    RoleAssignments = @([PSCustomObject] @{
                        Id = 'assignment-4'; Name = 'Tagged support'; Applicability = 'Confirmed'
                        RoleDefinition = [PSCustomObject] @{ DisplayName = 'Help Desk Operator' }
                        Permissions = @('Microsoft.Intune_ManagedDevices_Read'); AdminGroupEvidence = @()
                        ScopeType = 'resourceScope'; ScopeTypeDataState = 'Available'; ScopeGroupDataState = 'Available'; ScopeTagDataState = 'Available'
                        ScopeGroups = @(); ScopeTags = @(); RawIds = [PSCustomObject] @{ ScopeGroupIds = @('scope-device-group'); ScopeTagIds = @('tag-required') }
                    })
                }
            }

            $result = Test-IntuneResourceAccess -UserPrincipalName 'admin@example.test' -DeviceName 'PC-BETA-FAILURE'
            $result.Resource.Id | Should -Be 'managed-device-stable'
            $result.Resource.ScopeTagDataState | Should -Be 'Missing'
            $result.Result | Should -Be 'NotEvaluated'
            $result.Warnings -join ' ' | Should -Match 'Beta scope-tag enrichment failed'
        }

        It 'returns a warning finding when the beta scope-tag collection is unavailable' {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
            Mock Get-IntuneAccessRoleDefinitions { @() }
            Mock Get-IntuneAccessRoleAssignments { @() }
            Mock Get-IntuneAccessScopeTags { throw 'Simulated scope-tag collection failure' }
            Mock Get-IntuneAccessAuditedResources { @() }

            $findings = @(Get-IntuneScopeTagAudit)
            $findings.Count | Should -Be 1
            $findings[0].Title | Should -Be 'Scope tag collection unavailable'
            $findings[0].Severity | Should -Be 'Warning'
        }
    }
}
