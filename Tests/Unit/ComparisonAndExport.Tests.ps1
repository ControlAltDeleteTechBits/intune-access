$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Administrator comparison and data export' {
    BeforeAll {
        function New-ComparisonAccessResult {
            param(
                [string] $User,
                [string] $AssignmentId,
                [string] $GroupId
            )
            $grant = [PSCustomObject] @{ RoleAssignmentId = $AssignmentId; RoleAssignmentName = "Assignment $AssignmentId" }
            [PSCustomObject] @{
                PSTypeName = 'IntuneAccess.AdminAccess'
                User = [PSCustomObject] @{ Id = "user-$User"; UserPrincipalName = $User }
                Tenant = [PSCustomObject] @{ Id = 'tenant-1'; DisplayName = 'Example' }
                RoleAssignments = @([PSCustomObject] @{
                    Id = $AssignmentId; Name = "Assignment $AssignmentId"; Applicability = 'Confirmed'
                    RoleDefinition = [PSCustomObject] @{ Id = 'role-1'; DisplayName = 'Help Desk'; IsBuiltIn = $true }
                    RawIds = [PSCustomObject] @{ AdminGroupIds = @($GroupId); ScopeGroupIds = @('scope-1'); ScopeTagIds = @('tag-1') }
                    Permissions = @('Microsoft.Intune_ManagedDevices_Read')
                })
                EffectivePermissions = @([PSCustomObject] @{
                    RawAction = 'Microsoft.Intune_ManagedDevices_Read'; Resource = 'Managed Devices'; Operation = 'Read'
                    State = 'Allowed'; SourceCount = 1; IsDuplicate = $false; GrantedBy = @($grant)
                })
                AdminGroups = @([PSCustomObject] @{ Id = $GroupId; DisplayName = "Group $GroupId" })
                ScopeGroups = @([PSCustomObject] @{ Id = 'scope-1'; DisplayName = 'All devices' })
                ScopeTags = @([PSCustomObject] @{ Id = 'tag-1'; DisplayName = 'UK' })
                Warnings = @('Review this result')
                Evidence = @([PSCustomObject] @{
                    UserId = "user-$User"; UserPrincipalName = $User; AdminGroupId = $GroupId; AdminGroupName = "Group $GroupId"
                    MembershipType = 'Direct'; RoleAssignmentId = $AssignmentId; RoleAssignmentName = "Assignment $AssignmentId"
                    RoleDefinitionId = 'role-1'; RoleDefinitionName = 'Help Desk'; Applicability = 'Confirmed'
                })
                GeneratedAt = [DateTimeOffset]::Parse('2026-08-17T10:30:00+01:00')
                ToolVersion = '1.0.0'
            }
        }
    }

    It 'compares assignments and permission evidence' {
        $reference = New-ComparisonAccessResult -User 'senior@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $difference = New-ComparisonAccessResult -User 'helpdesk@example.test' -AssignmentId 'assignment-b' -GroupId 'group-b'

        $result = Compare-IntuneAdminAccess -ReferenceObject $reference -DifferenceObject $difference

        $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.AdminAccessComparison'
        $result.Summary.ReferenceOnly | Should -Be 2
        $result.Summary.DifferenceOnly | Should -Be 2
        $result.Summary.DifferentEvidence | Should -Be 1
        ($result.Changes | Where-Object Category -EQ 'Permission').Status | Should -Be 'DifferentEvidence'
    }

    It 'can retain unchanged comparison records' {
        $reference = New-ComparisonAccessResult -User 'senior@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $difference = New-ComparisonAccessResult -User 'helpdesk@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'

        $result = Compare-IntuneAdminAccess -ReferenceObject $reference -DifferenceObject $difference -IncludeUnchanged

        $result.Summary.TotalChanges | Should -Be 0
        $result.Summary.Unchanged | Should -Be 5
        $result.Changes.Status | Should -Not -Contain 'ReferenceOnly'
    }

    It 'rejects comparison objects that are not administrator results' {
        $valid = New-ComparisonAccessResult -User 'admin@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $invalid = [PSCustomObject] @{ Value = 'not access evidence' }

        { Compare-IntuneAdminAccess -ReferenceObject $valid -DifferenceObject $invalid } |
            Should -Throw '*must be results returned by Get-IntuneAdminAccess*'
    }

    It 'exports a complete JSON evidence envelope' {
        $access = New-ComparisonAccessResult -User 'admin@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $path = Join-Path $TestDrive 'snapshot.json'

        $file = $access | Export-IntuneAccessData -Path $path -Format Json
        $json = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 30

        $json.SchemaVersion | Should -Be '2.0'
        $json.DataType | Should -Be 'IntuneAccess.AdminAccess'
        $json.Data.User.UserPrincipalName | Should -Be 'admin@example.test'
    }

    It 'requires Force before replacing a JSON export' {
        $access = New-ComparisonAccessResult -User 'admin@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $path = Join-Path $TestDrive 'existing.json'
        $null = $access | Export-IntuneAccessData -Path $path -Format Json

        { $access | Export-IntuneAccessData -Path $path -Format Json } | Should -Throw '*Use -Force*'
        { $access | Export-IntuneAccessData -Path $path -Format Json -Force } | Should -Not -Throw
    }

    It 'rejects invalid JSON paths and unrelated objects' {
        $access = New-ComparisonAccessResult -User 'admin@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'

        { $access | Export-IntuneAccessData -Path (Join-Path $TestDrive 'snapshot.txt') -Format Json } |
            Should -Throw '*.json file extension*'
        { [PSCustomObject] @{ Value = 'not evidence' } | Export-IntuneAccessData -Path (Join-Path $TestDrive 'other.json') -Format Json } |
            Should -Throw '*must be an IntuneAccess*'
    }

    It 'exports the administrator CSV datasets' {
        $access = New-ComparisonAccessResult -User 'admin@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $path = Join-Path $TestDrive 'csv'

        $files = @($access | Export-IntuneAccessData -Path $path -Format Csv)

        $files.Count | Should -Be 8
        Test-Path -LiteralPath (Join-Path $path 'summary.csv') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $path 'effective-permissions.csv') | Should -BeTrue
        (Import-Csv -LiteralPath (Join-Path $path 'role-assignments.csv')).RoleDefinitionName | Should -Be 'Help Desk'
    }

    It 'requires Force before replacing populated CSV output' {
        $access = New-ComparisonAccessResult -User 'admin@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $path = Join-Path $TestDrive 'existing-csv'
        $null = $access | Export-IntuneAccessData -Path $path -Format Csv

        { $access | Export-IntuneAccessData -Path $path -Format Csv } | Should -Throw '*Use -Force*'
        { $access | Export-IntuneAccessData -Path $path -Format Csv -Force } | Should -Not -Throw
    }

    It 'writes header-only CSV datasets for an empty access result' {
        $access = New-ComparisonAccessResult -User 'empty@example.test' -AssignmentId 'assignment-a' -GroupId 'group-a'
        $access.RoleAssignments = @()
        $access.EffectivePermissions = @()
        $access.AdminGroups = @()
        $access.ScopeGroups = @()
        $access.ScopeTags = @()
        $access.Warnings = @()
        $access.Evidence = @()
        $path = Join-Path $TestDrive 'empty-csv'

        $files = @($access | Export-IntuneAccessData -Path $path -Format Csv)

        $files.Count | Should -Be 8
        (Get-Content -LiteralPath (Join-Path $path 'role-assignments.csv')).Count | Should -Be 1
        Get-Content -LiteralPath (Join-Path $path 'role-assignments.csv') | Should -Match 'RoleDefinitionName'
    }
}
