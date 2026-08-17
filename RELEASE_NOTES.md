# IntuneAccess 1.0.0

IntuneAccess is a read only PowerShell module that explains Microsoft Intune RBAC access for an administrator. It correlates Microsoft Entra group membership, Intune role assignments, role definitions, allowed actions, Scope (Groups) and Scope (Tags), and retains the evidence behind each conclusion.

## Capabilities

1. Delegated Microsoft Graph connection using documented read permissions.
2. Administrator analysis by user principal name or Microsoft Entra object ID.
3. Built-in and custom Intune roles using permissions returned by Microsoft Graph.
4. Cumulative permission calculation with every granting source retained.
5. Admin Group, Scope Group and Scope Tag evidence, including raw object IDs.
6. Detail-endpoint hydration for Graph role-assignment collections that omit member and scope arrays.
7. Scoped permissions impact modelling with explicit tenant-mode selection.
8. Comparison of two administrators, including different granting evidence.
9. Complete JSON evidence and eight flattened CSV datasets.
10. Conservative managed-device access explanation.
11. Base and extended scope-tag audits.
12. Self contained Signal Atlas HTML reports with bundled fonts and icons.

## Validation evidence

1. Forty-five unit tests pass.
2. Seven live integration checks pass against a test user with one built-in and one custom Intune RBAC assignment.
3. The live run resolves the portal Admin Groups, Scope Group and Scope Tag, and retains two grants for `Microsoft.Intune_ManagedDevices_Read`.
4. A managed device is proved to match the assigned Microsoft Entra device scope group. Its current Intune tag is still Default, so the full device result remains `NotEvaluated` as designed.
5. Measured command coverage is 72.8 per cent. PowerShell Script Analyzer reports no findings.
6. The 1.0.0 package imports in a clean no-profile process and installs from a temporary local PSResourceGet repository with nine exported commands.
7. The project contains no Graph write scope, telemetry, analytics or tenant-data upload path.

## Known limitations

1. The Microsoft Graph Command Line Tools service principal in the test tenant already holds broader delegated consent. A clean session confirmed the requested feature scopes were present, but could not prove that the shared client held only those scopes.
2. The active Scoped permissions tenant mode is not obtained from a supported Graph contract. The caller must select a model explicitly when an effective outcome is required.
3. Microsoft Entra administrative roles are not evaluated.
4. Nested Admin Group behaviour can depend on tenant configuration and licensing. Nested-only paths remain `NotEvaluated`.
5. Assignment scope type, assignment scope-tag IDs and some audited resource tags use isolated Microsoft Graph beta reads.
6. Managed-device access analysis never claims access denied when a complete path cannot be proved.

Use a non-production tenant first and review the documented limitations before relying on the output for an administrative decision.
