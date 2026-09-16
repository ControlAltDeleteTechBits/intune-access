# IntuneAccess V4 implementation and acceptance record

Status: V4 implementation and validation recorded. Publication is a separate authorised step.

## Objective

Implement all five capabilities agreed on 15 September 2026. Test locally, then obtain the user's local test feedback before GitHub or PowerShell Gallery publication. Browser sign-in does not establish a delegated Graph session; verify the session and tenant before live reads. No tenant fixtures or write permissions are authorised by this objective.

## Required capabilities and evidence

The user approved four endpoint investigation packs for V4: application detection correction proposals, update policy ownership and migration plans, policy residue ownership investigation, and working/affected endpoint comparison. Vendor-specific application migration is deferred to the roadmap and excluded from the exported script library. No vendor choice is required for V4. Scope and acceptance criteria are in `mvp-investigation-standard.md`. These are additional requirements, not replacements for the five original capabilities below.

1. Findings centre: resolution guides for every supported finding with affected objects, evidence, impact, checks, suggested action and verification. Include policy conflicts, missing required application results and remediation findings. Local expected dispositions require reason, review date and tenant isolation. Prove with unit fixtures and interactive HTML checks.
2. Reviewed script library: small versioned PowerShell library with detection, separate remediation where appropriate, exact changes, prerequisites, context, verification and recovery. Export only; never execute or upload. Test scripts with mocks and inspect exported packages, encoding and hashes. Label exports as change making when applicable.
3. Remediation effectiveness: retain separate detection and remediation states and script errors, execution time and expected execution time. Compare distinct observations across snapshots for recurrence, persistent errors and changed results. Missing or stale data cannot prove success. Test positive, negative, unknown, duplicate and stale cases.
4. Change plans: selected findings produce local review documents containing current evidence, proposed action, bounded potential impact, pilot recommendation, risks, prerequisites, verification and recovery. Verify selection, escaping and offline exports.
5. Verification: compare before and after evidence and age. Distinguish persisted, positively cleared and not evaluable. Missing devices, failed collection, incompatible tenants and stale observations must not become resolved. Verify through adversarial snapshot fixtures.

## Invariants

Read permissions only. No remote actions, execution of exported scripts, automatic uploads or apply controls. Script exports are separate artefacts for administrator review and external deployment. Report data and local decisions are sensitive. Never claim pseudonymisation guarantees anonymity. Existing tenant reports must not enter packages or public screenshots.

## Delivery gates

All unit tests, syntax checks, ScriptAnalyzer, clean import, report browser checks, isolated Gallery style installation and exact package checks must pass. Update documentation and version metadata consistently for the local candidate. Live read validation must state unavailable scenarios honestly. Provide local commands and synthetic screenshots for user review. Publication remains deferred until the user tests and approves.

## Validation summary

Default delegated read permissions were verified in an isolated application and fresh process. Read-only collection, HTML generation and snapshot export completed successfully. The temporary application was removed after validation. Private authentication history, tenant observations and local evidence paths are excluded from the public record.

The owner confirmed the principal HTML workflows. Separate-device incident testing was waived, not passed. Application detection parity, effective update-source ownership and real remediation before/after results remain unverified. See `v4-release-audit-current.md` for the current evidence boundary and `endpoint-investigations.md` for supported behaviours.
