# CHANGE MAKING: external deployment only, after administrator review.
# Does not install the agent, change startup type, restart or stop a service.
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
try {
    $service = Get-Service -Name 'IntuneManagementExtension' -ErrorAction Stop
    if ($service.StartType -eq 'Disabled') { Write-Output 'Disabled service: no change made.'; exit 2 }
    if ($service.Status -eq 'Running') { Write-Output 'Service already running: no change needed.'; exit 0 }
    if ($service.Status -ne 'Stopped') { Write-Output 'Service not in a stable stopped state: no change made.'; exit 2 }
    if (-not $PSCmdlet.ShouldProcess('IntuneManagementExtension', 'Start the stopped service')) { Write-Output 'Start not approved; no change made.'; exit 2 }
    Start-Service -Name 'IntuneManagementExtension' -ErrorAction Stop
    $service = Get-Service -Name 'IntuneManagementExtension' -ErrorAction Stop
    $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromSeconds(30))
    Write-Output 'Service reached Running. Verify subsequent agent reporting separately.'
    exit 0
}
catch { Write-Output 'Unable to confirm service start. Review the service and Windows event logs; do not assume recovery.'; exit 2 }
