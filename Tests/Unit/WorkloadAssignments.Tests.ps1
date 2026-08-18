$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Intune workload assignment evidence' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Assert-IntuneAccessConnection {
                [PSCustomObject] @{
                    Scopes = @(
                        'GroupMember.Read.All'
                        'DeviceManagementConfiguration.Read.All'
                        'DeviceManagementApps.Read.All'
                        'DeviceManagementScripts.Read.All'
                    )
                }
            }
            Mock Resolve-IntuneAccessGroups {
                @($GroupId | ForEach-Object {
                    [PSCustomObject] @{ Id = $_; DisplayName = "Group $_"; Description = ''; ResolutionState = 'Resolved' }
                })
            }
        }

        It 'normalises supported workloads, targets, filters and beta provenance' {
            Mock Invoke-IntuneAccessGraphRequest {
                switch -Regex ($Uri) {
                    '^deviceManagement/deviceConfigurations$' {
                        return @([PSCustomObject] @{ id = 'config-1'; displayName = 'Update ring'; '@odata.type' = '#microsoft.graph.windowsUpdateForBusinessConfiguration'; roleScopeTagIds = @('tag-1') })
                    }
                    '^deviceManagement/deviceConfigurations/config-1/assignments$' {
                        return @([PSCustomObject] @{ id = 'assignment-1'; target = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = 'group-1'; deviceAndAppManagementAssignmentFilterId = 'filter-1'; deviceAndAppManagementAssignmentFilterType = 'include' } })
                    }
                    '^deviceManagement/deviceCompliancePolicies$' {
                        return @([PSCustomObject] @{ id = 'compliance-1'; displayName = 'Windows compliance' })
                    }
                    '^deviceManagement/deviceCompliancePolicies/compliance-1/assignments$' {
                        return @([PSCustomObject] @{ id = 'assignment-2'; target = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' } })
                    }
                    '^deviceAppManagement/mobileApps$' {
                        return @([PSCustomObject] @{ id = 'app-1'; displayName = 'Company Portal helper'; '@odata.type' = '#microsoft.graph.win32LobApp' })
                    }
                    '^deviceAppManagement/mobileApps/app-1/assignments$' {
                        return @([PSCustomObject] @{ id = 'assignment-3'; intent = 'uninstall'; target = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'; groupId = 'group-2' } })
                    }
                    '^deviceManagement/configurationPolicies$' {
                        return @([PSCustomObject] @{ id = 'settings-1'; name = 'Microsoft Defender Firewall'; technologies = 'mdm,microsoftSense'; templateReference = [PSCustomObject] @{ templateFamily = 'endpointSecurityFirewall' } })
                    }
                    '^deviceManagement/configurationPolicies/settings-1/assignments$' {
                        return @([PSCustomObject] @{ id = 'assignment-4'; target = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' } })
                    }
                    '^deviceManagement/assignmentFilters$' {
                        return @([PSCustomObject] @{ id = 'filter-1'; displayName = 'Corporate Windows'; platform = 'windows10AndLater'; rule = '(device.deviceOwnership -eq "Corporate")' })
                    }
                    default { return @() }
                }
            }

            $result = Get-IntuneAssignmentImpact

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.WorkloadInventory'
            $result.Workloads.Count | Should -Be 4
            $result.Assignments.Count | Should -Be 4
            $result.Workloads.WorkloadType | Should -Contain 'Updates'
            $result.Workloads.WorkloadType | Should -Contain 'Compliance'
            $result.Workloads.WorkloadType | Should -Contain 'Applications'
            $result.Workloads.WorkloadType | Should -Contain 'Endpoint security'
            ($result.Assignments | Where-Object Id -EQ 'assignment-1').Group.DisplayName | Should -Be 'Group group-1'
            ($result.Assignments | Where-Object Id -EQ 'assignment-1').Filter.DisplayName | Should -Be 'Corporate Windows'
            ($result.Assignments | Where-Object Id -EQ 'assignment-3').EvidenceState | Should -Be 'ExcludedTarget'
            ($result.Workloads | Where-Object Id -EQ 'settings-1').SourceApiVersion | Should -Be 'beta'
            @($result.CollectionStatus | Where-Object State -EQ 'Available').Count | Should -Be 10
        }

        It 'retains partial evidence when one source is unavailable' {
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -eq 'deviceAppManagement/mobileApps') { throw 'Simulated apps failure' }
                return @()
            }

            $result = Get-IntuneAssignmentImpact

            ($result.CollectionStatus | Where-Object Source -EQ 'Applications').State | Should -Be 'Unavailable'
            $result.Warnings -join ' ' | Should -Match 'Applications could not be collected'
            @($result.Workloads).Count | Should -Be 0
        }

        It 'labels an unknown target as not evaluated' {
            $result = ConvertTo-IntuneAccessWorkloadAssignment -Assignment ([PSCustomObject] @{
                id = 'assignment-unknown'
                target = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.futureAssignmentTarget' }
            }) -WorkloadId 'item-1' -WorkloadName 'Future item' -WorkloadType 'Configuration' -ApiVersion beta

            $result.TargetType | Should -Be 'Unknown target'
            $result.EvidenceState | Should -Be 'NotEvaluated'
            $result.RawTargetType | Should -Match 'futureAssignmentTarget'
        }

        It 'does not call beta endpoints when beta collection is disabled' {
            Mock Invoke-IntuneAccessGraphRequest { return @() }

            $result = Get-IntuneAssignmentImpact -ExcludeBeta

            @($result.CollectionStatus | Where-Object ApiVersion -EQ 'beta' | Where-Object State -EQ 'Skipped').Count | Should -Be 7
            Should -Invoke Invoke-IntuneAccessGraphRequest -ParameterFilter { $ApiVersion -eq 'beta' } -Times 0 -Exactly
        }

        It 'renders workload relationships as navigable, encoded evidence' {
            $group = [PSCustomObject] @{ Id = 'group-1'; DisplayName = 'Corporate <Devices>'; Description = 'Managed estate'; ResolutionState = 'Resolved' }
            $filter = [PSCustomObject] @{ Id = 'filter-1'; DisplayName = 'Windows & Corporate'; Description = ''; Platform = 'windows10AndLater'; Rule = '(device.deviceOwnership -eq "Corporate")'; SourceApiVersion = 'beta' }
            $assignment = [PSCustomObject] @{
                Id = 'assignment-1'; WorkloadId = 'policy-1'; WorkloadName = 'Secure Browser'; WorkloadType = 'Applications'; Intent = 'required'; TargetType = 'Included group'
                RawTargetType = '#microsoft.graph.groupAssignmentTarget'; GroupId = 'group-1'; Group = $group; CollectionId = ''; FilterId = 'filter-1'; FilterMode = 'include'; Filter = $filter
                EvidenceState = 'ConfirmedAssignment'; SourceApiVersion = 'v1.0'
            }
            $workload = [PSCustomObject] @{
                Id = 'policy-1'; Name = 'Secure Browser'; Description = 'Required browser'; WorkloadType = 'Applications'; ScopeTagIds = @('tag-1')
                AssignmentDataState = 'Available'; SourceApiVersion = 'v1.0'
            }
            $model = [PSCustomObject] @{
                PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }
                Administrators = @(); AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
                WorkloadObjects = @($workload); WorkloadAssignments = @($assignment); WorkloadGroups = @($group); AssignmentFilters = @($filter)
                WorkloadCollectionStatus = @([PSCustomObject] @{ Source = 'Applications'; State = 'Available'; ApiVersion = 'v1.0'; ItemCount = 1; Reason = '' })
                Warnings = @(); GraphPermissionsUsed = @('DeviceManagementApps.Read.All'); GeneratedAt = [DateTimeOffset]::Parse('2026-08-18T12:00:00+01:00'); ToolVersion = '1.3.0'
            }

            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $model

            $html | Should -Match 'data-view="workloads"'
            $html | Should -Match 'data-view="workload-assignments"'
            $html | Should -Match 'data-view="target-groups"'
            $html | Should -Match 'data-view="assignment-filters"'
            $html | Should -Match 'data-object-panel="workload-1"'
            $html | Should -Match 'data-object-panel="workload-assignment-1"'
            $html | Should -Match 'Corporate &lt;Devices&gt;'
            $html | Should -Match 'Windows &amp; Corporate'
            $html | Should -Match 'Confirmed assignment'
        }
    }
}
