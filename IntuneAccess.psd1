@{
    RootModule           = 'IntuneAccess.psm1'
    ModuleVersion        = '4.0.0'
    GUID                 = '9fc99074-cfcf-46db-b99b-830e5a81d0df'
    Author               = 'Mark Oldham'
    CompanyName          = 'Control Alt Delete Tech Bits'
    Copyright            = '(c) 2026 Control Alt Delete Tech Bits contributors. MIT licensed.'
    Description          = 'Read-only Microsoft Intune evidence explorer. Quick start: Install-Module -Name IntuneAccess -Scope CurrentUser; Start-IntuneAccess'
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
            Tags         = @('Intune', 'RBAC', 'MicrosoftGraph', 'Security', 'ReadOnly', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/ControlAltDeleteTechBits/intune-access'
            LicenseUri   = 'https://github.com/ControlAltDeleteTechBits/intune-access/blob/main/LICENSE'
            IconUri      = 'https://raw.githubusercontent.com/ControlAltDeleteTechBits/intune-access/main/Assets/IntuneAccess-Gallery-Icon.svg'
            ReleaseNotes = 'IntuneAccess 4.0.0: findings resolution guides, local expected decisions, selected change plans, export-only reviewed script packages, remediation effectiveness and conservative snapshot verification. No tenant changes or script execution. Default read-scope collection and owner HTML acceptance verified; controlled endpoint incident validation remains unverified. See RELEASE_NOTES.md for limits. Quick start: Install-Module -Name IntuneAccess -Scope CurrentUser; Start-IntuneAccess.'
        }
    }
}
