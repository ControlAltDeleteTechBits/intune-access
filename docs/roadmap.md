# IntuneAccess product roadmap

Last updated: 18 August 2026.

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

## Candidate work after version 2.0.0

1. Autopilot and enrolment evidence timelines.
2. Application detection, requirement, dependency and supersedence troubleshooting.
3. Tenant health and hygiene findings.
4. Optional licence aware Endpoint Analytics enrichment.
5. Cross tenant snapshot comparison.

Candidate work is not committed to a release until its Graph support, permissions, performance and overlap with existing community tools have been reviewed.

The supporting gap research and evidence are recorded in `docs/product-opportunities.md` and `docs/community-research.md`.

## Release principles

1. Keep `Start-IntuneAccess` as the guided default experience.
2. Keep generated reports self contained and usable offline.
3. Request only documented Microsoft Graph read scopes needed by selected features.
4. Label beta API dependencies and partial collection clearly.
5. Validate large tenant behaviour before enabling a collector by default.
6. Publish only the exact package that passes the release and local repository gates.
