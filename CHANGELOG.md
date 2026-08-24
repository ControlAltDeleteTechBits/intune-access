# Changelog

All notable project changes are recorded here.

## 3.0.0

- Handles update and compliance workload records that omit `SourceApiVersion`, retaining `NotReturned` in collection provenance rather than stopping the report.

1. Added device inventory, Microsoft Entra reconciliation and evidence-backed hygiene rules.
2. Added device and associated-user assignment explanations with exclusions and conservative filter evaluation.
3. Added optional Autopilot, deployment profile, Enrolment Status Page and enrolment timeline evidence.
4. Added application definitions, detected software, installation results, requirements, detection rules and relationships.
5. Added update and compliance investigations with distinct targeting, stale, failure and unavailable states.
6. Added prioritised estate findings, recurring evidence groups, device cohorts, cross-device investigations and share-safe bundles.
7. Extended Signal Atlas, JSON, CSV and snapshot schema 2.0 for every device dataset.
8. Added six public commands and expanded the unit suite to 98 tests.

## 2.0.1

1. Added a prominent two-command Quick start to the GitHub README.
2. Added `Install-Module -Name IntuneAccess -Scope CurrentUser; Start-IntuneAccess` to the PowerShell Gallery description and release notes.
3. Clarified that installation and starting the guided explorer are separate PowerShell commands.
4. No collection, permission or report behaviour changed from 2.0.0.

## 2.0.0

1. Added conservative policy setting overlap and potential conflict analysis.
2. Normalised supported Settings Catalog, endpoint security intent and legacy device configuration settings while retaining their source API and collection state.
3. Reserved `PotentialConflict` for different observed values with confirmed exact target and filter overlap evidence; incomplete overlap remains `NotEvaluated`.
4. Added a 30-day Intune audit trail and exact resource-ID correlation to snapshot changes.
5. Expanded the Signal Atlas explorer with Policy Settings, Policy Conflicts, Snapshot Changes and Audit Trail views.
6. Added `Get-IntunePolicyConflict` and completed the local roadmap through 2.0.0.
7. Corrected managed-device collection to use the documented v1.0 `managedDeviceOwnerType` and `deviceRegistrationState` properties.

## 1.4.0

1. Added local, allow-listed tenant snapshots without authentication context, credentials or access tokens.
2. Added SHA-256 integrity validation and optional stable identity pseudonymisation.
3. Added evidence comparison for added, removed and modified RBAC, assignment and policy records.
4. Added conservative broad-target impact summaries without claiming exact affected membership.
5. Added `Export-IntuneAccessSnapshot` and `Compare-IntuneAccessSnapshot`.

## 1.3.0

1. Added Device 360 and User 360 views from managed-device identity and supported reported outcomes.
2. Retained reported state, detail, timestamps and decimal plus hexadecimal error codes.
3. Isolated failures by workload so available device inventory remains useful.
4. Added `Get-IntuneDevice360` and `Get-IntuneUser360`.

## 1.2.0

1. Added assignment and impact collection for configuration, compliance, endpoint security, applications, scripts, remediations and Windows updates.
2. Normalised included, excluded, broad and assignment-filter targets with API provenance and collection state.
3. Added `Get-IntuneAssignmentImpact` and the corresponding Signal Atlas views.

## 1.1.0

1. Added the guided `Start-IntuneAccess` workflow: delegated sign-in, tenant collection, local HTML generation and automatic opening.
2. Added a tenant-wide explorer across administrators, Admin Groups, roles, role assignments, Scope Groups, Scope Tags and exact permissions.
3. Added searchable object navigation, relationship inspection and resilient long identity formatting.

## 1.0.0

First stable release.

1. Live validated one built-in and one custom Intune role assignment against the Intune admin centre.
2. Confirmed cumulative managed-device read permission evidence from two assignments.
3. Fixed Graph role-assignment collection responses that omit members and scope arrays by hydrating each listed assignment from its v1.0 and beta detail endpoints.
4. Added a regression test for assignment detail hydration.
5. Added positive live integration assertions for role type, Admin Groups, Scope Groups, Scope Tags and duplicate granting evidence.
6. Confirmed a managed device scope relationship through direct Microsoft Entra device-group membership.
7. Promoted module, package, report and release metadata to 1.0.0.
8. Retained conservative `NotEvaluated` handling where the device's observed Intune tag does not match the assignment tag.

## 0.2.0-preview

Prepared as an unpublished development preview.

1. Added `Get-IntuneScopedPermissionImpact` to compare legacy merged and Scoped permissions models.
2. Added explicit `Unknown`, `LegacyMerged` and `Scoped` tenant-mode handling without automatic inference.
3. Added `Compare-IntuneAdminAccess` for role, permission, group and scope comparisons.
4. Added different-evidence detection for permissions granted through different assignments.
5. Added `Export-IntuneAccessData` with complete JSON evidence and eight CSV datasets.
6. Added modern PowerShell Gallery metadata and the Microsoft Graph authentication dependency.
7. Added allow-listed Gallery package creation and isolated package validation.
8. Reduced the Gallery package from approximately 2.8 MB to approximately 255 KB by excluding development material.
9. Added Windows and Linux GitHub Actions validation.
10. Added a clean no-profile PowerShell import gate.
11. Raised measured unit-test coverage to at least 70%.
12. Expanded the unit suite from 26 to 44 tests, with 72.59% measured command coverage.
13. Added optional extended scope-tag coverage for compliance policies, Settings Catalog, endpoint security policies, remediations and device health scripts.

## 0.1.0-preview

Released as an unpublished development preview.

1. Added delegated, read only Microsoft Graph connection handling.
2. Added administrator, role assignment and effective permission analysis.
3. Added source IDs and evidence for every permission conclusion.
4. Added conservative scope group and scope tag handling.
5. Added a limited scope tag audit.
6. Added a preview managed device access explanation.
7. Added a self contained HTML report.
8. Added mocked Pester tests, documentation and security guidance.
9. Added managed-device scope evidence for both device groups and associated-user groups.
10. Added explicit missing-data states for incomplete Graph role, assignment and scope-tag responses.
11. Fixed empty Graph collections being misread as synthetic records.
12. Added an empty-collection regression test and corrected live contract assertions for valid empty arrays.
13. Completed the six live integration checks against a test tenant with no Intune RBAC assignments.
14. Rebuilt the offline HTML report as the Signal Atlas access map.
15. Embedded Space Grotesk, IBM Plex Mono and Phosphor icon assets with their licence files.
16. Added native evidence disclosures and CSS permission family filters without introducing JavaScript.
17. Added desktop and narrow-screen layout corrections after visual comparison testing.
18. Added a project decision log, preview release notes, Awesome Intune submission draft and repeatable release check.
19. Added third party notices for the bundled fonts and icon library.
