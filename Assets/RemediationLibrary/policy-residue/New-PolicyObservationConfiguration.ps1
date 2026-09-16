#requires -Version 5.1
<#
.SYNOPSIS
Creates an exact observation configuration for a named update CSP setting.
.DESCRIPTION
Produces JSON only. Does not configure policy, remove registry values or infer tenant IDs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('QualityUpdateSource','FeatureUpdateSource')][string]$Setting,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$WorkloadId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$SettingDefinitionId
)
$category=if($Setting -eq 'QualityUpdateSource'){'Quality'}else{'Feature'}
$name="SetPolicyDrivenUpdateSourceFor${category}Updates"
[pscustomobject]@{
    Rules=@([pscustomobject]@{
        Id=$Setting;Type='Registry';Path='HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate';Name=$name;View='Registry64'
        WorkloadId=$WorkloadId;SettingDefinitionId=$SettingDefinitionId
        CspPath="./Device/Vendor/MSFT/Policy/Config/Update/$name"
        SupportedScope='Device';DocumentedDefault=1
        RemovalContract='The CSP supports Delete. Deleting a policy node is not equivalent to forcing Windows Update as the source or removing every local value. Other owners and WSUS configuration must be reviewed. This tool never deletes the node or registry value.'
        AllowedValues=@{WindowsUpdate=0;WSUS=1}
        Reference="https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-update#$($name.ToLowerInvariant())"
        MappingStatus='Administrator must verify the supplied workload and setting-definition IDs refer to this exact CSP setting.'
    })
} | ConvertTo-Json -Depth 10
