# Microsoft Graph permissions

This matrix was checked against Microsoft Learn on 24 August 2026. All permissions are delegated and read only.

| Feature | Endpoint | Delegated permission | Reason |
| --- | --- | --- | --- |
| Sign in and tenant label | `/organization` | `User.Read` | Reads the organisation ID, display name and verified domain values available to the signed in user. |
| Target user lookup | `/users/{id or UPN}` | `User.Read.All` | Resolves another administrator. |
| Direct group membership | `/users/{id}/memberOf/microsoft.graph.group` | `User.Read.All`, `GroupMember.Read.All` | Establishes direct Admin Group evidence and readable group details. |
| Transitive group membership | `/users/{id}/transitiveMemberOf/microsoft.graph.group` | `User.Read.All`, `GroupMember.Read.All` | Identifies nested membership without treating it as confirmed Intune access. |
| Direct Admin Group users | `/groups/{id}/members/microsoft.graph.user` | `User.Read.All`, `GroupMember.Read.All` | Enumerates direct users only from Admin Groups connected to Intune role assignments. |
| Transitive Admin Group users | `/groups/{id}/transitiveMembers/microsoft.graph.user` | `User.Read.All`, `GroupMember.Read.All` | Finds nested users within connected Admin Groups while retaining nested membership as `NotEvaluated`. |
| Group details | `/groups/{id}` | `GroupMember.Read.All` | Resolves Admin Group and Scope (Groups) display names. |
| Intune role definitions | `/deviceManagement/roleDefinitions` | `DeviceManagementRBAC.Read.All` | Reads built in and custom roles and exact allowed actions. |
| Intune role assignments | `/deviceManagement/roleDefinitions/{id}/roleAssignments` on v1.0 | `DeviceManagementRBAC.Read.All` | Reads stable assignment identity, administrator group IDs and resource scope IDs. |
| Role assignment enrichment | `/deviceManagement/roleDefinitions/{id}/roleAssignments` on beta | `DeviceManagementRBAC.Read.All` | Adds scope type, scope members and scope tag IDs. A failure leaves the v1.0 assignment available with missing-data states. |
| Scope tags | `/deviceManagement/roleScopeTags` | `DeviceManagementRBAC.Read.All` | Resolves scope tag IDs. Beta endpoint. |
| Legacy configuration assignments | `/deviceManagement/deviceConfigurations/{id}/assignments` | `DeviceManagementConfiguration.Read.All` | Reads included, excluded, broad and filtered assignment targets through v1.0. |
| Compliance assignments | `/deviceManagement/deviceCompliancePolicies/{id}/assignments` | `DeviceManagementConfiguration.Read.All` | Reads configured compliance policy targets through v1.0. |
| Application assignments | `/deviceAppManagement/mobileApps/{id}/assignments` | `DeviceManagementApps.Read.All` | Reads application intent and assignment targets through v1.0. |
| Settings Catalog assignments | `/deviceManagement/configurationPolicies/{id}/assignments` | `DeviceManagementConfiguration.Read.All` | Reads Settings Catalog and modern endpoint security targets. Beta endpoint. |
| Endpoint security intent assignments | `/deviceManagement/intents/{id}/assignments` | `DeviceManagementConfiguration.Read.All` | Reads targets for endpoint security intents and security baselines. Beta endpoint. |
| Settings Catalog values | `/deviceManagement/configurationPolicies/{id}/settings` | `DeviceManagementConfiguration.Read.All` | Reads setting instances for overlap analysis. Beta endpoint. |
| Endpoint security intent values | `/deviceManagement/intents/{id}/settings` | `DeviceManagementConfiguration.Read.All` | Reads intent setting instances for overlap analysis. Beta endpoint. |
| Legacy configuration properties | `/deviceManagement/deviceConfigurations/{id}` | `DeviceManagementConfiguration.Read.All` | Reads returned non-null profile properties through v1.0 for conservative comparison. |
| Recent Intune audit events | `/deviceManagement/auditEvents` | `DeviceManagementApps.Read.All` | Reads the previous 30 days of reported Intune audit activity and resource identifiers through v1.0. |
| Script assignments | `/deviceManagement/deviceManagementScripts/{id}/assignments` | `DeviceManagementScripts.Read.All` | Reads PowerShell script targets. Beta endpoint. |
| Remediation assignments | `/deviceManagement/deviceHealthScripts/{id}/assignments` | `DeviceManagementScripts.Read.All` | Reads remediation targets and schedule evidence. Beta endpoint. |
| Windows update profile assignments | `/deviceManagement/windowsFeatureUpdateProfiles/{id}/assignments`, `/windowsQualityUpdateProfiles/{id}/assignments`, `/windowsDriverUpdateProfiles/{id}/assignments` | `DeviceManagementConfiguration.Read.All` | Reads feature, expedited quality and driver update policy targets. Beta endpoints. |
| Assignment filters | `/deviceManagement/assignmentFilters` | `DeviceManagementConfiguration.Read.All` | Resolves filter IDs, platforms and rules used by collected assignments. Beta endpoint. |
| Device configurations | `/deviceManagement/deviceConfigurations` on v1.0 and beta | `DeviceManagementConfiguration.Read.All` | Reads stable IDs and names from v1.0, then adds beta scope tag properties for one audited resource family. |
| Mobile apps | `/deviceAppManagement/mobileApps` on v1.0 and beta | `DeviceManagementApps.Read.All` | Reads stable IDs and names from v1.0, then adds beta scope tag properties for one audited resource family. |
| Compliance policies | `/deviceManagement/deviceCompliancePolicies` on v1.0 and beta | `DeviceManagementConfiguration.Read.All` | Reads stable IDs and names from v1.0, then adds beta scope tag properties for the extended audit. |
| Settings Catalog and endpoint security policies | `/deviceManagement/configurationPolicies` on beta | `DeviceManagementConfiguration.Read.All` | Reads policy identity and scope tags for the extended audit. The adopted Graph contract is beta only. |
| Remediations and device health scripts | `/deviceManagement/deviceHealthScripts` on beta | `DeviceManagementScripts.Read.All` | Reads script identity and scope tags for the extended audit. The adopted Graph contract is beta only. |
| Managed device lookup | `/deviceManagement/managedDevices` on v1.0 | `DeviceManagementManagedDevices.Read.All` | Finds the named device and reads stable identity and relationship fields. |
| Managed-device inventory | `/deviceManagement/managedDevices` on v1.0 | `DeviceManagementManagedDevices.Read.All` | Supplies Device and User 360 identity, health, ownership, enrolment and last-sync evidence. |
| Legacy configuration device status | `/deviceManagement/deviceConfigurations/{id}/deviceStatuses` on v1.0 | `DeviceManagementConfiguration.Read.All` | Reads reported configuration state where the deprecated Graph contract remains available. Failure is isolated per workload. |
| Compliance device status | `/deviceManagement/deviceCompliancePolicies/{id}/deviceStatuses` on v1.0 | `DeviceManagementConfiguration.Read.All` | Reads reported compliance state and last-reported time. |
| Application device status | `/deviceAppManagement/mobileApps/{id}/deviceStatuses` on beta | `DeviceManagementApps.Read.All` | Reads reported install state, state detail, device, user and error code. The adopted contract is beta and marked deprecated by Microsoft. |
| PowerShell script device state | `/deviceManagement/deviceManagementScripts/{id}/deviceRunStates` on beta | `DeviceManagementScripts.Read.All` | Reads reported run state, output and errors with an expanded managed-device relationship. |
| Remediation device state | `/deviceManagement/deviceHealthScripts/{id}/deviceRunStates` on beta | `DeviceManagementScripts.Read.All` | Reads detection and remediation states. The current documented response does not guarantee a device relationship, so unmatched records remain `NotEvaluated`. |
| Managed device tag enrichment | `/deviceManagement/managedDevices` on beta | `DeviceManagementManagedDevices.Read.All` | Reads scope tag IDs. A failure leaves stable device data available and tag matching `NotEvaluated`. |
| Microsoft Entra device lookup and membership | `/devices` and `/devices/{id}/transitiveMemberOf` | `Device.Read.All` | Tests whether a managed device is within an assignment scope group. |
| Device inventory reconciliation | `/devices` | `Device.Read.All` | Correlates Intune records with Microsoft Entra device identity, OS, trust and activity evidence. |
| Detected software inventory | `/deviceManagement/detectedApps` and `/detectedApps/{id}/managedDevices` | `DeviceManagementManagedDevices.Read.All` | Reads detected software and its returned managed-device relationships through v1.0. |
| Application definition evidence | `/deviceAppManagement/mobileApps` and `/mobileApps/{id}/relationships` | `DeviceManagementApps.Read.All` | Reads requirement, detection, dependency and supersedence evidence. Relationship enrichment uses beta. |
| Autopilot identities | `/deviceManagement/windowsAutopilotDeviceIdentities` | `DeviceManagementServiceConfig.Read.All` | Reads optional registration, profile assignment and device correlation evidence through beta. |
| Autopilot events | `/deviceManagement/autopilotEvents` | `DeviceManagementManagedDevices.Read.All` | Reads optional enrolment stage, duration and failure evidence through beta. |
| Autopilot deployment profiles | `/deviceManagement/windowsAutopilotDeploymentProfiles` | `DeviceManagementServiceConfig.Read.All` | Reads optional deployment profile evidence through beta. |
| Enrolment Status Page profiles | `/deviceManagement/deviceEnrollmentConfigurations` | `DeviceManagementServiceConfig.Read.All` | Reads optional enrolment configuration evidence through beta. |

