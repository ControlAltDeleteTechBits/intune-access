Set-StrictMode -Version Latest

$script:IntuneAccessModuleRoot = $PSScriptRoot
$script:IntuneAccessVersion = '1.0.0'

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
    'Export-IntuneAccessData'
    'Export-IntuneAccessReport'
    'Get-IntuneAdminAccess'
    'Get-IntuneRoleAssignment'
    'Get-IntuneScopedPermissionImpact'
    'Get-IntuneScopeTagAudit'
    'Test-IntuneResourceAccess'
)
