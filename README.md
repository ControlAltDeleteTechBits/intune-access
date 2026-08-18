# IntuneAccess

IntuneAccess is an open source, read only PowerShell module that explains the Microsoft Intune RBAC access associated with an administrator. It joins the objects that are usually inspected one at a time: the administrator, Microsoft Entra groups, Intune role assignments, role definitions, allowed actions, Scope (Groups) and Scope (Tags).

The main result is a PowerShell object with an evidence trail. A self contained HTML report is available when a human readable record is needed.

IntuneAccess is an independent community project and is not affiliated with, endorsed by, or supported by Microsoft.

## Why IntuneAccess exists

The Intune admin centre exposes each RBAC building block, but answering a question such as "Why can this helpdesk administrator see this device?" can require several separate views. IntuneAccess performs that correlation without changing the tenant.

It is designed for administrators who need to establish:

1. Which Intune role assignments apply to a person.
2. Which exact Graph actions those roles allow.
3. Which Admin Groups supplied each assignment.
4. Which scope groups and scope tags constrain each assignment.
5. Which conclusions are confirmed and which remain `NotEvaluated`.

## What it does

1. Reads built in and custom role definitions from Microsoft Graph.
2. Preserves every source when two assignments allow the same action.
3. Returns structured PowerShell objects.
4. Follows Graph pagination and retries throttled or transient reads.
5. Produces a local, offline HTML report with no remote assets or tracking.
6. Audits a documented base or extended set of scope tag relationships.
7. Provides a conservative managed device access explanation.
8. Compares legacy merged and Scoped permissions behaviour without guessing the tenant setting.
9. Compares two administrators and identifies different permission evidence.
10. Exports complete JSON evidence or flattened CSV datasets.

## What it does not do

1. It does not create, edit or delete Intune configuration.
2. It does not request Graph write permissions.
3. It does not evaluate Microsoft Entra administrative roles.
4. It does not claim that a missing RBAC path proves access is denied.
5. It does not upload tenant data.

## Example

```powershell
Import-Module .\IntuneAccess.psd1

Connect-IntuneAccess

$access = Get-IntuneAdminAccess `
    -UserPrincipalName 'helpdesk.user@contoso.com'

$access.RoleAssignments
$access.EffectivePermissions
$access.ScopeGroups
$access.ScopeTags

$impact = $access | Get-IntuneScopedPermissionImpact
$impact.Rows

$access | Export-IntuneAccessReport `
    -Path '.\helpdesk-user-intune-access.html'

$access | Export-IntuneAccessData `
    -Path '.\helpdesk-user-intune-access.json' `
    -Format Json
```

For scope tag auditing or managed device access checks, reconnect with the required read only feature scopes:

```powershell
Connect-IntuneAccess -Feature Core, ScopeTagAudit, ManagedDeviceAccess

Get-IntuneScopeTagAudit

Test-IntuneResourceAccess `
    -UserPrincipalName 'helpdesk.user@contoso.com' `
    -DeviceName 'LAPTOP-0234'
```

## Screenshot

![IntuneAccess Signal Atlas report](screenshots/IntuneAccess-signal-atlas-full.png)

## Requirements

1. PowerShell 7 or later.
2. An Intune licensed tenant.
3. The `Microsoft.Graph.Authentication` module, version 2 or later.
4. Delegated Graph consent for the selected features.
5. A work or school account with sufficient Intune rights to read the requested tenant data.

Install the authentication module if needed:

```powershell
Install-PSResource Microsoft.Graph.Authentication -Scope CurrentUser -TrustRepository
```

## Graph permissions

Core analysis requests:

```text
User.Read
User.Read.All
GroupMember.Read.All
DeviceManagementRBAC.Read.All
```

Scope tag auditing adds:

```text
DeviceManagementConfiguration.Read.All
DeviceManagementApps.Read.All
```

Extended scope-tag auditing also adds:

```text
DeviceManagementScripts.Read.All
```

Managed device explanation adds:

```text
DeviceManagementManagedDevices.Read.All
Device.Read.All
```

Every requested permission ends in `Read` or `Read.All`. See [docs/permissions.md](docs/permissions.md) for the endpoint matrix and consent notes.

## Installation

IntuneAccess 1.0.0 is available from the PowerShell Gallery. Install it in PowerShell 7 or later:

```powershell
Install-PSResource IntuneAccess `
    -Repository PSGallery `
    -Scope CurrentUser `
    -TrustRepository

Import-Module IntuneAccess
```

The manifest declares `Microsoft.Graph.Authentication` version 2.0.0 or later as a dependency. See the [IntuneAccess package page](https://www.powershellgallery.com/packages/IntuneAccess/1.0.0) for the published metadata.

## Connect

`Connect-IntuneAccess` uses interactive delegated authentication. It shows the tenant, account and granted scopes after connection. Consent requirements are not hidden.

```powershell
Connect-IntuneAccess
```

Personal Microsoft accounts are not supported.

## Analyse an administrator

Use either a user principal name or a Microsoft Entra object ID:

```powershell
Get-IntuneAdminAccess -UserPrincipalName 'admin@contoso.com'

Get-IntuneAdminAccess `
    -UserId '00000000-0000-0000-0000-000000000000'
```

The returned object contains `User`, `Tenant`, `RoleAssignments`, `EffectivePermissions`, `AdminGroups`, `ScopeGroups`, `ScopeTags`, `Warnings`, `Evidence`, `GeneratedAt` and `ToolVersion`.

