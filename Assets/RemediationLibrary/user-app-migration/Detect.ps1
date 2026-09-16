#requires -Version 5.1
<#
.SYNOPSIS
Exports local per-user application migration evidence evidence. No configuration changes.
#>
[CmdletBinding()]
param([string]$ConfigurationPath)
& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Investigation 'UserApplication' -ConfigurationPath $ConfigurationPath
