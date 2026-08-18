$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Policy setting overlap and conflict analysis' {
    InModuleScope IntuneAccess {
        BeforeEach {
            $script:policies = @(
                [PSCustomObject] @{ Id = 'policy-1'; Name = 'Firewall baseline'; Description = ''; WorkloadType = 'Endpoint security'; ScopeTagIds = @(); AssignmentDataState = 'Available'; SourceEndpoint = 'deviceManagement/configurationPolicies'; SourceApiVersion = 'beta'; Assignments = @() }
                [PSCustomObject] @{ Id = 'policy-2'; Name = 'Firewall exception'; Description = ''; WorkloadType = 'Configuration'; ScopeTagIds = @(); AssignmentDataState = 'Available'; SourceEndpoint = 'deviceManagement/configurationPolicies'; SourceApiVersion = 'beta'; Assignments = @() }
            )
            $script:assignments = @(
                [PSCustomObject] @{ Id = 'assignment-1'; WorkloadId = 'policy-1'; TargetType = 'All devices'; GroupId = ''; FilterId = ''; FilterMode = 'none'; EvidenceState = 'ConfirmedAssignment' }
                [PSCustomObject] @{ Id = 'assignment-2'; WorkloadId = 'policy-2'; TargetType = 'All devices'; GroupId = ''; FilterId = ''; FilterMode = 'none'; EvidenceState = 'ConfirmedAssignment' }
            )
        }

        It 'reports a potential conflict only for different values with confirmed target overlap' {
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -like '*policy-1/settings') {
                    return @([PSCustomObject] @{ settingInstance = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'; settingDefinitionId = 'vendor_firewall_enable'; choiceSettingValue = [PSCustomObject] @{ value = 'enabled'; children = @() } } })
                }
                return @([PSCustomObject] @{ settingInstance = [PSCustomObject] @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'; settingDefinitionId = 'vendor_firewall_enable'; choiceSettingValue = [PSCustomObject] @{ value = 'disabled'; children = @() } } })
            }

            $result = Get-IntunePolicyConflict -Workload $script:policies -Assignment $script:assignments

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.PolicyConflictAnalysis'
            $result.PolicySettings.Count | Should -Be 2
            $result.PotentialConflictCount | Should -Be 1
            $result.Findings[0].FindingState | Should -Be 'PotentialConflict'
            $result.Findings[0].TargetOverlapState | Should -Be 'ConfirmedOverlap'
            $result.Findings[0].EvidenceState | Should -Be 'CalculatedFromObservedSettingsAndAssignments'
        }

        It 'keeps different group targets as not evaluated' {
            $script:assignments[0].TargetType = 'Included group'
            $script:assignments[0].GroupId = 'group-1'
            $script:assignments[1].TargetType = 'Included group'
            $script:assignments[1].GroupId = 'group-2'
            Mock Get-IntuneAccessPolicySettings {
                [PSCustomObject] @{
                    Settings = @(
                        [PSCustomObject] @{ WorkloadId = 'policy-1'; WorkloadName = 'Firewall baseline'; SettingDefinitionId = 'setting-1'; ValueJson = '["enabled"]' }
                        [PSCustomObject] @{ WorkloadId = 'policy-2'; WorkloadName = 'Firewall exception'; SettingDefinitionId = 'setting-1'; ValueJson = '["disabled"]' }
                    )
                    CollectionStatus = @(); Warnings = @()
                }
            }

            $result = Get-IntunePolicyConflict -Workload $script:policies -Assignment $script:assignments

            $result.PotentialConflictCount | Should -Be 0
            $result.UnevaluatedCount | Should -Be 1
            $result.Findings[0].TargetOverlapState | Should -Be 'NotEvaluated'
        }

        It 'normalises nested Settings Catalog and legacy profile values' {
            $nested = [PSCustomObject] @{
                settingDefinitionId = 'parent'; choiceSettingValue = [PSCustomObject] @{
                    value = 'enabled'; children = @([PSCustomObject] @{ settingDefinitionId = 'child'; simpleSettingValue = [PSCustomObject] @{ value = 30 } })
                }
            }
            $leaves = @(ConvertTo-IntuneAccessPolicySettingLeaf -SettingInstance $nested -Workload $script:policies[0])
            $legacy = @(ConvertTo-IntuneAccessLegacyPolicySettings -Policy ([PSCustomObject] @{ id = 'legacy-1'; displayName = 'Legacy'; '@odata.type' = '#microsoft.graph.windows10GeneralConfiguration'; passwordMinimumLength = 12 }) -Workload ([PSCustomObject] @{ Id = 'legacy-1'; Name = 'Legacy'; WorkloadType = 'Configuration'; SourceApiVersion = 'v1.0' }))

            $leaves.SettingDefinitionId | Should -Contain 'parent'
            $leaves.SettingDefinitionId | Should -Contain 'child'
            ($leaves | Where-Object SettingDefinitionId -EQ 'child').ValueJson | Should -Be '30'
            $legacy.SettingDefinitionId | Should -Contain 'legacy::passwordMinimumLength'
            $legacy.SettingDefinitionId | Should -Not -Contain 'legacy::displayName'
        }

        It 'isolates a policy settings endpoint failure' {
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -like '*policy-1/settings') { throw 'Simulated settings failure' }
                return @()
            }

            $result = Get-IntuneAccessPolicySettings -Workload $script:policies

            ($result.CollectionStatus | Where-Object WorkloadId -EQ 'policy-1').State | Should -Be 'Unavailable'
            ($result.CollectionStatus | Where-Object WorkloadId -EQ 'policy-2').State | Should -Be 'Available'
            $result.Warnings -join ' ' | Should -Match 'Simulated settings failure'
        }

        It 'renders policy settings and potential conflicts as linked explorer evidence' {
            $setting = [PSCustomObject] @{ Id = 'policy-1::setting-1'; WorkloadId = 'policy-1'; WorkloadName = 'Firewall baseline'; WorkloadType = 'Endpoint security'; SettingDefinitionId = 'setting-1'; ValueJson = '["enabled"]'; ValueCount = 1; SourceApiVersion = 'beta'; EvidenceState = 'ObservedSettingValue' }
            $finding = [PSCustomObject] @{ Id = 'setting-1::policy-1::policy-2'; SettingDefinitionId = 'setting-1'; FirstPolicyId = 'policy-1'; FirstPolicyName = 'Firewall baseline'; FirstValueJson = '["enabled"]'; SecondPolicyId = 'policy-2'; SecondPolicyName = 'Firewall exception'; SecondValueJson = '["disabled"]'; ValuesDiffer = $true; TargetOverlapState = 'ConfirmedOverlap'; TargetEvidence = @(1); FindingState = 'PotentialConflict'; Reason = 'Exact all-device target.' }
            $model = [PSCustomObject] @{
                PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }
                Administrators = @(); AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
                WorkloadObjects = $script:policies; WorkloadAssignments = @(); WorkloadGroups = @(); AssignmentFilters = @(); WorkloadCollectionStatus = @()
                ManagedDevices = @(); ManagedUsers = @(); DeploymentOutcomes = @(); OutcomeCollectionStatus = @()
                PolicySettings = @($setting); PolicyConflictFindings = @($finding); PolicyConflictCollectionStatus = @([PSCustomObject] @{ WorkloadName = 'Firewall baseline'; State = 'Available'; SettingCount = 1; Reason = '' })
                Warnings = @(); GraphPermissionsUsed = @(); GeneratedAt = [DateTimeOffset]::Now; ToolVersion = '2.0.0'
            }

            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $model

            $html | Should -Match 'data-view="policy-conflicts"'
            $html | Should -Match 'data-view="policy-settings"'
            $html | Should -Match 'data-object-panel="policy-conflict-1"'
            $html | Should -Match 'PotentialConflict'
            $html | Should -Match 'does not claim the final value enforced on a device'
        }
    }
}
