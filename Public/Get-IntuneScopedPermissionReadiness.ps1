function Get-IntuneScopedPermissionReadiness {
    <#
    .SYNOPSIS
    Shows which Admin Groups lose Intune permissions when Scoped permissions is enabled.
    .DESCRIPTION
    Microsoft's opt-in Scoped permissions setting stops Intune merging permissions across role
    assignments with different scope tags. Microsoft states the change cannot be reversed.
    This command models the change for every Admin Group in the same shape as Microsoft's
    Permissions Assessment Report, and reconciles the model with an exported report when supplied.
    It never reads or changes the tenant setting. Read only.
    .PARAMETER AssessmentReportPath
    Optional .csv or .xlsx export from Tenant administration > Roles > Settings > Generate Report > Export.
    .PARAMETER SnapshotPath
    Use a local IntuneAccess snapshot instead of a live collection.
    .EXAMPLE
    Get-IntuneScopedPermissionReadiness
    .EXAMPLE
    (Get-IntuneScopedPermissionReadiness -AssessmentReportPath .\PermissionsAssessment.xlsx).Rows |
        Format-Table Group, ScopeTag, Resource, LostPermissions, ReconciliationState
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()] [string] $AssessmentReportPath,
        [ValidateNotNullOrEmpty()] [string] $SnapshotPath
    )

    $assessment = if ($PSBoundParameters.ContainsKey('AssessmentReportPath')) { Import-IntuneAccessPermissionAssessment -Path $AssessmentReportPath } else { $null }
    $collection = Get-IntuneAccessInsightCollection -SnapshotPath $SnapshotPath
    $result = Get-IntuneAccessScopedReadiness -Collection $collection -Assessment $assessment
    if ($null -ne $assessment -and @($assessment.Warnings).Count) { foreach ($warning in $assessment.Warnings) { Write-Warning $warning } }
    $result
}
