# Research and validation status

Checked on 17 August 2026.

| Behaviour | Status | Basis |
| --- | --- | --- |
| Intune roles are assigned to groups | Documented | Microsoft Learn, Assign Microsoft Intune roles. |
| Permissions from several groups are cumulative | Documented | Microsoft Learn, Assign Microsoft Intune roles. |
| Intune RBAC has no deny option across assignments | Documented | Microsoft Learn, Assign Microsoft Intune roles. |
| Scope (Groups) constrain manageable users and devices | Documented | Microsoft Learn, Assign Microsoft Intune roles. |
| Scope (Tags) constrain visible Intune objects | Documented | Microsoft Learn, Use RBAC and scope tags for distributed IT. |
| An assignment with no scope tag can see all tags, subject to permissions | Documented | Microsoft Learn, Use RBAC and scope tags for distributed IT. |
| Default scope tag applies to otherwise untagged supported objects | Documented | Microsoft Learn, Use RBAC and scope tags for distributed IT. |
| Scoped permissions is an opt in preview introduced in March 2026 | Documented | Microsoft Learn, Use RBAC and scope tags for distributed IT. |
| v1.0 role definitions contain exact allowed resource actions | Documented | Microsoft Graph roleDefinition resource. |
| v1.0 assignments contain administrator group IDs and resource scope IDs | Documented and used as the stable source | Microsoft Graph deviceAndAppManagementRoleAssignment resource. |
| Assignment scope type and scope tag IDs require beta in this implementation | Documented API difference | Beta enriches the v1.0 assignment. Mock tests prove stable data survives a beta failure. |
| Managed-device scope tag IDs require beta in this implementation | Documented API difference | v1.0 supplies stable device identity and relationships; beta enriches tags. |
| Direct membership is sufficient assignment evidence | Documented | Microsoft Learn, Assign Microsoft Intune roles. |
| Nested membership applies in every tenant | Not established | Microsoft documents licence and tenant dependent behaviour. The module returns `NotEvaluated`. |
| Tenant Scoped permissions mode can be read from a supported Graph contract | Not established | No dependable documented endpoint was adopted. The mode is returned as `Unknown`. |
| Managed device access is denied when no path is found | Not established | Microsoft Entra roles and unsupported paths remain outside the model. The module returns `NotEvaluated`. |
| Mocked calculation, paging, retry and report safety behaviour | Observed in automated tests | Pester unit tests in this repository. |
| Managed-device scope can match the device group or associated user group | Implemented and live tested | `ScopeMatchSource` retains the matching source. The test device matched its assigned Microsoft Entra device group. |
| End to end results in a live Intune tenant | Observed | Seven integration checks passed for a user with built-in and custom assignments, matching portal groups and tags and two cumulative managed-device read grants. |

## Live validation observed on 17 August 2026

1. The Graph connection used delegated authentication in the Global environment.
2. A test user matched a Help Desk Operator assignment and a custom managed-device reader assignment.
3. The assignment collection omitted members and scopes, while its detail endpoints returned complete data. Detail hydration was implemented and regression tested.
4. The returned Admin Groups, Scope Group, Scope Tag and role types matched the Intune admin centre.
5. `Microsoft.Intune_ManagedDevices_Read` retained two granting assignments.
6. The test device matched the expected Microsoft Entra device scope group. Its Intune tag remained Default, so the complete path returned `NotEvaluated` rather than a false positive.
7. All seven integration tests passed with no skipped checks.
8. The Graph Command Line Tools registration already held broader delegated consent, so a clean least-privilege shared-client result remains outstanding.

## Additional live tenant checks after 1.0.0

1. Validate nested Admin Group membership with the tenant's unlicensed administrator setting.
2. Validate Default and custom scope tags on a device configuration and mobile app.
3. Validate the tenant's Scoped permissions setting against the module warning.
4. Confirm a dedicated Microsoft Entra application holds only the documented delegated scopes.

## Running the live checks

Use a lab tenant and a test administrator that has known Intune RBAC assignments. Connect in the same PowerShell process used to start Pester.

```powershell
Import-Module .\IntuneAccess.psd1 -Force
Connect-IntuneAccess -Feature Core, ScopeTagAudit, ManagedDeviceAccess

$env:INTUNEACCESS_TEST_UPN = 'lab.helpdesk@contoso.example'
$env:INTUNEACCESS_TEST_DEVICE = 'LAB-PC-001'
$env:INTUNEACCESS_TEST_SCOPE_AUDIT = '1'
$env:INTUNEACCESS_EXPECT_POSITIVE_RBAC = '1'

Invoke-Pester .\Tests\Integration
```

`INTUNEACCESS_TEST_DEVICE` is optional. Omit it to skip managed-device checks. Set `INTUNEACCESS_TEST_SCOPE_AUDIT` to `1` only after granting the two documented audit read scopes.

Remove the process variables after testing:

```powershell
Remove-Item Env:INTUNEACCESS_TEST_UPN -ErrorAction SilentlyContinue
Remove-Item Env:INTUNEACCESS_TEST_DEVICE -ErrorAction SilentlyContinue
Remove-Item Env:INTUNEACCESS_TEST_SCOPE_AUDIT -ErrorAction SilentlyContinue
Remove-Item Env:INTUNEACCESS_EXPECT_POSITIVE_RBAC -ErrorAction SilentlyContinue
```
