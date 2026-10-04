function Get-IntunePrivilegeUsage {
    <#
    .SYNOPSIS
    Compares administrators' Intune write permissions with the changes they actually made.
    .DESCRIPTION
    For each administrator and permission family (for example Device Configurations or Mobile Apps),
    shows whether the Intune audit log contains changes they made in the collected window. Families with
    no audited activity are review prompts for least privilege. Read permissions are never reported as
    unused because Intune does not audit reads. Families without a direct audit mapping stay NotEvaluated.
    .PARAMETER UserPrincipalName
    Limit results to one administrator.
    .PARAMETER SnapshotPath
    Use a local IntuneAccess snapshot instead of a live collection.
    .EXAMPLE
    (Get-IntunePrivilegeUsage).Rows | Where-Object State -EQ 'NoObservedActivity'
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()] [string] $UserPrincipalName,
        [ValidateNotNullOrEmpty()] [string] $SnapshotPath
    )

    $collection = Get-IntuneAccessInsightCollection -SnapshotPath $SnapshotPath -IncludeAuditEvidence
    $review = Get-IntuneAccessPrivilegeUsage -Collection $collection
    if ($PSBoundParameters.ContainsKey('UserPrincipalName')) {
        $review.Rows = @($review.Rows | Where-Object UserPrincipalName -EQ $UserPrincipalName)
        $review.NoObservedActivity = @($review.Rows | Where-Object State -EQ 'NoObservedActivity').Count
    }
    $review
}
