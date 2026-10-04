@{
    RootModule           = 'IntuneAccess.psm1'
    ModuleVersion        = '5.0.0'
    GUID                 = '9fc99074-cfcf-46db-b99b-830e5a81d0df'
    Author               = 'Mark Oldham'
    CompanyName          = 'Control Alt Delete Tech Bits'
    Copyright            = '(c) 2026 Control Alt Delete Tech Bits contributors. MIT licensed.'
    Description          = 'Read-only Microsoft Intune evidence explorer: why a policy or app did not apply, what changed, what a group change will affect, who can do what, and Scoped permissions readiness. Quick start: Install-Module -Name IntuneAccess -Scope CurrentUser; Start-IntuneAccess'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules      = @(
        @{
            ModuleName    = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.0.0'
            GUID          = '883916f2-9184-46ee-b1f8-b6a2fb784cee'
        }
    )
    FunctionsToExport    = @(
        'Connect-IntuneAccess'
        'Compare-IntuneAdminAccess'
        'Compare-IntuneAccessSnapshot'
        'Export-IntuneAccessData'
        'Export-IntuneAccessReport'
        'Export-IntuneAccessSnapshot'
        'Get-IntuneAdminAccess'
        'Get-IntuneAssignmentImpact'
        'Get-IntuneApplicationEvidence'
        'Get-IntuneAutopilotTimeline'
        'Get-IntuneDevice360'
        'Get-IntuneDeviceAssignmentExplanation'
        'Get-IntuneDeviceEstateInsight'
        'Get-IntuneDeviceHygiene'
        'Get-IntunePolicyConflict'
        'Get-IntuneRoleAssignment'
        'Get-IntuneScopedPermissionImpact'
        'Get-IntuneChangePreview'
        'Get-IntuneChangeTimeline'
        'Get-IntuneDeliveryChain'
        'Get-IntunePrivilegeUsage'
        'Get-IntuneScopedPermissionReadiness'
        'Get-IntuneScopeTagAudit'
        'Get-IntuneUser360'
        'Get-IntuneUpdateCompliance'
        'Start-IntuneAccess'
        'Test-IntuneResourceAccess'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    FormatsToProcess     = @('IntuneAccess.Format.ps1xml')
    PrivateData          = @{
        PSData = @{
            Tags         = @('Intune', 'RBAC', 'MicrosoftGraph', 'Security', 'ReadOnly', 'Troubleshooting', 'Audit', 'LeastPrivilege', 'ScopeTags', 'EntraID', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/ControlAltDeleteTechBits/intune-access'
            LicenseUri   = 'https://github.com/ControlAltDeleteTechBits/intune-access/blob/main/LICENSE'
            IconUri      = 'https://raw.githubusercontent.com/ControlAltDeleteTechBits/intune-access/main/Assets/IntuneAccess-Gallery-Icon.svg'
            ReleaseNotes = 'IntuneAccess 5.0.0: why did a policy or app not apply (evidence chain with next check), what changed (audit, configuration and result timeline with failure correlation), change preview for groups, filters and scope tags, least-privilege review from Intune audit activity, and Scoped permissions readiness reconciled with the Permissions Assessment Report. Report opens on a triage page. Read only; no new Graph permissions. See RELEASE_NOTES.md. Quick start: Install-Module -Name IntuneAccess -Scope CurrentUser; Start-IntuneAccess.'
        }
    }
}
