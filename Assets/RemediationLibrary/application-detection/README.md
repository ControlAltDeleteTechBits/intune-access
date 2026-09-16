# Application detection mismatch

Development candidate. Export-only, read-only collectors; not a production-approved repair package.

Supply reviewed file or registry rules matching the Intune configuration. Registry string-equality rules compare both views and propose a view correction where the expected value appears in the other view. Named registry integer and regular version comparisons preserve all six comparison operators. Imported file-version rules also preserve these operators and compare two to four numeric version components. Integer overflow, missing file-version metadata, invalid formats and version string-fallback cases stay NotEvaluated. Manual file rules support existence and exact version observations. MSI and arbitrary scripts are not evaluated. All imported detection conditions must match; unsupported conditions block a combined success.

## Run externally

Export the selected Win32 application's complete JSON using a read-only Graph GET of `v1.0/deviceAppManagement/mobileApps/{id}` in your authorised session. Save it outside this package. `Convert-ApplicationRules.ps1 -ApplicationPath .\application.json` writes collector configuration to the pipeline. It imports the supported registry comparisons described above, literal file/folder existence and literal file-version rules from the v1.0 `rules` collection. It keeps original rules and retains unsupported conditions as explicit blockers. File/folder existence requires `operationType=exists` and `operator=notConfigured`; versions require `operationType=version`, a supported comparison operator and comparison value. Both require a Boolean architecture flag and a literal local path. Use a 64-bit collector; environment-variable expansion, UNC paths, wildcards, traversal, file dates and sizes remain unsupported. Review the output and execution context before collection.

After collecting evidence using that configuration, `New-DetectionProposal.ps1 -EvidencePath .\evidence.json` writes a review-only correction proposal for a supported alternative-registry-view mismatch. Each proposed rule retains the source properties except the architecture flag. This is not a ready-to-apply Graph PATCH body; confirm current tenant configuration and product identity first. No rule is uploaded or changed.

Use 64-bit Windows PowerShell 5.1 or PowerShell 7 on Windows. Review every file first. Machine reads may need elevation; do not collect user evidence as SYSTEM and assume it represents the signed-in user. No tenant credentials, secret, enrolment change or remote command is required.

For imported applications, the reviewer requires the collected context to match `InstallContext`. A SYSTEM application requires `IsSystem=true` and SID `S-1-5-18`. For a user application, add `ExpectedUserSid` to the reviewed configuration with the affected user's SID, then collect as that user. An elevated administrator is not automatically SYSTEM or the affected user. Missing, inconsistent or mismatched context leaves combined detection as NotEvaluated and blocks correction proposals. Individual rule observations remain visible. These are checks of supplied evidence, not cryptographic proof of identity; do not edit context fields to bypass them.

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
