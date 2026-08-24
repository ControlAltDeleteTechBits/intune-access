# IntuneAccess 3.0.0

IntuneAccess 3.0.0 completes the agreed read-only device investigation roadmap. Signal Atlas now connects device record quality, assignment paths, enrolment, applications, updates, compliance and estate-level findings with the existing RBAC and policy evidence.

## Quick start

Run both commands in PowerShell 7:

```powershell
Install-Module -Name IntuneAccess -Scope CurrentUser
Start-IntuneAccess
```

`Start-IntuneAccess` opens delegated Microsoft sign-in, collects the default read-only evidence, creates a self-contained Signal Atlas report in Documents and opens it in the default browser.

Autopilot evidence is optional because it uses Microsoft Graph beta and requests `DeviceManagementServiceConfig.Read.All`:

```powershell
Start-IntuneAccess -Feature Core, AssignmentExplorer, OperationalEvidence, PolicyAnalysis, AuditEvidence, DeviceIntelligence, ApplicationEvidence, UpdateCompliance, EstateIntelligence, Autopilot
```

## Device inventory and hygiene

1. Adds enriched inventory with Intune and Microsoft Entra identity correlation, OS, ownership, management, enrolment, compliance, user and evidence-age fields.
2. Finds stale or missing check-ins, duplicate serial numbers, duplicate Microsoft Entra device identifiers, missing primary-user evidence and unknown compliance state.
3. Reports mismatched OS versions and unresolved or ambiguous identity correlation.
4. Keeps every finding traceable to the device, observed values, evidence timestamp, rule and a non-destructive review recommendation.

## Device assignment explanation

1. Resolves transitive device and associated-user Microsoft Entra group membership independently.
2. Evaluates broad targets, included groups, excluded groups and assignment intent.
3. Evaluates supported single-clause assignment filters and uses `NotEvaluated` for compound or unsupported rules.
4. Separates configured assignment, calculated applicability, exclusion, reported outcome and missing evidence.
5. Adds a fleet collection with an explicit collection limit and an exact-device public command.

## Autopilot and enrolment timeline

1. Correlates Autopilot identities with Intune managed devices by managed-device ID, serial number or Microsoft Entra device ID.
2. Shows deployment profile assignment, registration and returned enrolment events.
3. Normalises device preparation, device setup and account setup states and durations.
4. Retains failure details and beta provenance.
5. Treats missing stages as unavailable evidence rather than proof that a stage did not run.

## Application and software evidence

1. Joins application assignment intent, reported installation results and detected software by device.
2. Includes publisher, version, platform, device count and evidence timestamp where returned.
3. Retains requirements, detection rules, dependencies and supersedence relationships from supported application contracts.
4. Keeps exact-name detection separate from an Intune detection-rule result.
5. States when device-side client or Intune Management Extension logs can still be required.

## Update and compliance investigation

1. Joins update and compliance workloads with configured targets, managed-device OS state, returned outcomes and evidence age.
2. Separates missing targeting, stale reporting, target-version difference, returned failure and unavailable evidence.
3. Preserves compliance summary evidence without treating it as setting-level proof.
4. Includes all new datasets in local snapshot comparison.

## Device estate intelligence

1. Ranks traceable findings with a deterministic priority score.
2. Groups devices that share returned failure evidence without claiming a shared root cause.
3. Builds cohorts by model, OS version, enrolment type and management agent.
4. Supports cross-device investigation by workload or evidence source.
5. Uses local snapshot comparison for historical changes and returns `NoBaseline` when none is supplied.
6. Produces a stable pseudonymised share-safe bundle while retaining the evidence boundary.

## Signal Atlas and exports

Signal Atlas adds sections for Estate Intelligence, Recurring Evidence, Device Cohorts, Cross-Device Investigation, Device Hygiene, Assignment Explainer, Autopilot Timeline, Application Evidence, Detected Software, and Update and Compliance. The report remains self-contained and has no remote assets or tracking.

JSON export accepts every new evidence result. CSV export supports device inventory, hygiene findings, assignment explanations, application evidence, update and compliance investigations, estate findings, recurring evidence groups and cohorts.

## Evidence boundary

A configured assignment does not prove delivery. A reported result does not prove which assignment path produced it. Exact-name software detection does not prove that an Intune detection rule passed. Shared errors do not prove a shared root cause. Hygiene findings are review prompts and never remote actions.

IntuneAccess remains read only. It contains no wipe, retire, delete, restart, sync or other device-changing command and requests no Microsoft Graph write permission.

## Validation evidence

1. Ninety-nine unit tests cover the original module and the 3.0 device evidence model, with 79.58 per cent command coverage.
2. A separate no-profile PowerShell process imports all 22 intended public commands.
3. PowerShell Script Analyzer returns no findings with the checked-in settings.
4. The self-contained explorer passed desktop and 390-pixel responsive inspection.
5. The exact Gallery package must pass isolated import and temporary local PSResourceGet installation before publication.
6. A representative live tenant run completed with four managed devices, 137 detected applications, 88 assignment explanations, eight update and compliance investigations and ten prioritised findings. Missing workload API-version metadata is retained as `NotReturned`.

Use a non-production tenant first. Review Graph consent, collection warnings, beta provenance and evidence age before relying on a result for an administrative decision.
