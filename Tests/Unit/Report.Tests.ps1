$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'HTML report safety' {
    InModuleScope IntuneAccess {
        It 'encodes tenant supplied values and has no remote runtime dependency' {
            $access = [PSCustomObject] @{
                User = [PSCustomObject] @{ UserPrincipalName = 'admin<script>alert(1)</script>@example.test' }
                Tenant = [PSCustomObject] @{ DisplayName = 'Example & Sons' }
                RoleAssignments = @()
                EffectivePermissions = @()
                ScopeGroups = @()
                ScopeTags = @()
                Warnings = @()
                GraphPermissionsUsed = @('DeviceManagementRBAC.Read.All')
                GeneratedAt = [DateTimeOffset]::Parse('2026-08-17T10:30:00+01:00')
                ToolVersion = '1.0.0'
            }
            $html = ConvertTo-IntuneAccessHtml -Access $access
            $html | Should -Not -Match '<script>'
            $html | Should -Match '&lt;script&gt;'
            $html | Should -Match 'Example &amp; Sons'
            $html | Should -Not -Match '<script\s+src='
            $html | Should -Not -Match '<link\s+[^>]*href='
            $html | Should -Not -Match 'https?://'
        }
    }

    It 'provides a useful default console summary without changing the data object' {
        $access = [PSCustomObject] @{
            PSTypeName = 'IntuneAccess.AdminAccess'
            User = [PSCustomObject] @{ UserPrincipalName = 'admin@example.test' }
            Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }
            RoleAssignments = @(1, 2)
            EffectivePermissions = @(1, 2, 3)
            Warnings = @('Review')
        }
        $rendered = $access | Out-String -Width 120
        $rendered | Should -Match 'INTUNE EFFECTIVE ACCESS'
        $rendered | Should -Match 'admin@example\.test'
        $access.RoleAssignments.Count | Should -Be 2
    }
}
