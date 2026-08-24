function Get-IntuneAutopilotTimeline {
    <#
    .SYNOPSIS
    Gets optional Autopilot and enrolment timeline evidence.
    .DESCRIPTION
    Correlates Autopilot registration, deployment profile, Enrolment Status Page and managed-device evidence. The feature uses Microsoft Graph beta and labels unavailable stages explicitly.
    .PARAMETER DeviceName
    Optional exact managed-device name.
    .PARAMETER SerialNumber
    Optional exact Autopilot serial number.
    .EXAMPLE
    Get-IntuneAutopilotTimeline -SerialNumber 'PF123ABC'
    #>
    [CmdletBinding()]
    [OutputType([object], [object[]])]
    param(
        [ValidateNotNullOrEmpty()] [string] $DeviceName,
        [ValidateNotNullOrEmpty()] [string] $SerialNumber
    )

    $operational = Get-IntuneAccessOperationalEvidence -Workload @()
    $evidence = Get-IntuneAccessAutopilotEvidence -ManagedDevice $operational.ManagedDevices
    if (-not [string]::IsNullOrWhiteSpace($DeviceName)) { return ,@($evidence.Timelines | Where-Object DeviceName -EQ $DeviceName) }
    if (-not [string]::IsNullOrWhiteSpace($SerialNumber)) { return ,@($evidence.Timelines | Where-Object SerialNumber -EQ $SerialNumber) }
    $evidence
}
