$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Scoped permissions impact analysis' {
    InModuleScope IntuneAccess {
        BeforeAll {
            function New-ScopedTestAssignment {
                param(
                    [string] $Id,
                    [string] $TagId,
                    [string] $TagName,
                    [string[]] $Action,
                    [string] $Applicability = 'Confirmed',
                    [string] $ScopeTagDataState = 'Available'
                )
                [PSCustomObject] @{
                    Id = $Id
                    Name = "Assignment $Id"
                    Applicability = $Applicability
                    Permissions = $Action
                    ScopeTagDataState = $ScopeTagDataState
                    ScopeTags = if ($TagId) { @([PSCustomObject] @{ Id = $TagId; DisplayName = $TagName }) } else { @() }
                    RawIds = [PSCustomObject] @{ ScopeTagIds = if ($TagId) { @($TagId) } else { @() } }
                }
            }

            function New-ScopedAccessResult {
                param([object[]] $Assignment)
                [PSCustomObject] @{
                    PSTypeName = 'IntuneAccess.AdminAccess'
                    User = [PSCustomObject] @{ Id = 'user-1'; UserPrincipalName = 'admin@example.test' }
                    Tenant = [PSCustomObject] @{ Id = 'tenant-1'; DisplayName = 'Example' }
                    RoleAssignments = $Assignment
                }
            }
        }

        It 'shows permission reductions when legacy merging crosses scope tags' {
            $access = New-ScopedAccessResult -Assignment @(
                (New-ScopedTestAssignment -Id 'uk' -TagId 'tag-uk' -TagName 'UK' -Action 'Microsoft.Intune_ManagedDevices_Read')
                (New-ScopedTestAssignment -Id 'eu' -TagId 'tag-eu' -TagName 'Europe' -Action 'Microsoft.Intune_ManagedDevices_Wipe')
            )

            $result = Get-IntuneScopedPermissionImpact -InputObject $access

            $result.TenantMode | Should -Be 'Unknown'
            $result.Summary.Reductions | Should -Be 2
            $result.Summary.PermissionContexts | Should -Be 4
            $result.Rows.EffectiveState | Should -Not -Contain 'Allowed'
            ($result.Rows | Where-Object { $_.ScopeTagId -eq 'tag-uk' -and $_.Operation -eq 'Wipe' }).Change | Should -Be 'PermissionReduction'
        }

        It 'selects the Scoped outcome only when requested explicitly' {
            $access = New-ScopedAccessResult -Assignment @(
                (New-ScopedTestAssignment -Id 'uk' -TagId 'tag-uk' -TagName 'UK' -Action 'Microsoft.Intune_ManagedDevices_Read')
                (New-ScopedTestAssignment -Id 'eu' -TagId 'tag-eu' -TagName 'Europe' -Action 'Microsoft.Intune_ManagedDevices_Wipe')
            )

            $result = Get-IntuneScopedPermissionImpact -InputObject $access -TenantMode Scoped
            $row = $result.Rows | Where-Object { $_.ScopeTagId -eq 'tag-uk' -and $_.Operation -eq 'Wipe' }

            $row.LegacyState | Should -Be 'Allowed'
            $row.ScopedState | Should -Be 'NotGranted'
            $row.EffectiveState | Should -Be 'NotGranted'
        }

        It 'selects the legacy outcome only when requested explicitly' {
            $access = New-ScopedAccessResult -Assignment @(
                (New-ScopedTestAssignment -Id 'uk' -TagId 'tag-uk' -TagName 'UK' -Action 'Microsoft.Intune_ManagedDevices_Read')
                (New-ScopedTestAssignment -Id 'eu' -TagId 'tag-eu' -TagName 'Europe' -Action 'Microsoft.Intune_ManagedDevices_Wipe')
            )

            $result = Get-IntuneScopedPermissionImpact -InputObject $access -TenantMode LegacyMerged
            $row = $result.Rows | Where-Object { $_.ScopeTagId -eq 'tag-uk' -and $_.Operation -eq 'Wipe' }

            $row.LegacyState | Should -Be 'Allowed'
            $row.EffectiveState | Should -Be 'Allowed'
            $result.Warnings | Should -Not -Match 'active tenant mode was not supplied'
        }

        It 'keeps missing scope-tag evidence as NotEvaluated' {
            $access = New-ScopedAccessResult -Assignment @(
                (New-ScopedTestAssignment -Id 'unknown' -TagId $null -TagName '' -Action 'Microsoft.Intune_ManagedDevices_Read' -ScopeTagDataState Missing)
            )

            $result = Get-IntuneScopedPermissionImpact -InputObject $access -TenantMode Scoped

            $result.Rows[0].ScopeTagId | Should -Be '?'
            $result.Rows[0].EffectiveState | Should -Be 'NotEvaluated'
            $result.Warnings -join ' ' | Should -Match 'incomplete'
        }

        It 'applies an untagged assignment to every observed tag in the Scoped model' {
            $access = New-ScopedAccessResult -Assignment @(
                (New-ScopedTestAssignment -Id 'all' -TagId $null -TagName '' -Action 'Microsoft.Intune_ManagedDevices_Read')
                (New-ScopedTestAssignment -Id 'uk' -TagId 'tag-uk' -TagName 'UK' -Action 'Microsoft.Intune_ManagedDevices_Wipe')
            )

            $result = Get-IntuneScopedPermissionImpact -InputObject $access -TenantMode Scoped
            $row = $result.Rows | Where-Object { $_.ScopeTagId -eq 'tag-uk' -and $_.Operation -eq 'Read' }

            $row.ScopedState | Should -Be 'Allowed'
        }

        It 'rejects an unrelated input object' {
            { Get-IntuneScopedPermissionImpact -InputObject ([PSCustomObject] @{ Value = 'not access evidence' }) } |
                Should -Throw '*must be a result returned by Get-IntuneAdminAccess*'
        }
    }
}
