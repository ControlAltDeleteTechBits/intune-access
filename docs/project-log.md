# IntuneAccess project log

This document records product decisions, design choices, validation evidence, release progress and unresolved work. Update it when a decision changes or a release check produces new evidence.

Last updated: 24 August 2026.

## Current status

IntuneAccess 2.0.1 is published. The agreed roadmap now extends from device inventory and hygiene in 2.1.0 through device estate intelligence in 3.0.0. The project remains read only and requests no Microsoft Graph write permission.

Positive RBAC validation passes against a test user with built-in and custom assignments. The 2.0.1 release and local Gallery installation gates pass with no functional change from 2.0.0.

## Product decisions

1. The project remains a PowerShell 7 module with no Python, Node.js, hosted service, database or local server dependency.
2. Microsoft Graph is the only tenant data source.
3. Conclusions are separated into source, evidence and conclusion layers.
4. Missing or uncertain relationships return `NotEvaluated`, `Unknown` or a warning. They are not converted into an access denied result.
5. Version `1.0.0` is the first stable release.
6. The likely Awesome Intune directory classification is Reporting and PowerShell Module.
7. The product and Gallery package name remains `IntuneAccess`; IdentityAtlas remains a sibling product.
8. Scoped permissions mode is never detected through an undocumented endpoint. Both models are shown and the caller must select a tenant mode explicitly.
9. The agreed product direction connects administrator control, workload targeting and reported endpoint outcome in one evidence chain.
10. The versioned plan is maintained in `docs/roadmap.md`: 1.1.0 tenant wide RBAC explorer, 1.2.0 assignment and impact explorer, 1.3.0 Device and User 360, 1.4.0 snapshots and change impact, 2.0.0 policy overlap and conflict analysis, 2.1.0 device inventory and hygiene, 2.2.0 device assignment explanation, 2.3.0 Autopilot and enrolment timeline, 2.4.0 application and software evidence, 2.5.0 update and compliance investigation, and 3.0.0 device estate intelligence.
11. The core product question is recorded as: who can change it > who should receive it > what Intune reported > where the evidence stops.
12. Assignment configuration and deployment outcome are separate evidence layers. A returned assignment never proves successful delivery by itself.
13. The primary module remains read only. Wipe, retire, delete, restart, sync and other device-changing remote actions are excluded from the agreed device roadmap.

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
2. The module imports in PowerShell 7 and exports 16 intended public commands.
3. All 78 unit tests pass.
4. PowerShell Script Analyzer returns no findings with the repository settings.
5. The HTML report contains no remote runtime dependency, analytics or tracking.
6. Desktop access paths, native evidence disclosures and permission family filters were checked in the local browser.
7. The 390 pixel responsive view has no horizontal document overflow.
8. Seven integration checks passed against a test user with built-in and custom Intune RBAC assignments.
9. The live result matches the portal role types, Admin Groups, Scope Group and Scope Tag, and retains two managed-device read grants.
10. A clean consent run using only the documented delegated scopes remains unverified because the existing Microsoft Graph Command Line Tools registration already held broader consent.
11. Measured command coverage remains above 81 per cent across 78 passing unit tests.
12. The 1.0.0 Gallery package passes isolated no-profile import and temporary local PSResourceGet repository installation.
13. The Gallery package excludes tests, screenshots, development tools and workflow files.
14. The 2.0.0 Gallery package contains 89 entries and installs all 16 commands from a temporary local repository.
15. The 2.0.1 Gallery package contains 89 entries, exposes the two-command Quick start in its metadata and installs all 16 commands from a temporary local repository.

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

1. Complete a clean least-privilege consent check or keep the limitation prominent in the release notes.
2. Validate the 1.2.0 to 2.0.0 collectors and findings against the development tenant and Intune admin centre.
3. Confirm the maintainer belongs to the Awesome Intune LinkedIn group before posting the Pick contribution.
4. Obtain final approval before publishing a new Gallery version, submitting the directory form or posting to LinkedIn.
5. Publish only the independently tested `.nupkg`; do not rebuild from the source directory during submission.

## Progress log

### 24 August 2026

1. Adopted the device-focused roadmap from version 2.1.0 through 3.0.0.
2. Defined release scope and completion criteria for device hygiene, assignment explanation, Autopilot, application evidence, update and compliance investigation, and estate intelligence.
3. Retained read-only delegated permissions and excluded device-changing remote actions from the primary module.

### 18 August 2026

