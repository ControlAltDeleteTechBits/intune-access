# V4 release readiness audit

16 September 2026. Default-permission collection and owner HTML acceptance are complete. Publication is a separate authorised step. Final artefact gate receipts and hashes are retained in the release handover outside the package to avoid self-referential hashes. This audit preserves the original five action-centre capabilities and four approved investigation packs; application migration remains deferred.

## Release-owner decision and subsequent evidence

The release owner chose to skip separate-device testing on 16 September 2026. Controlled endpoint incident checks below remain unverified but are no longer release blockers. Do not describe them as passed.

A controlled unassigned configuration fixture passed exact definition/value collection checks. This validates collection only, not targeting, enforcement or remediation. Private fixture details are excluded.

On 16 September the release owner approved the appearance of the current synthetic V4 report and confirmed Script Library ZIP download, evidence imports, saved decisions after refresh and change-plan exports worked. This is user-reported manual acceptance, not automated browser evidence. Browser version, invalid-file recovery, keyboard traversal and narrow-window behaviour were not individually confirmed.

A fresh PowerShell process authenticated through an isolated temporary application with exactly the nine documented default Graph read scopes plus standard identity scopes. Read-only collection and HTML/snapshot exports completed. The process disconnected and exited successfully. Optional Autopilot was not included. No failed collection state was recorded. Unsupported sources remained NotSupported. Available can include zero records and does not prove positive incident coverage.

The temporary registration was deleted using the normal portal flow after validation. The portal confirmed successful deletion. Its associated enterprise application returned Not found, error 404. No permanent purge was performed and the shared Microsoft Graph Command Line Tools application was unchanged. Private tenant identifiers and receipts remain outside public artefacts.

The table below records the preceding technical checkpoint; its controlled-incident requirements and browser status must be read with the updates above. It is not final release approval.

| Requirement | Evidence inspected | Current verdict and required work |
| --- | --- | --- |
| Findings centre and resolution guides | ActionCentre.Tests.ps1; Get-IntuneAccessActionCentre.ps1; action-centre.html | Fixture coverage exists; manual guide, navigation, keyboard and long-name acceptance remains |
| Expected decisions and selected change plans | action-centre.html; ActionCentre.Tests.ps1; owner confirmation on 16 September | Persistence after refresh, evidence imports and change-plan exports manually confirmed by the owner; additional negative-path/browser-compatibility coverage is not asserted |
| Reviewed export-only library | RemediationLibrary.Tests.ps1; isolated package generation | Six entries; migration excluded from library and installable Gallery staging, source retained in Git. Package hashes tested. Final package must be regenerated after acceptance |
| Remediation effectiveness and before/after verification | RemediationEffectiveness.Tests.ps1; FindingVerification.Tests.ps1; live checkpoint | Positive and failure fixtures exist; positive live remediation history was not validated, so positive live recurrence and clearing remain unverified |
| Application investigation | ApplicationRuleImport.Tests.ps1; ApplicationContext.Tests.ps1; EndpointInvestigations.Tests.ps1; earlier package PS5.1 smoke | Registry comparisons, proposal export, literal file/folder existence and regular file-version comparisons tested. Real executable metadata read locally without executing it. Combined imported detection and correction proposals require matching SYSTEM or selected-user context. Expanded paths, file dates and sizes remain unsupported; Intune comparison parity and UI acceptance remain. Positive live application incident validation was not completed |
| Update investigation | EndpointInvestigations.Tests.ps1; UpdatePolicyReview.Tests.ps1; local collector run | Per-class plans, cached RSoP candidates and snapshot policy/assignment joins tested, including standalone exported ZIP. Exact setting mappings are administrator supplied. Real policy mapping and effective-source incident validation remain outstanding |
| Policy residue | PolicyHistory.Tests.ps1 | Snapshot joins and named quality/feature update CSP configurations tested. Supplied mappings need validation and a real controlled history case; no cleanup authorisation is inferred |
| Working/affected comparison | EndpointInvestigations.Tests.ps1; AdditionalDeviceEvidence.Tests.ps1; local metadata smoke | Context/age/missing-data handling and optional sources tested. A separate working reference and real incident correlation remain unverified |
| Read-only permissions | GET transport; fresh isolated application and process on 16 September | Exact default scopes verified and functional collection/export completed. Optional Autopilot and all possible tenant configurations are not claimed |
| HTML runtime, no network, screenshots | Static JavaScript compile; user manual acceptance; recorded URL security restriction | Owner confirmed report appearance and key interactions. Network isolation is not proven by that confirmation. Do not bypass the recorded browser restriction via another surface or URL |
| Release/package/install gates | Latest source gate: 213 tests, 80.44% coverage, no analyser findings. Earlier exact nupkg installed locally | These are checkpoints, not final acceptance. Regenerate and validate final packages after all acceptance work |
| PowerShell compatibility | 213 tests passed on isolated PowerShell 7.0.13 with Graph Authentication 2.39.0 and Pester 5.7.1; also passed on current runtime | Older-runtime tests exposed and verified fixes for README metadata serialisation and signed error-code formatting. Snapshot/helper/ZIP tests pass. This is offline fixture coverage, not live Graph authentication coverage or proof for every intervening runtime version |
| Final documentation and user approval | RELEASE_NOTES.md; this audit; owner acceptance | Completed validation and remaining limits recorded. Publication is a separate approval; nothing published by this validation workflow |

## Test environment needs

Positive application, remediation and affected/reference incident validation remains unverified. Collection success does not prove successful deployment or remediation. Do not create assignments, install applications or run remediation solely to obtain a passing result without an agreed test scope.

## Release handover and future validation

Controlled incident checks in the historical table remain future validation work under the owner's waiver. Real update definition/value collection and principal manual report/export acceptance are now complete as described above. Snapshot timestamp preservation has regression coverage, including the compatibility parser. Rebuild and pass Test-Release.ps1, Test-IntuneAccessGalleryPackage.ps1 and Test-IntuneAccessLocalRepository.ps1, then retain the exact source ZIP and nupkg hashes with the gate receipts. Publish only the exact verified package after separate approval. Do not treat fixture coverage as proof of endpoint remediation success.
