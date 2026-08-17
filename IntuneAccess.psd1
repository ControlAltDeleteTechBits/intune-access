@{
    RootModule           = 'IntuneAccess.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '9fc99074-cfcf-46db-b99b-830e5a81d0df'
    Author               = 'Mark Oldham'
    CompanyName          = 'Control Alt Delete Tech Bits'
    Copyright            = '(c) 2026 Control Alt Delete Tech Bits contributors. MIT licensed.'
    Description          = 'Read-only, evidence-led analysis of effective Microsoft Intune RBAC access.'
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
        'Export-IntuneAccessData'
        'Export-IntuneAccessReport'
        'Get-IntuneAdminAccess'
        'Get-IntuneRoleAssignment'
        'Get-IntuneScopedPermissionImpact'
        'Get-IntuneScopeTagAudit'
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
            ReleaseNotes = 'First stable release with live-validated built-in and custom role analysis, cumulative evidence, offline reporting and structured exports. Release details: https://github.com/ControlAltDeleteTechBits/intune-access/releases/tag/v1.0.0'
        }
    }
}
