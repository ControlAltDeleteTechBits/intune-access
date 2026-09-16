# Intune Management Extension stopped service review package

Version: 1.0.0. Licence: MIT. Exported scripts are not executed by IntuneAccess.

## Exact changes

Detect.ps1 reads the IntuneManagementExtension service state. Remediate.ps1 starts that exact service only if it exists, is stopped and is not disabled. It does not install software, change startup type, reset enrolment, delete files or restart a running service. Starting the agent can resume assigned application and script processing. This is a change making package, not a read only operation when deployed.

## Prerequisites and context

An approved Windows pilot device with Intune Management Extension already installed. Review why the service stopped and whether this was intentional. Deploy as SYSTEM using the 64-bit Windows PowerShell host. Test on representative supported Windows builds before production use. Intune Remediations has licensing and role prerequisites: https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations

A stopped agent might not retrieve a newly assigned package. This package is not a remote recovery guarantee. Use your approved support process if the agent cannot execute it.

## Detection and execution

Detection exit 0 means running, exit 1 means a stopped non-disabled service, and exit 2 means evaluation is unsuitable or failed. Only exit 1 should trigger remediation. Remediation exit 0 means already running or observed running after start; it does not prove device health. Exit 2 means failure, refusal, skipped execution or an unsuitable state. Remediate.ps1 supports -WhatIf for administrator review.

## Verification

Run detection separately through an approved process. Check a later agent report and the original management symptom. A running service alone does not establish application or policy success.

## Recovery

The package does not change persistent service configuration. If the start was inappropriate, the authorised administrator must decide whether to stop the service using normal service controls. Stopping management can interrupt work. Assigned tasks already performed after the start cannot be undone by stopping the service; plan recovery for those tasks separately.

## Review boundary

Source and mocked control-flow tests are provided. This is not a Microsoft-signed or universally validated repair. IntuneAccess does not upload, assign or execute this package.
