#requires -Version 5.1
<#
.SYNOPSIS
Exports local application detection mismatch evidence. No configuration changes.
#>
[CmdletBinding()]
param([string]$ConfigurationPath)
& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Investigation 'ApplicationDetection' -ConfigurationPath $ConfigurationPath
