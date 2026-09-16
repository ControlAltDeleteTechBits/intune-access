# Per-user application migration evidence

Development candidate. Export-only, read-only collectors; not a production-approved repair package.

Collect as the affected user. Inventory includes HKLM and the executing user's HKCU only. Matching display names and publishers identify candidates, not proven duplicate products. Vendor-specific migration, settings preservation and uninstall adapters are pending application selection. No uninstall command is read or executed.

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
