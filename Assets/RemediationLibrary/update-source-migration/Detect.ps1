#requires -Version 5.1
<#
.SYNOPSIS
Exports local update source migration review evidence. No configuration changes.
#>
[CmdletBinding()]
param([string]$ConfigurationPath)
& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Investigation 'UpdateSources' -ConfigurationPath $ConfigurationPath
