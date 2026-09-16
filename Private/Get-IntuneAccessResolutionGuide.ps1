function Get-IntuneAccessResolutionGuide {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object] $Finding)

    $rule = [string] (Get-IntuneAccessProperty $Finding 'SourceId' '')
    $source = [string] (Get-IntuneAccessProperty $Finding 'SourceType' '')
    $checks = @('Confirm the affected object still exists and the evidence is current.', 'Compare the returned evidence with the relevant Intune portal record.')
    $action = [string] (Get-IntuneAccessProperty $Finding 'ReviewRecommendation' 'Review the evidence with the service owner before proposing a change.')
    $impact = 'The observation may affect management or reporting. Business impact is not established by this finding alone.'
    $verify = 'Collect fresh evidence for the same object and repeat the relevant check. Missing data cannot confirm resolution.'
    $recovery = 'No change is performed by IntuneAccess. Record the original configuration before any external change; agree recovery with the service owner.'
    $reference = 'https://learn.microsoft.com/en-us/intune/device-management/'
    switch -Regex ($rule) {
        '^DEV-CHECKIN|^DEV-ENROLMENT' {
            $impact = 'Policies and inventory may not reflect the current device state.'
            $checks = @('Confirm whether the device is in service, stored, offline or retired.', 'Check the last observed enrolment and sync timestamps, device connectivity and management client status.', 'Compare related Intune and Microsoft Entra records before considering cleanup.')
            $action = 'Investigate connectivity and enrolment with the device owner. Consider a lifecycle change only after confirming the device is no longer required.'
            $verify = 'Obtain a newer successful check-in for this exact device ID. A missing or hidden record is not evidence of recovery.'
        }
        '^DEV-DUPLICATE|^DEV-ENTRA' {
            $impact = 'Identity ambiguity can make targeting and support investigations unreliable.'
            $checks = @('Compare exact Intune IDs, Microsoft Entra device IDs, serial numbers and enrolment dates.', 'Confirm which records correspond to real devices with their owners.', 'Check whether reused serial numbers or re-enrolment explain the observation.')
            $action = 'Prepare a record reconciliation plan. Do not select a record for deletion from serial number or age alone.'
            $verify = 'Repeat identity correlation and verify that all active devices remain represented.'
            $recovery = 'Deletion may not be reversible. Do not propose deletion without an approved recovery and re-enrolment plan.'
        }
        '^DEV-PRIMARY' {
            $impact = 'User association may be incomplete, or intentionally absent on shared devices.'
            $checks = @('Confirm the enrolment model and whether the device is shared, kiosk or userless.', 'Confirm the intended primary user with the device owner.')
            $action = 'Mark the finding expected for intentional userless devices. Otherwise review primary user configuration through the normal administrative process.'
            $verify = 'Confirm the expected user association in fresh evidence, or record an expected disposition with a review date.'
        }
        '^DEV-COMPLIANCE' {
            $checks = @('Review compliance policy targeting and per-policy results.', 'Check reporting age and distinguish unknown, pending and noncompliant states.')
            $action = 'Address the specific failed policy check only after obtaining its evidence. Do not weaken compliance requirements to clear an unknown state.'
        }
        '^DEV-OS-' {
            $checks = @('Compare observation times from both services.', 'Verify the OS build on the exact device; different reporting intervals can explain a mismatch.')
            $action = 'Obtain fresh inventory before proposing OS or identity changes.'
        }
    }
    switch ($source) {
        'DeploymentOutcome' {
            $impact = 'A workload reported an error on this device; the cause and current user impact require confirmation.'
            $checks = @('Review the workload type, error code and exact reporting time.', 'For applications, compare requirements, dependencies and detection rules with device logs.', 'Confirm the affected device and assignment before changing the package.')
            $action = 'Use the workload-specific troubleshooting procedure and test the proposed correction on a representative pilot device.'
            $verify = 'Collect a fresh result for the same workload and device, then confirm the intended behaviour on the device.'
            $reference = 'https://learn.microsoft.com/en-us/troubleshoot/mem/intune/app-management/troubleshoot-win32-app-install'
        }
        'ApplicationEvidence' {
            $impact = 'A required application may lack usable reporting. Absence from detected software does not prove it is absent from the device.'
            $checks = @('Confirm an included required assignment path for this device or user.', 'Check exclusions, filters, requirements and the outcome collection status.', 'Inspect application detection evidence and client logs before treating this as an installation failure.')
            $action = 'Correct a confirmed targeting or packaging issue through a pilot. If evidence is missing, collect it before choosing a fix.'
            $verify = 'Confirm a fresh installation result and the expected application behaviour; do not rely on a display-name inventory match alone.'
        }
        'PolicyConflict' {
            $impact = 'Different configured values may reach an overlapping target population. The final device value is not established.'
            $checks = @('Review each source policy, setting value and the evidence of target overlap.', 'Confirm the intended setting with its owner and check exceptions before consolidation.')
            $action = 'Prepare a consolidation proposal listing the original policies and values. Pilot one agreed configuration before removing redundant settings externally.'
            $verify = 'Recollect all source policy settings and verify intended device behaviour. Missing policy collection cannot prove the conflict cleared.'
        }
        'RemediationEffectiveness' {
            $impact = 'A remediation may be failing, repeatedly detecting an issue or lacking current results.'
            $checks = @('Read separate detection and remediation states, errors and execution timestamps.', 'Distinguish a new execution from another snapshot of the same result.', 'Review execution context, prerequisites and package logic without executing it.')
            $action = 'Review the script with its owner and test any correction outside IntuneAccess on an approved pilot. Missing results alone do not justify changing the script.'
            $verify = 'Inspect a later execution and an independent relevant check. A remediation success state alone does not prove recovery.'
            $reference = 'https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations'
        }
        'UpdateCompliance' {
            $checks = @('Confirm the exact update or compliance workload and its device targeting.', 'Compare reported per-policy evidence and age; a device summary is not a per-policy result.', 'Use a documented OS build mapping when checking a release name against an OS version.')
            $action = 'Obtain policy-specific failure evidence before proposing a change. Do not relax update or compliance policy based on missing or mismatched reporting alone.'
        }
        'AutopilotTimeline' {
            $checks = @('Review the reported failing stage, profile and timestamps.', 'Confirm the exact device identity and collect relevant enrolment diagnostics.')
            $action = 'Address the evidenced stage failure with the enrolment owner. Do not reset or re-enrol a device solely from a historical event.'
        }
    }
    [PSCustomObject] @{
        GuideVersion = '1.0'; PotentialImpact = $impact; RecommendedChecks = $checks; SuggestedFix = $action
        Prerequisites = @('Confirm current evidence and intended configuration with the object owner.', 'Obtain change approval and preserve the original configuration before applying changes externally.')
        PilotRecommendation = 'Select a non-critical representative device from the affected population with its owner. No pilot is assigned automatically.'
        Risks = @('The finding is an observation, not proof of root cause.', 'External changes may affect users; scope and recovery must be reviewed.')
        Verification = $verify; Recovery = $recovery; Reference = $reference; ExecutionAllowed = $false
    }
}
