# Limitations

The module is deliberately conservative.

## Tenant testing

The repository includes mocked unit tests. Six optional integration checks passed against a real test tenant with no Intune RBAC assignments. Positive live validation with known built in and custom role assignments remains outstanding. Mock data proves calculation behaviour but does not establish every tenant API response or tenant specific RBAC condition.

## Microsoft Graph beta

The current v1.0 role assignment model does not expose every property needed for the report. Scope tag IDs and richer scope type data are read through isolated beta endpoints. Audited resource and managed device scope tag IDs also use beta. Stable assignment and managed-device fields come from v1.0 and survive a beta enrichment failure.

Beta APIs can change. The module labels beta sourced objects and stops or returns `NotEvaluated` when required data is absent.

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

Version 0.2 targets Microsoft Graph in the global commercial cloud. The connection and URI design can be extended for sovereign environments, but those environments have not been validated.
