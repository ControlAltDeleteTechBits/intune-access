# Endpoint investigation expansion

Status: four V4 investigation packs in development, not completed repair solutions. Application migration is deferred. Nothing from this expansion has been published.

The library contains four new export-only investigation entries alongside the existing service and disk-space packages, six entries in total. Each investigation includes a Windows PowerShell 5.1-compatible source collector, JSON example, evidence reviewer and comparison script. All collection modes and their reviewers have executed on one local Windows PowerShell 5.1 host. This is a smoke test, not verification of every supported fault scenario or execution context. Earlier five-mode results below include the now-deferred user application prototype.

## Implemented

1. Application detection: exact local file existence/version and exact registry-value observations, both registry views, alternative-view mismatch proposals. The package imports Graph application rule metadata for named registry string-equality, integer and regular version rules with preserved operators. The report now offers a collected-application selector and metadata export, disabled when no detection rules were collected. The collector retains the modern rules collection and export omits script bodies and installer commands. Unsupported rules remain NotEvaluated blockers. Source-checked alternative-view proposals are supported for string equality. Custom scripts and MSI detection are not executed. Browser acceptance, file-rule import, version fallback semantics and live Intune parity validation remain outstanding.
2. Update migration: compare explicit per-category source values in local policy stores with administrator-supplied expected sources; distinguish missing and conflicting evidence. Collect bounded computer RSoP update records and the class-source switch. Review output includes per-class CSP and Group Policy locations, recorded GPO candidates, proposed source values, verification and recovery instructions. Cached records do not prove current enforcement. Current tenant policy association and live effective-source validation remain outstanding; no automatic cleanup.
3. Policy residue: collect exact selected registry values and require ownership review. Analyst-side PowerShell 7 history review now joins explicit workload/setting IDs with integrity-checked full-identity schema 2.0 snapshots. It distinguishes current targeting, still-configured settings, possible residue and inconclusive collection. No inference of tattooing from presence alone. Administrator mapping and setting-specific removal contract verification remain required.
4. Working/affected comparison: compare bounded OS, update-source, service and registered-application facts. Optional certificate and event metadata adapters are now included and disabled by default. They retain collection limits and omit certificate subjects/SANs/private key material and event message/XML bodies. Comparison provides source-specific next checks; different certificate identities or event windows are not faults by themselves. Missing facts remain NotEvaluated. Differences are not automatically causes or resolution.

Deferred prototype: user application inventory can identify possible parallel installations by display name and publisher. It is not a vendor-specific migration adapter. Source is retained for future work but the migration entry is not offered in the V4 library.

The HTML Script Library can import review/comparison JSON locally. It renders untrusted content as text, limits input size/row count, does not upload or persist the data and does not merge unverified endpoint identities into tenant findings. This is a preview interface; manual browser verification is outstanding.

## Required before calling the expansion complete

1. Integrate selected tenant application export with the report; extend supported comparison semantics beyond named registry string equality and test real tenant rules. The new importer and correction artefact have fixture coverage, not live affected-application proof. Unsupported conditions must remain explicit blockers.
2. Produce an update policy ownership and correction plan first. Microsoft recommends Group Policy or CSP configuration rather than direct registry edits. Any later setting-specific cleanup export requires verified orphaned ownership, preconditions, backup and rollback. Active or unknown Group Policy or Configuration Manager ownership must block local cleanup.
3. Choose and document specific policy settings; connect current and earlier tenant evidence to local observations. Do not build a universal registry resetter.
4. Add relevant certificate/event adapters and reviewed associations between differences and corrections. Make evidence age, context mismatch and identity limitations prominent.
5. Validate collectors externally on real Windows endpoints using an approved script execution method. Add direct collector failure-path tests, schema validation and UI acceptance tests.

## Validation checkpoint





The generated release-gate ZIP predates this documentation and is not approved for publication. Regenerate all release/package artefacts after completing the work and acceptance testing.

Public validation summary: source, package import and isolated installation checks passed. Exported collectors have fixture and local runtime coverage, not proof of Intune agent parity or a successful repair. Private endpoint observations and execution paths are excluded. See v4-release-audit-current.md for current validation limits.
