function Get-IntuneAssignmentImpact {
    <#
    .SYNOPSIS
    Gets read-only assignment evidence for supported Intune workloads.
    .DESCRIPTION
    Collects policies, applications, scripts and update objects with their assignment
    targets. The command reports confirmed assignment configuration and explicit
    exclusions. It does not claim that a user or device received the payload unless
    deployment evidence supports that conclusion.
    .PARAMETER ExcludeBeta
    Omits Settings Catalog, script, remediation, update profile and assignment filter
    endpoints which are currently exposed through Microsoft Graph beta.
    .EXAMPLE
    Get-IntuneAssignmentImpact
    #>
    [CmdletBinding()]
    param(
        [switch] $ExcludeBeta
    )

    Get-IntuneAccessWorkloadAssignments -ExcludeBeta:$ExcludeBeta
}
