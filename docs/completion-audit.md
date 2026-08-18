# Completion audit

Audited against the attached IntuneAccess build specification and agreed roadmap on 18 August 2026.

## Acceptance criteria

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Module imports in PowerShell 7 | Manifest and separate no-profile module imports checked in PowerShell 7.6.5. Sixteen intended commands are exported. | Locally verified |
| No Graph write permissions | Connection source contains read scopes only. Unit test rejects any `ReadWrite.All` scope in production source. Graph transport accepts GET only. | Locally verified |
| Connection is documented | README and command help document delegated connection, selected features, consent and personal-account rejection. | Verified in source |
| User selection by UPN or object ID | `Get-IntuneAdminAccess` has `ByUpn` and `ById` parameter sets. | Mock tested |
| Applicable role assignments identified | Direct and nested group evidence is correlated with assignment `members`; nested-only applicability remains `NotEvaluated`. Built-in and custom positive assignments were found in the live tenant. | Mock and live tested |
| Built in and custom roles | `isBuiltIn` is read from Graph and custom actions are not hard coded. Help Desk Operator and a custom managed-device reader matched the portal. | Mock and live tested |
| Permissions come from Graph role definitions | Exact `allowedResourceActions` values are read from v1.0 role definitions. Missing permission data produces a warning. | Mock tested |
| Cumulative permissions | Confirmed actions are unioned by exact action. Managed-device read retained two live grants. | Mock and live tested |
| Duplicate sources retained | One effective permission retains every granting assignment in `GrantedBy`. | Mock and live tested |
| Admin Groups displayed | Assignment `members` IDs are resolved and retained with raw IDs. Both live Admin Groups matched the portal. | Live verified |
| Scope (Groups) displayed | v1.0 `resourceScopes` and beta `scopeType` are retained and resolved. Stable scope groups survive a beta failure. The live device scope group matched the portal. | Live verified |
| Scope (Tags) displayed | Beta `roleScopeTagIds` are isolated, resolved and labelled. Missing data is not treated as empty. The custom live tag matched the portal. | Live verified |
| Graph pagination | Transport follows every `@odata.nextLink`. | Mock tested |
| Graph throttling | HTTP 429 and transient server errors retry with `Retry-After` or bounded backoff. | Mock tested |
| Unknown cases are not guessed | Missing beta properties, nested-only Admin Groups and incomplete resource paths return `NotEvaluated` or a warning. | Mock tested |
| Structured PowerShell output | Main command returns `IntuneAccess.AdminAccess` with source, evidence and conclusion properties. | Mock tested |
| Useful default console output | Format view shows administrator, tenant, assignment, permission and warning counts without changing the object. | Unit tested |
| Public command help | Every exported command has comment-based help and at least one example. | Source inspected and release gated |
| HTML report | Pipeline and direct-user export paths generate one offline HTML file. Tenant text is encoded. | Unit tested and visually inspected |
| Guided tenant explorer | `Start-IntuneAccess` collects RBAC, assignments, operational evidence and supported policy settings before opening one local explorer. | Unit tested and visually inspected |
| Local snapshots | Allow-listed JSON excludes authentication context and supports integrity validation, stable pseudonyms and comparison. | Unit tested |
| Intune audit correlation | A bounded v1.0 audit collection retains actors, resources and modified properties; exact resource IDs link to snapshot changes. | Unit tested; live validation pending |
| Policy overlap | Same-setting values are compared and potential conflict is reserved for different values with exact target and filter overlap evidence. | Unit tested; live validation pending |
| No external HTML dependencies | Report contains inline CSS, no remote fonts, scripts, links, analytics or tracking. | Unit tested |
| No tenant data upload | No network destination exists outside Microsoft Graph. Processing and report generation are local. | Source inspected |
| No token logging | No file logger exists and no token or authorisation header is placed in output. | Source inspected |
| Effective model documented | README and `effective-access-model.md` describe source, evidence, conclusion and 2026 Scoped permissions uncertainty. | Verified |
| Permission matrix documented | `permissions.md` maps each endpoint to a delegated read permission. | Verified against Microsoft Learn |
| Beta dependencies documented | Architecture, limitations and permission documents identify each beta dependency. | Verified |
| Pester tests pass | Seventy-eight unit tests pass with at least 81 per cent coverage. Seven earlier positive RBAC integration checks also pass. | Locally and live verified |
| PSScriptAnalyzer | Repository scan returns no findings with the checked-in settings. | Locally verified |
| MIT licence | `LICENSE` contains the MIT licence. | Verified |
| Security policy | `SECURITY.md` covers private reporting and tenant-data handling. | Verified |
| Useful example | `examples/Example-IntuneAccess.ps1` covers connection, analysis, report, audit and device explanation. | Verified |
| Original implementation | Source and wording were created for IntuneAccess. VibeCurb supplied design principles only. | Maintainer assertion |

## Managed-device explanation

The managed-device explanation requires one assignment to provide a confirmed Admin Group path, the exact action, a matching resource scope and a matching scope tag. A `resourceScope` can match either:

1. The Microsoft Entra device's transitive group membership.
2. The managed device's associated user's transitive group membership.

The result records `DeviceGroup`, `AssociatedUserGroup` or `VirtualAllDevices` as the scope match source. No complete path returns `NotEvaluated`, never access denied.

## Local quality evidence

Run `tools/Test-Release.ps1` to perform:

1. `Test-ModuleManifest`.
2. Module import in the current process and a separate no-profile PowerShell 7 process.
3. PowerShell parser checks over every script and manifest.
4. Pester unit tests.
5. PSScriptAnalyzer over the full repository.
6. HTML safety tests.
7. ZIP generation and SHA-256 hashing.
8. Separate allow-listed Gallery package creation and isolated package import validation.

The 2.0.1 validation run passed on 18 August 2026. Seventy-eight tests pass with at least 81 per cent coverage and no Script Analyzer findings. The 89-entry Gallery package is expanded into an isolated validation directory, imported with 16 exported commands and installed as version 2.0.1 through a temporary local PSResourceGet repository. Responsive browser inspection remains a separate design check rather than a step performed by `Test-Release.ps1`.

## Outstanding release evidence

A real test tenant was connected on 17 August 2026. Seven integration checks passed for a user with built-in and custom Intune RBAC assignments. The returned Admin Groups, Scope Group and Scope Tag matched the Intune admin centre, and cumulative managed-device read access retained two granting assignments. The managed device matched the known device scope group, while its observed Intune tag remained Default, so the complete device path correctly remained `NotEvaluated`.

The live run exposed a Graph behaviour where assignment collection responses omitted member and scope arrays although the assignment detail endpoints returned them. Version 1.0.0 hydrates each listed assignment from its detail endpoint and includes a regression test. The Microsoft Graph Command Line Tools registration used for the live run already had broader delegated consent, so a clean least-privilege shared-client result remains outstanding.

The assignment, operational, snapshot and policy-conflict layers added after 1.0.0 are locally verified. They still require the maintainer's live development-tenant comparison with the Intune admin centre before any 2.0.0 publication decision.

The first 2.0.0 live run exposed an invalid managed-device `$select` pair. The collector now uses the documented v1.0 `managedDeviceOwnerType` and `deviceRegistrationState` properties, with a regression-tested compatibility fallback for older fixtures. The release and package gates were rerun after this correction.
