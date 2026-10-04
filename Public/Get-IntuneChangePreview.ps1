function Get-IntuneChangePreview {
    <#
    .SYNOPSIS
    Shows what depends on an Entra group, assignment filter or scope tag before you change or delete it.
    .DESCRIPTION
    Lists the policies, apps, scripts, updates and Intune role assignments that reference the object,
    and flags risks such as unreadable (possibly deleted) groups, groups used for both inclusion and
    exclusion, groups that control both administration and targeting, and scope tags no role
    assignment grants. Uses collected evidence only. Read only.
    .PARAMETER Name
    Group, filter or scope tag display name. Wildcards are supported.
    .PARAMETER Id
    Exact object ID.
    .PARAMETER SubjectType
    Limit results to Group, AssignmentFilter or ScopeTag.
    .PARAMETER SnapshotPath
    Use a local IntuneAccess snapshot instead of a live collection.
    .PARAMETER FlaggedOnly
    Return only objects with at least one risk flag.
    .EXAMPLE
    Get-IntuneChangePreview -Name 'All Corporate Laptops'
    .EXAMPLE
    Get-IntuneChangePreview -FlaggedOnly
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()] [string] $Name = '*',
        [ValidateNotNullOrEmpty()] [string] $Id,
        [ValidateSet('Group', 'AssignmentFilter', 'ScopeTag')] [string[]] $SubjectType = @('Group', 'AssignmentFilter', 'ScopeTag'),
        [ValidateNotNullOrEmpty()] [string] $SnapshotPath,
        [switch] $FlaggedOnly
    )

    $collection = Get-IntuneAccessInsightCollection -SnapshotPath $SnapshotPath -IncludeWorkloadAssignments
    foreach ($subject in @(Get-IntuneAccessDependencyIndex -Collection $collection)) {
        if ($subject.SubjectType -notin $SubjectType) { continue }
        if ($PSBoundParameters.ContainsKey('Id') -and $subject.Id -ne $Id) { continue }
        if ($subject.Name -notlike $Name) { continue }
        if ($FlaggedOnly -and @($subject.Flags).Count -eq 0) { continue }
        $subject
    }
}