## Feature sets

### Core

```text
User.Read
User.Read.All
GroupMember.Read.All
DeviceManagementRBAC.Read.All
```

### ScopeTagAudit

Adds:

```text
DeviceManagementConfiguration.Read.All
DeviceManagementApps.Read.All
```

### AssignmentExplorer

Adds:

```text
DeviceManagementConfiguration.Read.All
DeviceManagementApps.Read.All
DeviceManagementScripts.Read.All
```

`Start-IntuneAccess` selects `Core`, `AssignmentExplorer`, `OperationalEvidence`, `PolicyAnalysis`, `AuditEvidence`, `DeviceIntelligence`, `ApplicationEvidence`, `UpdateCompliance` and `EstateIntelligence` by default. Each source has its own collection state, so a missing permission or unavailable beta endpoint does not hide successful evidence from other sources.

### PolicyAnalysis

Adds:

```text
DeviceManagementConfiguration.Read.All
```

This feature reads supported policy setting values and uses completed assignment evidence to test exact target overlap. It is selected by the guided workflow.

### AuditEvidence

Adds:

```text
DeviceManagementApps.Read.All
```

This feature reads a bounded 30-day Intune audit trail. The default Assignment Explorer already requests the same read scope.

### ExtendedScopeTagAudit

Includes the ScopeTagAudit permissions and adds:

