#requires -Version 5.1
<#
.SYNOPSIS
Exports local working and affected device comparison evidence. No configuration changes.
#>
[CmdletBinding()]
param([string]$ConfigurationPath)
& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Investigation 'DeviceComparison' -ConfigurationPath $ConfigurationPath
