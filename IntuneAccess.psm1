Set-StrictMode -Version Latest

$script:IntuneAccessModuleRoot = $PSScriptRoot
$script:IntuneAccessVersion = '4.0.0'

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
    'Get-IntuneScopeTagAudit'
    'Get-IntuneUser360'
    'Get-IntuneUpdateCompliance'
    'Start-IntuneAccess'
    'Test-IntuneResourceAccess'
)
