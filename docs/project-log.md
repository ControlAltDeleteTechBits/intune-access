# IntuneAccess project log

This document records product decisions, design choices, validation evidence, release progress and unresolved work. Update it when a decision changes or a release check produces new evidence.

Last updated: 17 August 2026.

## Current status

IntuneAccess is prepared as version `1.0.0`. The core module, evidence model, HTML report, Scoped permissions modelling, administrator comparison, structured exports, unit tests and documentation are implemented. The project remains read only and requests no Microsoft Graph write permission.

Positive RBAC validation now passes against a test user with built-in and custom assignments. The remaining publication work is the final release gate, public repository and external package publication.

## Product decisions

1. The project remains a PowerShell 7 module with no Python, Node.js, hosted service, database or local server dependency.
2. Microsoft Graph is the only tenant data source.
3. Conclusions are separated into source, evidence and conclusion layers.
4. Missing or uncertain relationships return `NotEvaluated`, `Unknown` or a warning. They are not converted into an access denied result.
5. Version `1.0.0` is the first stable release.
6. The likely Awesome Intune directory classification is Reporting and PowerShell Module.
7. The product and Gallery package name remains `IntuneAccess`; IdentityAtlas remains a sibling product.
8. Scoped permissions mode is never detected through an undocumented endpoint. Both models are shown and the caller must select a tenant mode explicitly.

## Design decisions

1. The selected report direction is Signal Atlas, option 3 from the August 2026 design exploration.
2. Space Grotesk is the primary interface and heading typeface.
3. IBM Plex Mono is used for identifiers, technical metadata and compact field labels.
4. Both fonts are bundled under the SIL Open Font Licence and embedded into generated reports. Reports remain self contained and work offline.
5. Phosphor provides the interface icons. The assets and licence are bundled locally.
6. Confirmed access paths use yellow. Paths that cannot be fully evaluated use grey dashed connectors.
7. Allowed access is not presented as green or good, and unevaluated access is not presented as red or failed.
8. Native HTML disclosure elements expose assignment and permission evidence without JavaScript.
9. Permission family filters use native radio controls and CSS. No remote or inline script is required.
10. Narrow screens use a vertical evidence sequence. The spatial desktop map is not compressed into an unreadable miniature.
11. VibeCurb informed the typography, restrained palette, technical rules and asymmetrical composition. The implementation and wording are original to IntuneAccess.

## Validation evidence

1. The PowerShell module manifest validates.
2. The module imports in PowerShell 7 and exports nine intended public commands.
3. All 45 unit tests pass.
4. PowerShell Script Analyzer returns no findings with the repository settings.
5. The HTML report contains no remote runtime dependency, analytics or tracking.
6. Desktop access paths, native evidence disclosures and permission family filters were checked in the local browser.
7. The 390 pixel responsive view has no horizontal document overflow.
8. Seven integration checks passed against a test user with built-in and custom Intune RBAC assignments.
9. The live result matches the portal role types, Admin Groups, Scope Group and Scope Tag, and retains two managed-device read grants.
10. A clean consent run using only the documented delegated scopes remains unverified because the existing Microsoft Graph Command Line Tools registration already held broader consent.
11. Measured command coverage is 72.8 per cent across 45 passing unit tests.
12. The 1.0.0 Gallery package passes isolated no-profile import and temporary local PSResourceGet repository installation.
13. The Gallery package excludes tests, screenshots, development tools and workflow files.

## Release decisions

1. Release tag: `v1.0.0`.
2. Release title: `IntuneAccess 1.0.0`.
3. The release archive will include the module, tests, documentation, examples, bundled fonts, bundled icons and screenshots.
4. A SHA-256 checksum will be published beside the release archive.
5. The README must use the final public repository URL before publication.
6. The release notes must retain the least privilege consent limitation and the managed-device tag observation.
7. Awesome Pick entry is completed by posting the released contribution in the Awesome Intune LinkedIn group. There is no separate Pick registration form.
8. Awesome Intune directory listing is a separate submission through `/submit`.

## Release blockers

1. Create or identify the public GitHub repository and final repository URL.
2. Confirm the public author name and optional GitHub or LinkedIn profile URLs.
3. Complete a clean least privilege consent check or keep the limitation prominent in the release notes.
4. Confirm the maintainer belongs to the Awesome Intune LinkedIn group before posting the Pick contribution.
5. Obtain final approval before submitting the directory form or posting to LinkedIn.
6. Publish only the independently tested `.nupkg`; do not rebuild from the source directory during submission.

