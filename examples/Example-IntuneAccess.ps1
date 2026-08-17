#requires -Version 7.0

Import-Module (Join-Path $PSScriptRoot '..\IntuneAccess.psd1') -Force

Connect-IntuneAccess

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
