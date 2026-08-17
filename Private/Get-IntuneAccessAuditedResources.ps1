function Get-IntuneAccessAuditedResources {
    [CmdletBinding()]
    param(
        [switch] $IncludeExtended
    )

    $requiredScopes = @(
        'DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All'
    )
    if ($IncludeExtended) { $requiredScopes += 'DeviceManagementScripts.Read.All' }
    $null = Assert-IntuneAccessConnection -RequiredScope $requiredScopes

    $sources = [System.Collections.Generic.List[object]]::new()
    $sources.Add([PSCustomObject] @{
        Type = 'Device configuration'
        NameProperty = 'displayName'
        StableUri = 'deviceManagement/deviceConfigurations?$select=id,displayName'
        BetaUri = 'deviceManagement/deviceConfigurations?$select=id,displayName,roleScopeTagIds,supportsScopeTags'
    })
    $sources.Add([PSCustomObject] @{
        Type = 'Mobile app'
        NameProperty = 'displayName'
        StableUri = 'deviceAppManagement/mobileApps?$select=id,displayName'
        BetaUri = 'deviceAppManagement/mobileApps?$select=id,displayName,roleScopeTagIds'
    })
    if ($IncludeExtended) {
        $sources.Add([PSCustomObject] @{
            Type = 'Compliance policy'
            NameProperty = 'displayName'
            StableUri = 'deviceManagement/deviceCompliancePolicies?$select=id,displayName'
            BetaUri = 'deviceManagement/deviceCompliancePolicies?$select=id,displayName,roleScopeTagIds'
        })
        $sources.Add([PSCustomObject] @{
            Type = 'Settings Catalog or endpoint security policy'
            NameProperty = 'name'
            StableUri = $null
            BetaUri = 'deviceManagement/configurationPolicies?$select=id,name,roleScopeTagIds,templateReference'
        })
        $sources.Add([PSCustomObject] @{
            Type = 'Remediation or device health script'
            NameProperty = 'displayName'
            StableUri = $null
            BetaUri = 'deviceManagement/deviceHealthScripts?$select=id,displayName,roleScopeTagIds,deviceHealthScriptType'
        })
    }
    $resources = [System.Collections.Generic.List[object]]::new()
    foreach ($source in $sources) {
        $stableItems = @()
        if (-not [string]::IsNullOrWhiteSpace([string] $source.StableUri)) {
            $stableItems = @(Invoke-IntuneAccessGraphRequest -Uri $source.StableUri)
        }
        $betaItems = @()
        try {
            $betaItems = @(Invoke-IntuneAccessGraphRequest -Uri $source.BetaUri -ApiVersion beta)
            if ([string]::IsNullOrWhiteSpace([string] $source.StableUri)) {
                $stableItems = @($betaItems)
            }
        }
        catch {
            Write-Warning "Beta scope-tag enrichment failed for $($source.Type) resources. Stable v1.0 objects are retained with missing tag data. $($_.Exception.Message)"
        }

        foreach ($item in $stableItems) {
            $itemId = [string] (Get-IntuneAccessProperty $item 'id')
            $betaItem = $betaItems | Where-Object {
                [string] (Get-IntuneAccessProperty $_ 'id') -eq $itemId
            } | Select-Object -First 1
            $missingValue = [object]::new()
            $tagValue = Get-IntuneAccessProperty $betaItem 'roleScopeTagIds' $missingValue
            $tagDataState = if ([object]::ReferenceEquals($tagValue, $missingValue)) { 'Missing' } else { 'Available' }
            $tagIds = @(
                $(if ($tagDataState -eq 'Missing') { @() } else { @($tagValue) }) |
                    ForEach-Object { [string] $_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
            if ($tagDataState -eq 'Available' -and $tagIds.Count -eq 0) {
                $tagIds = @('0')
            }
            $resources.Add([PSCustomObject] @{
                ResourceType    = $source.Type
                ResourceId      = [string] (Get-IntuneAccessProperty $item 'id')
                ResourceName    = [string] (Get-IntuneAccessProperty $item $source.NameProperty)
                ScopeTagIds     = $tagIds
                ScopeTagDataState = $tagDataState
                SupportsScopeTags = Get-IntuneAccessProperty $betaItem 'supportsScopeTags' $null
                SourceApiVersion = if ([string]::IsNullOrWhiteSpace([string] $source.StableUri)) { 'beta' } else { 'v1.0+beta' }
                PropertySource = [PSCustomObject] @{
                    Identity = if ([string]::IsNullOrWhiteSpace([string] $source.StableUri)) { 'beta' } else { 'v1.0' }
                    ScopeTags = if ($tagDataState -eq 'Available') { 'beta' } else { 'Missing' }
                }
            })
        }
    }
    return $resources.ToArray()
}