1. Published IntuneAccess 2.0.0 to GitHub and the PowerShell Gallery.
2. Confirmed a clean device can install the module with `Install-Module -Name IntuneAccess`.
3. Prepared 2.0.1 to make `Start-IntuneAccess` explicit in the Gallery description, release notes and README Quick start.
4. Passed 78 tests with at least 81 per cent coverage, a clean analyser scan, isolated package import and local Gallery installation for 2.0.1.

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
9. Added a normalised workload and assignment evidence model spanning configuration, compliance, endpoint security, applications, scripts, remediations and Windows update profiles.
10. Added per-source collection states, API-version provenance, explicit exclusion handling and assignment-filter resolution.
11. Added Policies and Apps, Assignment Impact, Target Groups and Assignment Filters views to the self-contained Signal Atlas explorer.
12. Verified navigation, filtering, cross-links, inspector wrapping and the 390 pixel responsive menu in the local browser.
13. Expanded the unit suite to 56 passing tests before the full release gate.
14. Passed the 1.2.0 source gate with 56 tests, 79.32 per cent command coverage, 11 clean exports and no Script Analyzer findings.
15. Built the 1.2.0 Gallery package, validated 75 package entries and installed 11 commands from a temporary local PSResourceGet repository.
16. Added managed-device inventory and normalised supported configuration, compliance, application, PowerShell script and remediation outcome evidence.
17. Added Device 360, User 360 and Deployment Outcomes views with cross-links, timestamps, state details and decimal plus hexadecimal error codes.
18. Kept workload assignment configuration separate from reported operational state and marked unsupported modern outcome families explicitly.
19. Expanded the unit suite to 63 passing tests and passed the 1.3.0 full source, package and local-repository gates.
20. Recorded 80.58 per cent coverage, 13 clean exports, archive hash `b61620258d8e35498dd36b1961e166083feaccc75dfad97b8093a455927b16f8` and package hash `399b5f60bd32e282851b2d8dc89dab6f7f06d7406849755a3b5975c6602d65d7` for 1.3.0.
21. Added allow-listed local snapshots, SHA-256 integrity validation, stable identity pseudonymisation and structured evidence comparison for 1.4.0.
22. Added Snapshot Changes navigation and conservative broad-target user or device counts.
23. Added endpoint security intents to the shared workload assignment collector.
24. Added Settings Catalog, endpoint security intent and supported legacy profile value normalisation for 2.0.0.
25. Added Policy Settings and Policy Conflicts navigation with exact-target overlap evidence and explicit unevaluated states.
26. Expanded the unit suite to 72 passing tests before the 2.0.0 full release gate.
27. Removed reliance on `Publish-PSResource -WhatIf` after PSResourceGet 1.2.0 treated the dry-run command as a live publication.
28. Confirmed the PowerShell Gallery installation succeeds but identified that installation alone cannot execute module code or open sign-in.
29. Added `Start-IntuneAccess` for the guided 1.1.0 workflow: sign in, collect tenant-wide Intune RBAC-connected objects, generate the Signal Atlas explorer in Documents and open it automatically.
30. Limited tenant-wide user collection to direct and transitive members of Admin Groups connected to Intune role assignments; unrelated tenant users and groups are not enumerated.
31. Added report navigation for administrators, Admin Groups, role assignments, roles, Scope Groups, Scope Tags, permissions and review notes.
32. Added a clickable object inspector with cross-links between connected RBAC objects.
33. Fixed long administrator names and user principal names overflowing into adjacent metadata cells.
34. Passed 50 unit tests with 77.7 per cent measured coverage and no PowerShell Script Analyzer findings.
35. Adopted the versioned product roadmap from 1.1.0 through 2.0.0 and recorded it in `docs/roadmap.md`.
36. Reviewed recent `r/Intune` problem reports and recorded community led opportunities and the product value proposition in `docs/community-research.md`.
37. Passed the 2.0.0 full gate with 77 tests, 81.44 per cent coverage, 16 clean exports and no Script Analyzer findings.
38. Built the 89-entry `IntuneAccess.2.0.0.nupkg` and installed it through a temporary local PSResourceGet repository. Final hashes are written beside the release artefacts.
39. Generated the 2.0.0 source archive and SHA-256 checksum.
40. Checked Policy Conflicts, linked setting values and Snapshot Changes in the local browser at 1280 pixels without horizontal overflow.
41. Added a bounded 30-day Intune Audit Trail from Graph v1.0 and exact resource-ID correlation to snapshot changes.

## Next actions

1. Complete a clean least-privilege consent run using a dedicated Microsoft Entra application, or retain the documented shared-client limitation.
2. Submit the Awesome Intune directory form after approval.
3. Post the contribution in the Awesome Intune LinkedIn group after approval.
4. Complete live tenant validation of the locally implemented 2.0.0 collectors before any publication decision.