## Compare administrators

Compare two live analyses or two existing result objects:

```powershell
Compare-IntuneAdminAccess `
    -ReferenceUser 'senioradmin@contoso.com' `
    -DifferenceUser 'helpdesk@contoso.com'

Compare-IntuneAdminAccess `
    -ReferenceObject $seniorAccess `
    -DifferenceObject $helpdeskAccess
```

The comparison covers role assignments, exact Graph actions, Admin Groups, Scope Groups and Scope Tags. A shared permission is marked `DifferentEvidence` when different assignments supply it.

## Assess Scoped permissions impact

```powershell
$impact = $access | Get-IntuneScopedPermissionImpact
$impact.Rows | Format-Table Resource, ScopeTagName, Operation, LegacyState, ScopedState, Change
```

The default tenant mode is `Unknown`. Both documented models are returned, but `EffectiveState` remains `NotEvaluated` until the caller explicitly supplies `LegacyMerged` or `Scoped`:

```powershell
$access | Get-IntuneScopedPermissionImpact -TenantMode Scoped
```

This parameter is an explicit statement by the caller. It is not tenant-mode detection.

## Export structured evidence

Export a complete JSON evidence envelope:

```powershell
$access | Export-IntuneAccessData `
    -Path '.\access-snapshot.json' `
    -Format Json
```

Export flattened CSV datasets:

```powershell
$access | Export-IntuneAccessData `
    -Path '.\access-csv' `
    -Format Csv
```

CSV export writes summary, role assignment, permission, group, scope tag, warning and evidence datasets.

## Export an HTML report

```powershell
$access | Export-IntuneAccessReport -Path '.\IntuneAccess.html'
```

The report contains sensitive administrative information. It can include usernames, group names and RBAC configuration. Store and share it with the same care as other tenant administration exports.

## Scope tag audit

The base audit examines role assignments, classic device configurations and mobile apps. Findings use `Information` and `Review` severities. They are observations, not vulnerability claims.

```powershell
Connect-IntuneAccess -Feature Core, ScopeTagAudit
Get-IntuneScopeTagAudit
```

The extended audit adds compliance policies, Settings Catalog and endpoint security policies, remediations and device health scripts:

```powershell
Connect-IntuneAccess -Feature Core, ExtendedScopeTagAudit
Get-IntuneScopeTagAudit -IncludeExtendedResources
```

## How effective access is calculated

IntuneAccess keeps three layers:

1. Source: the Graph object and its raw ID.
2. Evidence: an observed relationship between sources.
3. Conclusion: an exact action marked `Allowed` or `NotEvaluated`.

Confirmed assignments are unioned by the exact action returned in the role definition. No built in role permission table is treated as authoritative.

Microsoft introduced an opt in Scoped permissions behaviour in March 2026. The documented Graph contracts used by IntuneAccess do not expose a dependable tenant setting for it. `Get-IntuneScopedPermissionImpact` models both documented behaviours from the observed assignments. It does not select the active behaviour unless the caller supplies the tenant mode.

See [docs/effective-access-model.md](docs/effective-access-model.md).

## Known limitations

1. Assignment scope tag IDs, scope type and audited resource tag IDs require isolated Microsoft Graph beta reads. Stable assignment identity, Admin Groups and Scope (Groups) come from v1.0 and remain available if beta enrichment fails.
2. Nested Admin Group membership can depend on Intune licensing and tenant configuration. Nested only paths are marked `NotEvaluated`.
3. Microsoft Entra roles, including Intune Administrator, are not evaluated.
4. Hidden Microsoft Entra group membership is not read because the default connection does not request `Member.Read.Hidden`.
5. Managed device access explanation is deliberately conservative and never returns `AccessDenied`.
6. Scope tag auditing covers a defined set of resource families rather than every Intune object type.
7. A live tenant is required to validate tenant specific behaviour.

See [docs/limitations.md](docs/limitations.md).

The current requirement-by-requirement status is recorded in [docs/completion-audit.md](docs/completion-audit.md).

Product decisions, design choices, validation evidence and release progress are tracked in [docs/project-log.md](docs/project-log.md).

The current release notes are available in [RELEASE_NOTES.md](RELEASE_NOTES.md).

## Security and privacy

IntuneAccess does not send tenant data to the project author. Microsoft Graph data is processed locally in the PowerShell session.

The module has no telemetry, analytics, hosted service, persistent tenant cache or credential store. Access tokens are not written to reports or logs. See [SECURITY.md](SECURITY.md).

## Microsoft documentation

The implementation and documentation were checked against Microsoft Learn on 17 August 2026.

1. [Assign Microsoft Intune roles](https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/assign-role)
2. [Use RBAC and scope tags for distributed IT](https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/scope-tags)
3. [List Intune role definitions](https://learn.microsoft.com/en-us/graph/api/intune-rbac-deviceandappmanagementroledefinition-list?view=graph-rest-1.0)
4. [List Intune role assignments](https://learn.microsoft.com/en-us/graph/api/intune-rbac-deviceandappmanagementroleassignment-list?view=graph-rest-1.0)
5. [List a user's direct and transitive memberships](https://learn.microsoft.com/en-us/graph/api/user-list-transitivememberof?view=graph-rest-1.0)

## Contributing

Bug reports and focused pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before sharing logs or sample Graph data.

## Licence

IntuneAccess is licensed under the [MIT Licence](LICENSE).

Bundled font and icon licences are recorded in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