## Progress log

### 17 August 2026

1. Completed the initial module implementation, mocked Graph correlation and safety documentation.
2. Connected to a test tenant and passed six integration checks for the empty assignment path.
3. Fixed empty Graph collections being misread as synthetic records.
4. Generated and compared three report design directions informed by VibeCurb.
5. Selected Signal Atlas.
6. Rebuilt the report generator around an administrator access map and permission index.
7. Selected Space Grotesk with IBM Plex Mono as the permanent report typography.
8. Bundled offline font and Phosphor icon assets with their licence files.
9. Added working native evidence disclosures and CSS permission filters.
10. Corrected desktop metadata overflow and mobile table overflow.
11. Passed 26 unit tests and PowerShell Script Analyzer after the redesign.
12. Reviewed the current Awesome Pick rules and Awesome Intune directory submission fields.
13. Confirmed that the `IntuneAccess` name is not currently present as an exact PowerShell Gallery package or GitHub repository name.
14. Kept `IntuneAccess` as the product name and retained IdentityAtlas as a sibling product.
15. Added legacy-versus-Scoped permission impact modelling with explicit tenant-mode selection.
16. Added administrator comparison with different-evidence detection.
17. Added complete JSON and flattened CSV evidence exports.
18. Declared Microsoft.Graph.Authentication as a Gallery dependency and aligned publisher metadata with IdentityAtlas.
19. Added an allow-listed Gallery build and isolated package validation.
20. Added a Windows and Linux GitHub Actions validation workflow.
21. Expanded the unit suite to 44 passing tests and raised measured coverage to 72.59%.
22. Added an opt-in extended scope-tag audit for compliance policies, Settings Catalog and endpoint security policies, and remediation scripts. The extra Microsoft Graph permission is requested only when this mode is selected.
23. Created two administrator groups, one device scope group, one custom scope tag, one custom role and built-in and custom assignments in the test tenant.
24. Found that the Graph assignment collection omitted member and scope arrays while each assignment detail endpoint returned them.
25. Added assignment detail hydration and a regression test; all 45 unit tests passed.
26. Passed seven live integration checks against the positive fixture and confirmed duplicate managed-device read evidence.
27. Confirmed the managed device matches the intended device scope group. Its Intune object still carries the Default tag, so the full path remains conservatively `NotEvaluated`.
28. Promoted all active release metadata to 1.0.0 and removed the module prerelease marker.
29. Passed the 1.0.0 release gate with 45 tests, 72.8 per cent coverage, nine exported commands and no analyzer findings.
30. Built and validated `IntuneAccess.1.0.0.nupkg`, then installed and imported it through a temporary local PSResourceGet repository.

### 18 August 2026

1. Created the public `ControlAltDeleteTechBits/intune-access` repository and published the GitHub 1.0.0 release.
2. Published `IntuneAccess` 1.0.0 to the PowerShell Gallery at <https://www.powershellgallery.com/packages/IntuneAccess/1.0.0>.
3. Recorded the public Gallery publication time as `2026-08-18 08:35:26` from the Gallery feed.
4. Downloaded the public package and confirmed its SHA-256 hash matches the tested package: `4e1459c0ea79e4ef42144297f64aeb21fb662f4a141d3c9ec4fea8c7c15497a2`.
5. Installed the Gallery copy in an isolated path, imported version 1.0.0 and confirmed all nine commands are exported.
6. Confirmed the Gallery page names Mark Oldham as author, Control Alt Delete Tech Bits as company and Microsoft.Graph.Authentication as a dependency.
7. Confirmed the project, licence, icon and GitHub release links resolve publicly.
8. Revoked the one-day, package-restricted Gallery API key and cleared it from the clipboard after publication.
9. Removed reliance on `Publish-PSResource -WhatIf` after PSResourceGet 1.2.0 treated the dry-run command as a live publication.

## Next actions

1. Complete a clean least-privilege consent run using a dedicated Microsoft Entra application, or retain the documented shared-client limitation.
2. Submit the Awesome Intune directory form after approval.
3. Post the contribution in the Awesome Intune LinkedIn group after approval.
