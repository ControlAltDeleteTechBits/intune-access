# Update source migration review

The collector also reads bounded cached computer RSoP registry-policy records and the update-class source switch. The review identifies the exact per-class CSP path, Group Policy setting, administrator-declared expected source and any recorded GPO candidates. A cached GPO record is not proof of current enforcement; an unavailable RSoP namespace is not proof that Group Policy is absent. Configuration Manager service presence is not proof of update workload ownership. Review current assignments and management authority before any policy correction. Local cleanup remains disabled.

Development candidate. Export-only, read-only collectors; not a production-approved repair package.

Supply ExpectedSources by Quality, Feature, Driver and Other, each WSUS or WindowsUpdate. Review observed policy stores against that baseline. This does not establish effective policy ownership. Never delete all update settings. No cleanup script is included until ownership and setting-specific preconditions can be verified.

## Run externally

Use 64-bit Windows PowerShell 5.1 or PowerShell 7 on Windows. Review every file first. Machine reads may need elevation; do not collect user evidence as SYSTEM and assume it represents the signed-in user. No tenant credentials, secret, enrolment change or remote command is required.

```powershell
.\Detect.ps1 -ConfigurationPath .\configuration.example.json | Out-File .\evidence.json -Encoding utf8
.\Review-Evidence.ps1 -EvidencePath .\evidence.json | Out-File .\review.json -Encoding utf8
.\Compare-Evidence.ps1 -ReferencePath .\working.json -DifferencePath .\affected.json | Out-File .\comparison.json -Encoding utf8
```

Edit the example before collection. Keep output outside the extracted package. These are diagnostic exports, not Intune detection/remediation exit-code pairs. Large JSON output is unsuitable for Intune's limited script-output field. An administrator must explicitly arrange collection and retrieve files; IntuneAccess does not deploy or retrieve them.

## Verify and recover

### Relate observations to tenant policies

On the analyst machine, use PowerShell 7 and a full-identity IntuneAccess snapshot. Before collection, add reviewed exact mappings to the configuration's `PolicyMappings` array, for example `{"Category":"Quality","SettingDefinitionId":"the-exact-definition-id-from-your-policy"}`. Do not use a display name, guessed ID or the example placeholder. Confirm the definition represents the stated update source class. This initial mapping is administrator supplied, not independently verified by the tool.

```powershell
.\Review-UpdatePolicies.ps1 -EvidencePath .\evidence.json -SnapshotPath .\tenant-snapshot.json -TenantId 'your-tenant-id' -DeviceId 'your-managed-device-id' | Out-File .\policy-review.json -Encoding utf8
```

The review preserves the local findings and adds exact matching policy IDs, names, raw configured values and assignment evidence. Fresh successfully collected settings with one included assignment become targeted policy candidates, not proven owners. Exclusions, failed collection, duplicate assignments and stale evidence cannot become correction candidates. Missing mappings remain unevaluated. Snapshot hashes check integrity, not authenticity; the selected endpoint-to-device identity is not verified. Review candidates in Intune and reconcile Group Policy and co-management authority before an external pilot change. Import policy-review.json into the report's Script Library. No policy or local registry value is changed.

Review source paths, execution context, observation time and errors. Import review.json or comparison.json into the report's Script Library. Imported evidence is untrusted, not tenant-verified and not merged into cloud findings. Recollect after any externally approved change. No settings are changed by these scripts, so there is no configuration rollback. Delete your local evidence files only when no longer needed; they may contain usernames, SIDs, application inventory and internal server names.

## Limits

No downloaded binaries or commands from JSON are executed. No automatic repair, application uninstall, service restart, registry write, reboot or policy change occurs. Collection is not cryptographic proof of device identity, and comparison does not prove resolution. Freshness must be reviewed manually.
