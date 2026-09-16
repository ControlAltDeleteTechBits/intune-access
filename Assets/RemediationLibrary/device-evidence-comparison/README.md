# Working and affected device comparison

## Optional certificate and event metadata

Set the JSON Boolean options `IncludeCertificateMetadata` and `IncludeEventMetadata` to true in the reviewed configuration to include these sources. Both default to false. The certificate adapter reads at most 500 certificates per personal store, LocalMachine and the executing CurrentUser, and exports issuer, thumbprint, validity, EKU identifiers and key-presence metadata only. It does not export private keys, subjects or SANs. Different device certificates are normal and must not be treated as a fault merely because their thumbprints differ.

The event adapter reads the newest 100 warning/error records from the last seven days in the MDM Admin and Windows Update operational channels. It exports record identifiers, event IDs, provider, level and timestamp, not messages or XML. Truncation, access failures and query time windows remain explicit. An empty result does not prove that the device is healthy or that logs are complete. Compare both machines using the same options and inspect relevant event records locally before recommending a correction.

Development candidate. Export-only, read-only collectors; not a production-approved repair package.

Collect on both the affected device and a known-working device using the same context and near the same time. Compare matching keys and inspect differences. A difference is not proof of causation. Missing and inaccessible facts are NotEvaluated. This initial collector covers OS, update sources, service state and registered applications; certificate and event adapters are not yet included.

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
