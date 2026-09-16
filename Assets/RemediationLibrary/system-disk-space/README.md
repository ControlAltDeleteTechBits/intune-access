# System disk space detection review package

Version: 1.0.0. Licence: MIT. Detection only: no remediation script is supplied because automated deletion is not appropriate without knowing the contents and retention requirements.

## Exact changes

None. Detect.ps1 reads local system drive capacity through CIM. It flags less than 10 GiB free. This is a configurable operational review threshold, not a Microsoft requirement for every workload. Review the constant before deployment.

## Prerequisites and context

Windows with a readable Win32_LogicalDisk CIM provider. Use SYSTEM and the 64-bit Windows PowerShell host when deploying through Intune Remediations. Confirm current licensing and role prerequisites at https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations

## Results

Exit 0 means at least 10 GiB was reported free; exit 1 means below the threshold; exit 2 means missing or failed evaluation. No result proves that a specific application has enough space. Supply only the detection script in a detection-only package; do not invent a generic cleanup action.

## Suggested action and verification

Confirm the storage consumers, business retention requirements and actual workload requirements with the device owner. Use approved storage management procedures externally. Repeat detection and verify workload operation after an approved change.

## Recovery

No recovery is needed for this detection script because it does not change the device. Recovery for external cleanup depends on the chosen action and backups; deletion is not assumed reversible.

## Review boundary

Source and mocked control-flow tests are provided. IntuneAccess only exports this package. It never uploads or executes it.
