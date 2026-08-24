function Get-IntuneDeviceHygiene {
    <#
    .SYNOPSIS
    Finds stale, duplicate, mismatched and incomplete Intune device records.
    .DESCRIPTION
    Correlates read-only Intune managed-device evidence with Microsoft Entra device records and applies documented local hygiene rules. Findings are review prompts, not remote actions or proof that a record should be deleted.
    .PARAMETER StaleAfterDays
    Number of days since the last confirmed Intune check-in before a record is flagged as stale.
    .PARAMETER NewEnrollmentGraceDays
    Grace period before an enrolment without a later check-in is flagged.
    .EXAMPLE
    Get-IntuneDeviceHygiene -StaleAfterDays 45
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 3650)] [int] $StaleAfterDays = 30,
        [ValidateRange(1, 3650)] [int] $NewEnrollmentGraceDays = 7
    )

    $operational = Get-IntuneAccessOperationalEvidence -Workload @()
    Get-IntuneAccessDeviceIntelligence -ManagedDevice $operational.ManagedDevices -StaleAfterDays $StaleAfterDays -NewEnrollmentGraceDays $NewEnrollmentGraceDays
}
