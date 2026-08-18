function Get-IntuneAccessPolicySettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Workload
    )

    $settings = [Collections.Generic.List[object]]::new()
    $status = [Collections.Generic.List[object]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $supportedEndpoints = @('deviceManagement/configurationPolicies', 'deviceManagement/intents', 'deviceManagement/deviceConfigurations')

    foreach ($policy in @($Workload | Where-Object SourceEndpoint -In $supportedEndpoints)) {
        try {
            $rawSettings = @()
            if ($policy.SourceEndpoint -eq 'deviceManagement/deviceConfigurations') {
                $rawPolicy = @(Invoke-IntuneAccessGraphRequest -Uri "$($policy.SourceEndpoint)/$([uri]::EscapeDataString([string] $policy.Id))" -ApiVersion v1.0 | Select-Object -First 1)
                if ($rawPolicy.Count -gt 0) { $rawSettings = @(ConvertTo-IntuneAccessLegacyPolicySettings -Policy $rawPolicy[0] -Workload $policy) }
            }
            else {
                $raw = @(Invoke-IntuneAccessGraphRequest -Uri "$($policy.SourceEndpoint)/$([uri]::EscapeDataString([string] $policy.Id))/settings" -ApiVersion beta)
                foreach ($rawSetting in $raw) {
                    $instance = Get-IntuneAccessProperty $rawSetting 'settingInstance' $rawSetting
                    $rawSettings += @(ConvertTo-IntuneAccessPolicySettingLeaf -SettingInstance $instance -Workload $policy)
                }
            }

            foreach ($settingGroup in @($rawSettings | Group-Object SettingDefinitionId)) {
                $valueSet = @($settingGroup.Group.ValueJson | Sort-Object -Unique)
                $settings.Add([PSCustomObject] @{
                    PSTypeName          = 'IntuneAccess.PolicySetting'
                    Id                  = "$($policy.Id)::$($settingGroup.Name)"
                    WorkloadId          = [string] $policy.Id
                    WorkloadName        = [string] $policy.Name
                    WorkloadType        = [string] $policy.WorkloadType
                    SettingDefinitionId = [string] $settingGroup.Name
                    ValueJson           = $valueSet | ConvertTo-Json -Compress
                    ValueCount          = $valueSet.Count
                    InstancePaths       = @($settingGroup.Group.InstancePath | Sort-Object -Unique)
                    ODataTypes          = @($settingGroup.Group.ODataType | Where-Object { $_ } | Sort-Object -Unique)
                    SourceEndpoint      = [string] $policy.SourceEndpoint
                    SourceApiVersion    = [string] $policy.SourceApiVersion
                    EvidenceState       = [string] $settingGroup.Group[0].EvidenceState
                })
            }
            $status.Add([PSCustomObject] @{ WorkloadId = $policy.Id; WorkloadName = $policy.Name; State = 'Available'; SettingCount = @($rawSettings | Group-Object SettingDefinitionId).Count; SourceApiVersion = $policy.SourceApiVersion; Reason = '' })
        }
        catch {
            $reason = $_.Exception.Message
            $status.Add([PSCustomObject] @{ WorkloadId = $policy.Id; WorkloadName = $policy.Name; State = 'Unavailable'; SettingCount = 0; SourceApiVersion = $policy.SourceApiVersion; Reason = $reason })
            $warnings.Add("Settings for '$($policy.Name)' could not be collected. $reason")
        }
    }

    [PSCustomObject] @{
        PSTypeName       = 'IntuneAccess.PolicySettingInventory'
        Settings         = $settings.ToArray()
        CollectionStatus = $status.ToArray()
        Warnings         = $warnings.ToArray()
        SourceBoundary   = 'Settings Catalog, endpoint security intents and supported legacy device configuration properties.'
        GeneratedAt      = [DateTimeOffset]::Now
        ToolVersion      = $script:IntuneAccessVersion
    }
}
