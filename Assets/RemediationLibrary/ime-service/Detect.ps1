# External deployment only. Run as SYSTEM in 64-bit Windows PowerShell.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
try {
    $service = Get-Service -Name 'IntuneManagementExtension' -ErrorAction Stop
    if ($service.StartType -eq 'Disabled') { Write-Output 'Service is disabled. Investigate configuration; no automatic repair is suitable.'; exit 2 }
    if ($service.Status -eq 'Running') { Write-Output 'Intune Management Extension service is running.'; exit 0 }
    if ($service.Status -eq 'Stopped') { Write-Output 'Intune Management Extension service is stopped.'; exit 1 }
    Write-Output 'Service is transitioning or paused. Investigate before changing it.'
    exit 2
}
catch { Write-Output 'Unable to inspect Intune Management Extension service. Check installation and permissions.'; exit 2 }
