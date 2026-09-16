# V4 local acceptance testing

Version 4.0.0 validation workflow. Default-permission collection and principal owner HTML acceptance are recorded below. Controlled endpoint incidents remain unverified under the owner's waiver; publishing is a separate authorised step.

## Import a local checkout

Use PowerShell 7. The explicit path selects the local development copy rather than the Gallery installation. After public release, users will not need this development path.

```powershell
Remove-Module IntuneAccess -Force -ErrorAction SilentlyContinue
# Run from the root of your local IntuneAccess checkout.
Import-Module (Join-Path (Get-Location) 'IntuneAccess.psd1') -Force
Get-Module IntuneAccess | Select-Object Name, Version, Path
$documents = [Environment]::GetFolderPath('MyDocuments')
$baseline = Join-Path $documents 'IntuneAccess-v4-baseline.json'
Start-IntuneAccess -SnapshotPath $baseline
```

Complete Microsoft Graph sign-in when prompted and check that the report identifies your intended tenant. Signing into the portal does not establish a Graph SDK session. Review the requested read permissions; stop if the tenant or permissions are unexpected. The baseline contains sensitive tenant evidence. Choose a different filename for another test rather than overwriting your baseline.

## Manual HTML checks

1. Open Findings Centre. Expand a resolution guide and check affected objects, evidence time, impact, checks, suggested fix, prerequisites, pilot, risks, verification and recovery.
2. Select one finding and export its change plan. Confirm the document contains that finding, not every finding. Check its source values against the report.
3. Mark a finding expected with a reason and future review date. Reload the report and confirm the decision remains. Return it to review and confirm the finding itself is not deleted. Local file browser storage may vary; export decisions before clearing browser data.
4. Open Remediations. Confirm detection and remediation states are separate. A reported successful remediation must not claim the problem is resolved. Empty or unavailable data must remain explicit.
5. Open Script Library. Read the package notes, acknowledge the review requirement and export a ZIP. Inspect Detect.ps1, README.md, SHA256SUMS.txt and, for the service package only, Remediate.ps1. Do not execute scripts during this report acceptance test.
6. Check long names, keyboard navigation, search, empty views and a narrow browser window. Send screenshots and exact errors for anything unclear or broken.

Browser automation was blocked from opening the local file under its URL policy. On 16 September 2026 the release owner approved the synthetic report's appearance and confirmed ZIP download, evidence imports, decision persistence after refresh and change-plan exports worked. These are user-reported manual results, not an automated browser run. Browser version, invalid-file recovery, keyboard traversal and narrow-window behaviour were not individually confirmed.

## Later evidence and verification

After collecting genuinely newer evidence, use the earlier baseline:

```powershell
$current = Join-Path $documents 'IntuneAccess-v4-current.json'
Start-IntuneAccess -BaselineSnapshotPath $baseline -SnapshotPath $current
```

Open Verification. Persisted means the finding remains in the later collection, not that another execution occurred. ObservationCleared means newer positive evidence clears that particular observation; it does not prove an external change caused it or all problems are fixed. NotEvaluated means evidence is insufficient, unavailable, stale or the exact device is missing. A successful application result matched only by name cannot clear a device-specific finding.

Remediation history compares distinct execution timestamps, not the number of exported files. Re-exporting the same execution cannot count as recurrence. Policy verification needs both source policies and fresh collection coverage. Some observations cannot be positively cleared from currently available evidence and remain NotEvaluated.

Use the same tenant and identity mode for both snapshots. Redacted snapshot script outputs are pseudonymised and are unsuitable for reading raw error details. Treat full and pseudonymised reports as sensitive; review before sharing.

## Release conditions

On 16 September 2026, the release owner waived separate-device incident validation. Record that limit without claiming endpoint parity, effective enforcement or successful remediation. Application migration remains deferred. This waiver does not waive browser acceptance, minimum-permission verification or final package checks.

Default-permission validation completed on 16 September in a fresh process using an isolated temporary application: exactly nine default Graph read scopes, successful read-only collection and HTML/snapshot exports. No failed collection state was recorded; unsupported workload outcome sources remained explicitly NotSupported. Optional Autopilot was not included. The temporary application was subsequently deleted and its enterprise application returned Not found.

No GitHub push or Gallery publication until final artefact gates are recorded and publication is authorised. No tenant test objects, assignments or remediation actions are created by this test workflow. See v4-release-audit-current.md for the accepted validation limits.
