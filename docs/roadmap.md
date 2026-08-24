# IntuneAccess product roadmap

Last updated: 24 August 2026.

This roadmap records the agreed product direction after the first stable Gallery release. Planned versions may change when Microsoft Graph contracts, tenant validation or release testing show that a conclusion cannot be supported safely.

## Product direction

IntuneAccess will connect three questions in one local report:

1. Who can change an Intune object?
2. Who should receive it?
3. What happened when Intune processed it?

The module remains read only. It will distinguish confirmed evidence, calculated expectations, exclusions, conflicts, unavailable data and relationships that were not evaluated. It will not turn missing data into a successful or failed conclusion.

## Version 1.1.0

Status: implemented locally.

Complete and release the tenant wide RBAC explorer, including:

1. Guided sign in, tenant collection, report generation and local opening through `Start-IntuneAccess`.
2. Tenant wide RBAC navigation for administrators, Admin Groups, role assignments, roles, Scope Groups, Scope Tags, permissions and review notes.
3. Clickable cross references and an object inspector.
4. Improved wrapping for long administrator names and user principal names.
5. The Signal Atlas design with Space Grotesk and IBM Plex Mono.

## Version 1.2.0

Status: implemented locally.

Add the assignment and impact explorer for:

1. Configuration policies.
2. Compliance policies.
3. Endpoint security policies.
4. Applications.
5. PowerShell scripts and remediations.
6. Windows update policies.

The explorer now correlates included and excluded groups, broad targets and assignment filters. It records Graph API provenance and collection state per workload. User and device resolution, deployment outcomes and errors remain in the 1.3.0 work because a configured target alone does not prove delivery.

## Version 1.3.0

Status: implemented locally.

Device and User 360 views now contain:

1. Connected policies, applications, scripts, updates and group memberships.
2. Reported deployment outcomes.
3. Errors, conflicts, pending results and not applicable results.
4. Last check in evidence and relevant error details.
5. Links back to the administrator, role, scope and assignment evidence for each object.

The implemented operational layer covers managed-device inventory plus supported legacy configuration, compliance, application, PowerShell script and remediation device state. Modern Settings Catalog and update reporting remain explicitly `NotSupported` until a documented read contract is adopted. RBAC links remain available in the same explorer; a direct per-object RBAC scope conclusion is not claimed without complete scope evidence.

## Version 1.4.0

Status: implemented locally.

Add local snapshots, change comparison and impact summaries:

1. Save a sanitised local snapshot without credentials or access tokens.
2. Compare assignments, filters, settings, role assignments and scope tags between snapshots.
3. Summarise the users and devices potentially affected by a change.
4. Correlate supported Microsoft Intune audit evidence when it is available.
5. Produce a share safe change report with optional tenant and identity redaction.

## Version 2.0.0

Status: implemented locally; live tenant validation remains.

Add policy setting overlap and conflict analysis across Settings Catalog, endpoint security, security baselines and supported legacy profiles. The analysis will identify overlapping target populations and different configured values while retaining the source policy and setting evidence.

Version 2.0.0 will not claim the final value enforced on a device unless Microsoft Graph or device evidence supports that conclusion.

## Version 2.1.0

Status: planned.

Add device inventory and hygiene so administrators can find stale, duplicate, mismatched and incomplete device records.

1. Expand Device 360 with hardware, operating system, ownership, management agent, enrolment, compliance, registration, primary-user and evidence-age fields that Microsoft Graph returns reliably.
2. Reconcile Intune managed-device, Microsoft Entra ID device and Windows Autopilot identities without treating a missing match as proof that a record should be deleted.
3. Detect duplicate serial numbers, duplicate Microsoft Entra device IDs, inconsistent ownership, missing primary users and incomplete identity relationships.
4. Identify stale check-ins, recent enrolments without a healthy check-in, prolonged unknown states and devices without confirmed compliance policy evidence.
5. Add fleet search, filters, finding severity, evidence timestamps and CSV export.
6. Keep optional beta hardware enrichment isolated from the stable v1.0 inventory.

The release is complete when every hygiene finding contains the affected device, observed evidence, collection timestamp, rule used and a non-destructive review recommendation.

## Version 2.2.0

Status: planned.

Add a device assignment explainer that shows why a device received, missed or could not evaluate a policy or application.

