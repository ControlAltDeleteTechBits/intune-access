BeforeAll {
    $modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
    Import-Module $modulePath -Force
}

Describe 'IntuneAccess module' {
    It 'imports and exports only the intended public commands' {
        $commands = @(Get-Command -Module IntuneAccess).Name | Sort-Object
        $commands | Should -Be @(
            'Compare-IntuneAccessSnapshot'
            'Compare-IntuneAdminAccess'
            'Connect-IntuneAccess'
            'Export-IntuneAccessData'
            'Export-IntuneAccessReport'
            'Export-IntuneAccessSnapshot'
            'Get-IntuneAdminAccess'
            'Get-IntuneApplicationEvidence'
            'Get-IntuneAssignmentImpact'
            'Get-IntuneAutopilotTimeline'
            'Get-IntuneDevice360'
            'Get-IntuneDeviceAssignmentExplanation'
            'Get-IntuneDeviceEstateInsight'
            'Get-IntuneDeviceHygiene'
            'Get-IntunePolicyConflict'
            'Get-IntuneRoleAssignment'
            'Get-IntuneScopedPermissionImpact'
            'Get-IntuneScopeTagAudit'
            'Get-IntuneUpdateCompliance'
            'Get-IntuneUser360'
            'Start-IntuneAccess'
            'Test-IntuneResourceAccess'
        )
    }

    It 'declares no write Graph scope in source' {
        $moduleRoot = Split-Path $modulePath -Parent
        $source = Get-ChildItem $moduleRoot -Recurse -Include '*.ps1', '*.psm1' | Get-Content -Raw
        ($source -join "`n") | Should -Not -Match 'ReadWrite\.All'
    }

    It 'publishes the complete two-command quick start in Gallery metadata' {
        $manifest = Test-ModuleManifest -Path $modulePath
        $manifest.Description | Should -Match 'Install-Module -Name IntuneAccess'
        $manifest.Description | Should -Match 'Start-IntuneAccess'
        [string] $manifest.PrivateData.PSData.ReleaseNotes | Should -Match 'Install-Module -Name IntuneAccess'
        [string] $manifest.PrivateData.PSData.ReleaseNotes | Should -Match 'Start-IntuneAccess'
    }

    It 'provides a synopsis and example for every public command' {
        foreach ($command in @(Get-Command -Module IntuneAccess -CommandType Function)) {
            $help = Get-Help -Name $command.Name -Full
            [string] $help.Synopsis | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
        }
    }
}
