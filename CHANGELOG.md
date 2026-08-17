# Changelog

All notable project changes are recorded here.

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
