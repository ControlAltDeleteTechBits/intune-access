Set-StrictMode -Version Latest

$script:IntuneAccessModuleRoot = $PSScriptRoot
# The manifest is the single source of the module version.
$script:IntuneAccessVersion = [string] (Import-PowerShellDataFile -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'IntuneAccess.psd1')).ModuleVersion

foreach ($folder in @('Private', 'Public')) {
    $functions = Get-ChildItem -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath $folder) -Filter '*.ps1' -File |
        Sort-Object -Property Name

    foreach ($function in $functions) {
        . $function.FullName
    }
}

Export-ModuleMember -Function @(
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
