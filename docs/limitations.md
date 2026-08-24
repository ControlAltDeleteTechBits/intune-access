# Limitations

The module is deliberately conservative.

## Tenant testing

The repository includes mocked unit tests. Positive RBAC integration checks passed against a development tenant with built-in and custom role assignments. The device intelligence collectors added in 3.0.0 still require a maintainer comparison against representative production-like device, Autopilot, application, update and compliance evidence. Mock data proves calculation behaviour but does not establish every tenant API response or tenant-specific condition.

## Microsoft Graph beta

The current v1.0 role assignment model does not expose every property needed for the report. Scope tag IDs and richer scope type data are read through isolated beta endpoints. Audited resource and managed device scope tag IDs also use beta. Stable assignment and managed-device fields come from v1.0 and survive a beta enrichment failure.

Beta APIs can change. The module labels beta sourced objects and stops or returns `NotEvaluated` when required data is absent. Autopilot events, deployment profiles, Enrolment Status Page profiles, application relationships and some update contracts use beta.

## Device assignment explanation

The assignment explainer evaluates broad targets, transitive device and associated-user group membership, exclusions and a conservative subset of single-clause assignment filters. Compound expressions and properties absent from the collected device model remain `NotEvaluated`. The default fleet collection is limited to 250 devices to avoid an unbounded sequence of transitive membership reads; an exact device can be analysed separately.

Assignment configuration does not prove delivery. A reported outcome does not prove which assignment path produced it.

## Detected software and application evidence

Detected software uses the names and versions returned by Intune. An exact-name match is not proof that an Intune detection rule passed. Device relationships are limited to 500 detected-application queries in the default collector and any remainder is labelled `NotCollected`. Application error evidence can still require Intune Management Extension or application installer logs for root-cause analysis.

## Update and compliance evidence

Availability differs across update workload families. A version label can be compared with the reported device OS version, but this does not prove eligibility, safeguard holds, deadline state or successful installation. Compliance summary state is not setting-level evidence. Stale reporting is kept separate from returned failure.

## Estate findings

Priority scores are deterministic review aids, not risk predictions. Recurring failures group shared returned evidence and use `CauseState = NotAsserted`. Pseudonymised share-safe bundles can still contain sensitive configuration and should be handled accordingly.

## Scoped permissions setting

Microsoft introduced an opt in Scoped permissions behaviour in March 2026. The module does not use an undocumented endpoint to discover the tenant setting. It keeps assignment scope with every permission source and models legacy and Scoped outcomes separately. The active mode remains `Unknown` unless the caller explicitly supplies it. The model is not a substitute for the Intune Permissions Assessment Report.

## Nested administrator groups

Nested Admin Group behaviour depends on Intune licensing and tenant configuration. The module records nested membership but does not confirm it as an effective assignment.

Microsoft Entra hidden group membership requires the additional `Member.Read.Hidden` delegated permission. The default connection does not request it. If an Intune Admin Group has hidden membership, the observed membership set can be incomplete and the module might not identify that assignment.

## Microsoft Entra roles

Microsoft Entra administrative roles are outside the current model. An Intune Administrator can have access that this module does not report. This is one reason the managed-device explanation never returns access denied.

## Scope tag audit coverage

The base audit covers stable v1.0 objects with beta scope-tag enrichment for:

1. Role assignments.
2. Classic device configurations.
3. Mobile apps.

It does not cover every Intune policy, script, remediation, security policy or enrolment resource. An apparently unused scope tag may be used on an object family that was not examined.

The optional extended audit also covers:

1. Compliance policies using v1.0 identity and beta scope-tag enrichment.
2. Settings Catalog and endpoint security policies using beta.
3. Remediations and device health scripts using beta.

The extended audit requires `DeviceManagementScripts.Read.All`. It still does not examine every Intune resource family.

## Managed device explanation

The managed-device explanation supports exact device names and one required action at a time. Duplicate names stop the command. It does not evaluate:

1. Microsoft Entra administrative roles.
2. Associated-user scope when the managed device has no resolvable `userId` or membership data.
3. Every licensing condition.
4. Unsupported or missing Graph scope data.
5. Reverse queries such as who can manage a device.

## Global commercial cloud

Version 3.0.0 targets Microsoft Graph in the global commercial cloud. The connection and URI design can be extended for sovereign environments, but those environments have not been validated.
