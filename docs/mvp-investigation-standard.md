# Investigation pack product standard

Scope decision: 15 September 2026. The user approved four investigation packs for V4 and deferred vendor-specific application migration to the roadmap. The four packs shipped in 4.0.0 with the validation limits recorded in v4-release-audit-current.md.

## Product promise

Explain a specific Intune support incident using tenant configuration and fresh endpoint evidence, identify the next justified action, and help the administrator verify the result. IntuneAccess remains read-only. Corrections are reviewed exports or portal instructions, never automatic tenant actions.

An additional inventory view is not sufficient. Microsoft already supplies application inventory, deployment reports and diagnostic tools. Our contribution is a reproducible, evidence-linked explanation across those sources, with explicit limits and a portable support handover.

## Four approved V4 packs

| Pack | First deliverable | Acceptance example |
| --- | --- | --- |
| Application detection | Import supported rules from the selected Win32 application, preserve comparisons and rule combinations, compare exact file/registry evidence in the stated context, export a proposed corrected rule | A deliberately wrong registry view produces an explainable mismatch; missing evidence never becomes an installation success |
| Update migration | Show intended source by update class, local observations, policy ownership and a source-policy correction plan | Mixed WSUS and Windows Update configuration is explained per class; unknown ownership blocks cleanup |
| Policy residue | Support a small named set of CSP settings with documented removal behaviour, earlier tenant evidence and local observations | A still-targeted setting is not called residue; absent historical evidence yields an ownership question, not a registry deletion |
| Working/affected comparison | Correlate same-scenario evidence with collection time, user context and device identity; produce a bounded difference report and support bundle | Context or age mismatches are prominent; differences alone never establish causation |

## Deferred roadmap: application migration

Vendor-specific application migration is excluded from V4 acceptance and from the exported script library. Existing development source is retained, not advertised as a working migration adapter. A future adapter requires verified product identity, supported installation, settings preservation, replacement health checks, rollback and real scenario tests. No vendor selection is needed for V4. Certificate and device-registration evidence would strengthen the comparison pack before adding unrelated scripts.

## Two strong follow-on cases

1. Certificate delivery versus usability: compare the assigned certificate and Wi-Fi/VPN requirements with bounded local certificate metadata, store, validity and relevant delivery events. Distinguish missing delivery, expired certificate and requirement mismatch. Do not export private keys, delete certificates or claim successful authentication from certificate presence.
2. Device trust versus Intune health: compare local registration status and identifiers with the corresponding Entra and Intune objects. Explain a deleted or disabled device separately from absent MDM evidence and a failed diagnostic query. Never recommend automatic disconnect, rejoin or token-cache deletion. This addresses a common class of sign-in incident in which portal and device state disagree.

Entra.News also suggests a useful future assignment-dependency review: link risky or changing group rules to the Intune workloads that depend on them. Do not implement a retirement deadline from newsletter text alone; confirm official guidance first. Broad identity governance belongs in IdentityAtlas.

## Shipping requirements

1. Document supported OS, execution context, permissions, licences and evidence sources.
2. Include an original positive fixture, negative fixture, missing-data case and context mismatch case.
3. Validate on a real affected endpoint and a reference endpoint where the scenario requires two devices. One available machine does not prove this.
4. Show each finding's evidence, age, confidence, alternative explanation and next check.
5. Keep diagnosis, proposed correction, applied action and verified outcome as separate states.
6. Any exported change includes exact scope, preconditions, preview, backup where applicable, rollback and post-checks. No broad resets.
7. Exclude secrets and minimise personal data in exported support bundles. Keep endpoint evidence outside source control.
8. Retain a native Intune alternative and explain the extra benefit of this pack.

## Research sources and boundaries

Published Intune and identity books were consulted for investigation topics only: application detection, certificate delivery, legacy update ownership and access-event analysis. No book text, scripts or examples were copied into the product. Behaviour is always checked against current Microsoft documentation.

Current primary references:

1. [Win32 application configuration and detection](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32)
2. [Native Intune application inventory](https://learn.microsoft.com/en-us/intune/app-management/deployment/enhanced-app-inventory)
3. [Windows update scan sources](https://learn.microsoft.com/en-us/windows/deployment/update/wufb-wsus), including the recommendation to configure Group Policy or CSP rather than write registry values directly.
4. [Device registration diagnostic fields](https://learn.microsoft.com/en-us/entra/identity/devices/troubleshoot-device-dsregcmd), including the distinction between an unhealthy device and a test that could not run.
5. [Entra.News group dependency discussion](https://entra.news/p/microsoft-entra-memberof-retirement), used for topic discovery, not as proof of tenant impact or a verified deadline.

## Local validation at release

All five collector modes and their reviewers executed under Windows PowerShell 5.1 using process-only RemoteSigned. The application and residue runs used example paths and exercise absent-data behaviour. No real repair was tested. No permanent execution policy, tenant setting or device configuration was changed. The prior 135-test release result is separate from these new smoke tests. UI acceptance and full scenario validation remain outstanding.
