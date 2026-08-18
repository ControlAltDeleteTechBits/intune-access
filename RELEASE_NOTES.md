# IntuneAccess 2.0.0

IntuneAccess 2.0.0 completes the agreed local roadmap. The Signal Atlas explorer now connects administrative access, workload targeting, reported outcomes, change history and conservative policy overlap analysis in one read-only report.

## Guided workflow

`Start-IntuneAccess` selects `Core`, `AssignmentExplorer`, `OperationalEvidence`, `PolicyAnalysis` and `AuditEvidence` by default. After delegated sign-in it creates one self-contained report in Documents and opens it in the default browser.

Use `Start-IntuneAccess -Feature Core, AssignmentExplorer` when managed-device, outcome and setting analysis is not required.

## Added since 1.0.0

1. Tenant-wide navigation across administrators, Admin Groups, roles, role assignments, Scope Groups, Scope Tags and exact Intune actions.
2. Assignment Impact across configuration, compliance, endpoint security, applications, scripts, remediations and Windows updates.
3. Device 360, User 360 and supported reported deployment outcomes with timestamps, detail and decimal plus hexadecimal error codes.
4. Local allow-listed snapshots without authentication context, credentials or access tokens.
5. SHA-256 snapshot integrity validation and optional stable identity pseudonymisation.
6. Added, removed and modified evidence comparison with conservative broad-target impact counts.
7. Policy setting normalisation for Settings Catalog, endpoint security intents and supported legacy device configuration properties.
8. Potential conflict findings only where different observed values share an exact included target and matching filter evidence.
9. Policy Settings, Policy Conflicts and Snapshot Changes sections in the offline HTML explorer.
10. Public `Export-IntuneAccessSnapshot`, `Compare-IntuneAccessSnapshot` and `Get-IntunePolicyConflict` commands.
11. A 30-day Intune Audit Trail and resource-ID links from matching snapshot changes.
12. Corrected managed-device collection to use the documented v1.0 `managedDeviceOwnerType` and `deviceRegistrationState` properties.

## Evidence boundary

A configured assignment does not prove delivery. A reported outcome does not prove the assignment path that produced it. A policy conflict finding does not prove the final value enforced on a device.

Different target groups, different filters and incomplete assignment evidence remain `NotEvaluated`. Missing data is never presented as success, failure or proof that no conflict exists.

Identity redaction creates stable pseudonyms for comparison. It is not irreversible anonymisation and the resulting file must still be handled as potentially sensitive.

## Validation evidence

1. Seventy-seven unit tests pass with 81.44 per cent command coverage.
2. PowerShell Script Analyzer reports no findings and a clean process imports all 16 intended commands.
3. The exact 89-entry Gallery package installed as version 2.0.0 through a temporary local PSResourceGet repository.
4. The module source contains no Microsoft Graph write scope or write request method.

## Known limitations

1. Settings Catalog and endpoint security setting contracts used for analysis are Microsoft Graph beta contracts.
2. Legacy profile analysis compares returned non-null profile properties; it does not claim portal intent that Graph does not expose.
3. Exact different-group membership intersection and assignment-filter rule evaluation are not calculated in 2.0.0.
4. Microsoft marks the legacy configuration device-status and beta application device-status resources as deprecated. Each call is isolated and labelled.
5. Settings Catalog, endpoint security and Windows update deployment outcomes remain `NotSupported` until a documented read contract is adopted.
6. Microsoft Entra administrative roles are not evaluated.
7. The active Scoped permissions tenant mode is not obtained from a supported Graph contract.
8. Managed-device access analysis never claims access denied when a complete path cannot be proved.

Use a non-production tenant first and review the documented limitations before relying on the output for an administrative decision.
