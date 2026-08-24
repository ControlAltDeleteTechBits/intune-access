function Get-IntuneApplicationEvidence {
    <#
    .SYNOPSIS
    Joins Intune application assignments, installation results and detected software.
    .DESCRIPTION
    Returns read-only application definition, requirement, detection, relationship, installation and detected-software evidence. It does not infer root cause from an error code or exact-name software match.
    .PARAMETER DeviceName
    Optional exact managed-device name used to filter device application evidence.
    .PARAMETER ApplicationName
    Optional exact managed application name.
    .EXAMPLE
    Get-IntuneApplicationEvidence -DeviceName 'LAPTOP-0234'
    #>
    [CmdletBinding()]
    [OutputType([object], [object[]])]
    param(
        [ValidateNotNullOrEmpty()] [string] $DeviceName,
        [ValidateNotNullOrEmpty()] [string] $ApplicationName
    )
    $inventory = Get-IntuneAccessWorkloadAssignments
    $operational = Get-IntuneAccessOperationalEvidence -Workload $inventory.Workloads
    $result = Get-IntuneAccessApplicationEvidence -Workload $inventory.Workloads -Assignment $inventory.Assignments -ManagedDevice $operational.ManagedDevices -DeploymentOutcome $operational.DeploymentOutcomes
    if (-not [string]::IsNullOrWhiteSpace($DeviceName) -or -not [string]::IsNullOrWhiteSpace($ApplicationName)) {
        return @($result.DeviceApplicationEvidence | Where-Object { ([string]::IsNullOrWhiteSpace($DeviceName) -or $_.DeviceName -eq $DeviceName) -and ([string]::IsNullOrWhiteSpace($ApplicationName) -or $_.ApplicationName -eq $ApplicationName) })
    }
    $result
}