```text
DeviceManagementScripts.Read.All
```

### ManagedDeviceAccess

Adds:

```text
DeviceManagementManagedDevices.Read.All
Device.Read.All
```

### OperationalEvidence

Adds:

```text
DeviceManagementConfiguration.Read.All
DeviceManagementApps.Read.All
DeviceManagementScripts.Read.All
DeviceManagementManagedDevices.Read.All
```

The guided workflow selects this feature by default. Use `Start-IntuneAccess -Feature Core, AssignmentExplorer` to omit managed-device inventory, deployment outcomes and policy setting analysis.

### DeviceIntelligence and EstateIntelligence

Add:

```text
DeviceManagementManagedDevices.Read.All
Device.Read.All
```

Estate intelligence also uses the application and configuration read scopes already requested by the default workflow.

### ApplicationEvidence

Adds:

```text
DeviceManagementApps.Read.All
DeviceManagementManagedDevices.Read.All
Device.Read.All
```

### UpdateCompliance

Adds:

```text
DeviceManagementConfiguration.Read.All
DeviceManagementManagedDevices.Read.All
Device.Read.All
```

### Autopilot

Adds:

```text
DeviceManagementManagedDevices.Read.All
DeviceManagementServiceConfig.Read.All
```

Autopilot is opt-in and is not selected by the default guided workflow.

## Consent and administrator rights

A delegated scope does not grant the signed in person more Intune data than that person is authorised to read. Tenant consent and an appropriate Intune role may both be required.

IntuneAccess does not request `Directory.Read.All`. It also does not request any `ReadWrite` scope.

Microsoft documents `Member.Read.Hidden` for reading hidden group membership. IntuneAccess does not request it by default. A hidden Admin Group can therefore make membership evidence incomplete; this limitation is reported rather than broadening consent for every user.

## Primary references

1. [List Intune role definitions](https://learn.microsoft.com/en-us/graph/api/intune-rbac-deviceandappmanagementroledefinition-list?view=graph-rest-1.0)
2. [List Intune role assignments](https://learn.microsoft.com/en-us/graph/api/intune-rbac-deviceandappmanagementroleassignment-list?view=graph-rest-1.0)
3. [List a user's transitive memberships](https://learn.microsoft.com/en-us/graph/api/user-list-transitivememberof?view=graph-rest-1.0)
4. [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)
5. [List device configurations](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-deviceconfiguration-list?view=graph-rest-1.0)
6. [List compliance policies](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-devicecompliancepolicy-list?view=graph-rest-1.0)
7. [List Settings Catalog policies](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfigv2-devicemanagementconfigurationpolicy-list?view=graph-rest-beta)
8. [List device health scripts](https://learn.microsoft.com/en-us/graph/api/intune-devices-devicehealthscript-list?view=graph-rest-beta)
9. [List device configuration assignments](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-deviceconfigurationassignment-list?view=graph-rest-1.0)
10. [List compliance policy assignments](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-devicecompliancepolicyassignment-list?view=graph-rest-1.0)
11. [List application assignments](https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappassignment-list?view=graph-rest-1.0)
12. [List remediation assignments](https://learn.microsoft.com/en-us/graph/api/intune-devices-devicehealthscriptassignment-list?view=graph-rest-beta)
13. [List feature update profile assignments](https://learn.microsoft.com/en-us/graph/api/intune-softwareupdate-windowsfeatureupdateprofileassignment-list?view=graph-rest-beta)
14. [List managed devices](https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list?view=graph-rest-1.0)
15. [List configuration device statuses](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-deviceconfigurationdevicestatus-list?view=graph-rest-1.0)
16. [List compliance device statuses](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-devicecompliancedevicestatus-list?view=graph-rest-1.0)
17. [List application device statuses](https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappinstallstatus-list?view=graph-rest-beta)
18. [List remediation device states](https://learn.microsoft.com/en-us/graph/api/intune-devices-devicehealthscriptdevicestate-list?view=graph-rest-beta)
19. [List configuration policy settings](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfigv2-devicemanagementconfigurationsetting-list?view=graph-rest-beta)
20. [Endpoint security intent resource](https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceintent-devicemanagementintent?view=graph-rest-beta)
21. [List Intune audit events](https://learn.microsoft.com/en-us/graph/api/intune-auditing-auditevent-list?view=graph-rest-1.0)
