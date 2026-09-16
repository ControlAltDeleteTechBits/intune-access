#requires -Version 5.1
<#
.SYNOPSIS
Exports local policy residue investigation evidence. No configuration changes.
#>
[CmdletBinding()]
param([string]$ConfigurationPath)
& (Join-Path $PSScriptRoot 'Collect-Evidence.ps1') -Investigation 'PolicyResidue' -ConfigurationPath $ConfigurationPath
