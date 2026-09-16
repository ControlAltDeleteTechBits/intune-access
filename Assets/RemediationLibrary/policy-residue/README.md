# Policy residue investigation

## Compare policy history on the analyst machine

The initial named observation configurations are `QualityUpdateSource` and `FeatureUpdateSource`. Run `New-PolicyObservationConfiguration.ps1 -Setting QualityUpdateSource -WorkloadId <policy-id> -SettingDefinitionId <exact-setting-id>` and save its JSON output. Verify the supplied IDs against the chosen policy. Each configuration includes the exact CSP path, registry observation, documented default and removal caveat. Microsoft documents Delete support and a default of 1 for these nodes; deleting configuration must not be interpreted as forcing Windows Update or as a universal registry cleanup instruction. Other WSUS settings and policy owners still matter.

`Review-PolicyHistory.ps1` requires PowerShell 7 and two full-identity schema 2.0 IntuneAccess snapshots. Supply `-EvidencePath`, `-ReferencePath`, `-CurrentPath`, `-TenantId` and the selected Intune managed-device `-DeviceId`. Each endpoint configuration rule must also include the exact `WorkloadId` and `SettingDefinitionId`. These mappings are administrator supplied, not inferred from names or verified automatically.

The script checks snapshot data hashes, tenant agreement and collection order, then joins exact setting and assignment identifiers. Current targeted settings are not residue. A setting missing from a successfully collected current policy but present in its earlier settings is only possible residue when the local value remains. Missing, failed or stale evidence stays inconclusive. Other policies and setting-specific removal behaviour must still be checked. No deletion is proposed or performed. Snapshot hashes are integrity checks, not signatures or proof of identity. Import its JSON output into the Script Library like other endpoint reviews.

Development candidate. Export-only, read-only collectors; not a production-approved repair package.

Supply exact registry rules for the settings under investigation. A present value is only a candidate for review, never proof of tattooing. Correlate the previous and current Intune snapshots, Group Policy results and the setting-specific CSP contract. Automatic correction remains unavailable until a supported setting adapter is reviewed.

## Run externally

Use 64-bit Windows PowerShell 5.1 or PowerShell 7 on Windows. Review every file first. Machine reads may need elevation; do not collect user evidence as SYSTEM and assume it represents the signed-in user. No tenant credentials, secret, enrolment change or remote command is required.

```powershell
.\Detect.ps1 -ConfigurationPath .\configuration.example.json | Out-File .\evidence.json -Encoding utf8
.\Review-Evidence.ps1 -EvidencePath .\evidence.json | Out-File .\review.json -Encoding utf8
.\Compare-Evidence.ps1 -ReferencePath .\working.json -DifferencePath .\affected.json | Out-File .\comparison.json -Encoding utf8
```

Edit the example before collection. Keep output outside the extracted package. These are diagnostic exports, not Intune detection/remediation exit-code pairs. Large JSON output is unsuitable for Intune's limited script-output field. An administrator must explicitly arrange collection and retrieve files; IntuneAccess does not deploy or retrieve them.

## Verify and recover

Review source paths, execution context, observation time and errors. Import review.json or comparison.json into the report's Script Library. Imported evidence is untrusted, not tenant-verified and not merged into cloud findings. Recollect after any externally approved change. No settings are changed by these scripts, so there is no configuration rollback. Delete your local evidence files only when no longer needed; they may contain usernames, SIDs, application inventory and internal server names.

## Limits

No downloaded binaries or commands from JSON are executed. No automatic repair, application uninstall, service restart, registry write, reboot or policy change occurs. Collection is not cryptographic proof of device identity, and comparison does not prove resolution. Freshness must be reviewed manually.