1. Join the selected device to direct and transitive Microsoft Entra group membership.
2. Resolve included groups, excluded groups, broad targets, assignment intent and supported assignment filters.
3. Separate confirmed assignment, confirmed exclusion, calculated applicability, reported outcome and missing evidence.
4. Explain user-targeted and device-targeted paths independently.
5. Show the policy, application, script or update assignment beside its device outcome and evidence age.
6. Return `NotEvaluated` when membership, filter, requirement or reporting evidence is incomplete.

The release is complete when a selected device can display a source-to-outcome path without claiming that configured intent proves delivery.

## Version 2.3.0

Status: planned.

Add an optional Windows Autopilot and enrolment timeline showing profiles, Enrollment Status Page stages, durations, failures and enrolment evidence.

1. Reconcile Autopilot registration, managed-device identity, deployment profile and Enrollment Status Page profile.
2. Present registration, enrolment start, device preparation, device setup, account setup and desktop arrival as ordered evidence.
3. Retain deployment state, stage state, duration, timestamps and returned failure details.
4. Join supported Autopilot policy-status records to the related stage.
5. Label beta API provenance and unavailable stage evidence clearly.
6. Request `DeviceManagementServiceConfig.Read.All` only when the Autopilot feature is selected.

The release is complete when an Autopilot attempt can be reconstructed from returned evidence while client-only diagnostic gaps remain explicit.

## Version 2.4.0

Status: planned.

Add application and software evidence that joins required applications, installation results, detected software and errors.

1. Add detected application inventory with publisher, version, platform, device count and evidence timestamp.
2. Join selected-device application intent, assignment path and reported installation result.
3. Retain supported requirements, detection configuration, dependencies and supersedence relationships.
4. Explain documented error and return codes without turning a configuration risk into a confirmed root cause.
5. Compare required applications with detected software where identifiers support a dependable match.
6. State when Intune Management Extension or device diagnostics are required to continue an investigation.

The release is complete when application intent, reported state and detected evidence remain separate but can be inspected together.

## Version 2.5.0

Status: planned.

Add an update and compliance investigator that explains patch state, update targeting, compliance failures and stale reporting.

1. Join update rings, feature updates, expedited quality updates and driver policies to the selected device.
2. Show operating system build, reported update state, failure evidence and last report time where supported.
3. Identify devices that are behind and outside a confirmed update targeting path.
4. Show compliance policies, noncompliant settings, error states, not-applicable states and devices without confirmed compliance policy evidence.
5. Use local snapshots to show changes in update, compliance and evidence-age state.
6. Keep unsupported modern reporting contracts labelled rather than inferring results from configuration alone.

The release is complete when administrators can distinguish missing targeting, deployment delay, stale telemetry, returned failure and unavailable evidence.

## Version 3.0.0

Status: planned.

Add device estate intelligence with prioritised findings, historical trends and cross-device investigation.

1. Combine hygiene, assignment, Autopilot, application, update and compliance evidence into a prioritised finding model.
2. Support fleet-wide search by device, user, serial number, operating system, policy, application, error and finding.
3. Add historical trend views from local snapshots without introducing a hosted service or tenant-data upload.
4. Group recurring failures and shared evidence without claiming a common cause that the data cannot prove.
5. Compare cohorts such as model, operating system build, enrolment type and deployment profile.
6. Produce share-safe investigation bundles with stable pseudonyms and an explicit evidence boundary.
7. Add cross-device impact investigation for a selected policy, application, update or setting.

The release is complete when the report can prioritise an estate-level investigation and trace every finding back to its devices and source evidence.

## Deferred candidates

1. Optional licence-aware Endpoint Analytics enrichment.
2. Cross-tenant snapshot comparison.
3. User-supplied device diagnostic bundle analysis in a separately reviewed workflow.

These candidates are not committed to a release until their Graph support, permissions, privacy impact, performance and overlap with established tools have been reviewed.

The supporting gap research and evidence are recorded in `docs/product-opportunities.md` and `docs/community-research.md`.

## Release principles

1. Keep `Start-IntuneAccess` as the guided default experience.
2. Keep generated reports self contained and usable offline.
3. Request only documented Microsoft Graph read scopes needed by selected features.
4. Label beta API dependencies and partial collection clearly.
5. Validate large tenant behaviour before enabling a collector by default.
6. Publish only the exact package that passes the release and local repository gates.
7. Keep wipe, retire, delete, restart, sync and other remote actions outside the primary module so its delegated permissions remain read only.
