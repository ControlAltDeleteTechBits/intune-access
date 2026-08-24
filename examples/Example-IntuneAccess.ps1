#requires -Version 7.0

[CmdletBinding()]
param(
    [switch] $Advanced
)

Import-Module (Join-Path $PSScriptRoot '..\IntuneAccess.psd1') -Force

# Guided interactive workflow: sign in, collect tenant Intune RBAC data, create the explorer and open it.
if (-not $Advanced) {
    Start-IntuneAccess
    return
}

# Run this example with -Advanced to exercise the individual commands below.

Connect-IntuneAccess -Feature Core, AssignmentExplorer, OperationalEvidence, DeviceIntelligence, ApplicationEvidence, UpdateCompliance, EstateIntelligence

$assignmentImpact = Get-IntuneAssignmentImpact
$assignmentImpact.Workloads
$assignmentImpact.Assignments

$policyAnalysis = Get-IntunePolicyConflict `
    -Workload $assignmentImpact.Workloads `
    -Assignment $assignmentImpact.Assignments
$policyAnalysis.PotentialConflicts

$hygiene = Get-IntuneDeviceHygiene
$hygiene.Findings | Format-Table Severity, RuleId, DeviceName, EvidenceTimestamp

Get-IntuneDeviceAssignmentExplanation -DeviceName 'LAPTOP-0234'
Get-IntuneApplicationEvidence -DeviceName 'LAPTOP-0234'
Get-IntuneUpdateCompliance -DeviceName 'LAPTOP-0234'

$estate = Get-IntuneDeviceEstateInsight
$estate.PrioritisedFindings | Format-Table PriorityScore, Severity, DeviceName, Title

# Autopilot is optional and requires a new connection with its service-configuration read scope.
# Connect-IntuneAccess -Feature Core, OperationalEvidence, Autopilot
# Get-IntuneAutopilotTimeline -SerialNumber 'PF123ABC'

$access = Get-IntuneAdminAccess `
    -UserPrincipalName 'helpdesk.user@contoso.com'

$access.RoleAssignments
$access.EffectivePermissions
$access.ScopeGroups
$access.ScopeTags
$access.Warnings

$impact = $access | Get-IntuneScopedPermissionImpact
$impact.Rows | Format-Table Resource, ScopeTagName, Operation, LegacyState, ScopedState, Change

$access | Export-IntuneAccessData `
    -Path (Join-Path $PSScriptRoot 'IntuneAccess-example.json') `
    -Format Json

$access | Export-IntuneAccessReport `
    -Path (Join-Path $PSScriptRoot 'IntuneAccess-example.html')

# Reconnect only when the additional feature scopes are needed.
Connect-IntuneAccess -Feature Core, ScopeTagAudit, ManagedDeviceAccess

Get-IntuneScopeTagAudit

Connect-IntuneAccess -Feature Core, ExtendedScopeTagAudit
Get-IntuneScopeTagAudit -IncludeExtendedResources

Test-IntuneResourceAccess `
    -UserPrincipalName 'helpdesk.user@contoso.com' `
    -DeviceName 'LAPTOP-0234'
