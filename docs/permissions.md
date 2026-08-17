# Microsoft Graph permissions

This matrix was checked against Microsoft Learn on 17 August 2026. All permissions are delegated and read only.

| Feature | Endpoint | Delegated permission | Reason |
| --- | --- | --- | --- |
| Sign in and tenant label | `/organization` | `User.Read` | Reads the organisation ID, display name and verified domain values available to the signed in user. |
| Target user lookup | `/users/{id or UPN}` | `User.Read.All` | Resolves another administrator. |
| Direct group membership | `/users/{id}/memberOf/microsoft.graph.group` | `User.Read.All`, `GroupMember.Read.All` | Establishes direct Admin Group evidence and readable group details. |
| Transitive group membership | `/users/{id}/transitiveMemberOf/microsoft.graph.group` | `User.Read.All`, `GroupMember.Read.All` | Identifies nested membership without treating it as confirmed Intune access. |
| Group details | `/groups/{id}` | `GroupMember.Read.All` | Resolves Admin Group and Scope (Groups) display names. |
| Intune role definitions | `/deviceManagement/roleDefinitions` | `DeviceManagementRBAC.Read.All` | Reads built in and custom roles and exact allowed actions. |
| Intune role assignments | `/deviceManagement/roleDefinitions/{id}/roleAssignments` on v1.0 | `DeviceManagementRBAC.Read.All` | Reads stable assignment identity, administrator group IDs and resource scope IDs. |
| Role assignment enrichment | `/deviceManagement/roleDefinitions/{id}/roleAssignments` on beta | `DeviceManagementRBAC.Read.All` | Adds scope type, scope members and scope tag IDs. A failure leaves the v1.0 assignment available with missing-data states. |
| Scope tags | `/deviceManagement/roleScopeTags` | `DeviceManagementRBAC.Read.All` | Resolves scope tag IDs. Beta endpoint. |
| Device configurations | `/deviceManagement/deviceConfigurations` on v1.0 and beta | `DeviceManagementConfiguration.Read.All` | Reads stable IDs and names from v1.0, then adds beta scope tag properties for one audited resource family. |
| Mobile apps | `/deviceAppManagement/mobileApps` on v1.0 and beta | `DeviceManagementApps.Read.All` | Reads stable IDs and names from v1.0, then adds beta scope tag properties for one audited resource family. |
| Compliance policies | `/deviceManagement/deviceCompliancePolicies` on v1.0 and beta | `DeviceManagementConfiguration.Read.All` | Reads stable IDs and names from v1.0, then adds beta scope tag properties for the extended audit. |
| Settings Catalog and endpoint security policies | `/deviceManagement/configurationPolicies` on beta | `DeviceManagementConfiguration.Read.All` | Reads policy identity and scope tags for the extended audit. The adopted Graph contract is beta only. |
| Remediations and device health scripts | `/deviceManagement/deviceHealthScripts` on beta | `DeviceManagementScripts.Read.All` | Reads script identity and scope tags for the extended audit. The adopted Graph contract is beta only. |
| Managed device lookup | `/deviceManagement/managedDevices` on v1.0 | `DeviceManagementManagedDevices.Read.All` | Finds the named device and reads stable identity and relationship fields. |
| Managed device tag enrichment | `/deviceManagement/managedDevices` on beta | `DeviceManagementManagedDevices.Read.All` | Reads scope tag IDs. A failure leaves stable device data available and tag matching `NotEvaluated`. |
| Microsoft Entra device lookup and membership | `/devices` and `/devices/{id}/transitiveMemberOf` | `Device.Read.All` | Tests whether a managed device is within an assignment scope group. |

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

## Consent and administrator rights

A delegated scope does not grant the signed in person more Intune data than that person is authorised to read. Tenant consent and an appropriate Intune role may both be required.

IntuneAccess does not request `Directory.Read.All`. It also does not request any `ReadWrite` scope.

Microsoft documents `Member.Read.Hidden` for reading hidden group membership. Version 0.2 does not request it by default. A hidden Admin Group can therefore make membership evidence incomplete; this limitation is reported in the documentation rather than broadening consent for every user.

## Primary references

1. [List Intune role definitions](https://learn.microsoft.com/en-us/graph/api/intune-rbac-deviceandappmanagementroledefinition-list?view=graph-rest-1.0)
2. [List Intune role assignments](https://learn.microsoft.com/en-us/graph/api/intune-rbac-deviceandappmanagementroleassignment-list?view=graph-rest-1.0)
3. [List a user's transitive memberships](https://learn.microsoft.com/en-us/graph/api/user-list-transitivememberof?view=graph-rest-1.0)
4. [Microsoft Graph permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference)
5. [List device configurations](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-deviceconfiguration-list?view=graph-rest-1.0)
6. [List compliance policies](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-devicecompliancepolicy-list?view=graph-rest-1.0)
7. [List Settings Catalog policies](https://learn.microsoft.com/en-us/graph/api/intune-deviceconfigv2-devicemanagementconfigurationpolicy-list?view=graph-rest-beta)
8. [List device health scripts](https://learn.microsoft.com/en-us/graph/api/intune-devices-devicehealthscript-list?view=graph-rest-beta)
