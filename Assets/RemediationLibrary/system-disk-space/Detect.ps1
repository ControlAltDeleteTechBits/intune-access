# Detection only. No cleanup or file deletion. Run in the approved Windows context.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$minimumFreeBytes = 10GB
try {
    $systemDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
    if ($null -eq $systemDisk -or $null -eq $systemDisk.FreeSpace -or $null -eq $systemDisk.Size -or [long] $systemDisk.Size -le 0) {
        Write-Output 'System drive capacity could not be evaluated.'; exit 2
    }
    $free = [long] $systemDisk.FreeSpace
    if ($free -lt 0 -or $free -gt [long] $systemDisk.Size) { Write-Output 'Inconsistent capacity values; evaluation unavailable.'; exit 2 }
    Write-Output ("System drive free GiB: {0:N1}; review threshold GiB: 10. This is a local operational threshold, not an application requirement." -f ($free / 1GB))
    if ($free -lt $minimumFreeBytes) { exit 1 }
    exit 0
}
catch { Write-Output 'Unable to inspect system drive capacity.'; exit 2 }
