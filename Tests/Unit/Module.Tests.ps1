BeforeAll {
    $modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
    Import-Module $modulePath -Force
}

Describe 'IntuneAccess module' {
    It 'imports and exports only the intended public commands' {
        $commands = @(Get-Command -Module IntuneAccess).Name | Sort-Object
        $commands | Should -Be @(
            'Compare-IntuneAdminAccess'
            'Connect-IntuneAccess'
            'Export-IntuneAccessData'
            'Export-IntuneAccessReport'
            'Get-IntuneAdminAccess'
            'Get-IntuneRoleAssignment'
            'Get-IntuneScopedPermissionImpact'
            'Get-IntuneScopeTagAudit'
            'Test-IntuneResourceAccess'
        )
    }

    It 'declares no write Graph scope in source' {
        $moduleRoot = Split-Path $modulePath -Parent
        $source = Get-ChildItem $moduleRoot -Recurse -Include '*.ps1', '*.psm1' | Get-Content -Raw
        ($source -join "`n") | Should -Not -Match 'ReadWrite\.All'
    }
}
