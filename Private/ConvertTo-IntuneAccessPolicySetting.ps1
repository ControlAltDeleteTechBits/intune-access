function ConvertTo-IntuneAccessCanonicalJson {
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()] [object] $Value)

    if ($Value -is [string]) {
        try { return ($Value | ConvertFrom-Json -Depth 30 | ConvertTo-Json -Depth 30 -Compress) }
        catch { return ($Value | ConvertTo-Json -Compress) }
    }
    $Value | ConvertTo-Json -Depth 30 -Compress
}

function ConvertTo-IntuneAccessPolicySettingLeaf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $SettingInstance,
        [Parameter(Mandatory)] [object] $Workload,
        [string] $Path = 'setting'
    )

    $definitionId = [string] (Get-IntuneAccessProperty $SettingInstance 'settingDefinitionId' (Get-IntuneAccessProperty $SettingInstance 'definitionId' ''))
    $odataType = [string] (Get-IntuneAccessProperty $SettingInstance '@odata.type' '')
    $values = [Collections.Generic.List[object]]::new()
    $children = [Collections.Generic.List[object]]::new()

    $choice = Get-IntuneAccessProperty $SettingInstance 'choiceSettingValue'
    if ($null -ne $choice) {
        $choiceValue = Get-IntuneAccessProperty $choice 'value'
        if ($null -ne $choiceValue) { $values.Add($choiceValue) }
        foreach ($child in @(Get-IntuneAccessProperty $choice 'children' @())) { $children.Add($child) }
    }
    $simple = Get-IntuneAccessProperty $SettingInstance 'simpleSettingValue'
    if ($null -ne $simple) {
        $simpleValue = Get-IntuneAccessProperty $simple 'value'
        if ($null -ne $simpleValue) { $values.Add($simpleValue) }
    }
    foreach ($collectionValue in @(Get-IntuneAccessProperty $SettingInstance 'simpleSettingCollectionValue' @())) {
        $itemValue = Get-IntuneAccessProperty $collectionValue 'value'
        if ($null -ne $itemValue) { $values.Add($itemValue) }
    }
    foreach ($groupValue in @(Get-IntuneAccessProperty $SettingInstance 'groupSettingCollectionValue' @())) {
        foreach ($child in @(Get-IntuneAccessProperty $groupValue 'children' @())) { $children.Add($child) }
    }
    foreach ($child in @(Get-IntuneAccessProperty $SettingInstance 'children' @())) { $children.Add($child) }

    $valueJson = [string] (Get-IntuneAccessProperty $SettingInstance 'valueJson' '')
    if (-not [string]::IsNullOrWhiteSpace($valueJson)) { $values.Add($valueJson) }

    if (-not [string]::IsNullOrWhiteSpace($definitionId) -and $values.Count -gt 0) {
        foreach ($value in $values) {
            [PSCustomObject] @{
                PSTypeName          = 'IntuneAccess.PolicySettingValue'
                WorkloadId          = [string] $Workload.Id
                WorkloadName        = [string] $Workload.Name
                WorkloadType        = [string] $Workload.WorkloadType
                SettingDefinitionId = $definitionId
                ValueJson           = ConvertTo-IntuneAccessCanonicalJson -Value $value
                InstancePath        = $Path
                ODataType           = $odataType
                SourceApiVersion    = [string] $Workload.SourceApiVersion
                EvidenceState       = 'ObservedSettingValue'
            }
        }
    }

    for ($index = 0; $index -lt $children.Count; $index++) {
        ConvertTo-IntuneAccessPolicySettingLeaf -SettingInstance $children[$index] -Workload $Workload -Path "$Path.children[$index]"
    }
}

function ConvertTo-IntuneAccessLegacyPolicySettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Policy,
        [Parameter(Mandatory)] [object] $Workload
    )

    $excluded = @(
        'id', 'displayName', 'description', 'version', 'createdDateTime', 'lastModifiedDateTime',
        'roleScopeTagIds', 'supportsScopeTags', 'deviceManagementApplicabilityRuleOsEdition',
        'deviceManagementApplicabilityRuleOsVersion', 'deviceManagementApplicabilityRuleDeviceMode',
        'assignments', 'deviceStatusOverview', 'userStatusOverview', 'deviceStatuses', 'userStatuses',
        'settingStateDeviceSummaries', '@odata.context', '@odata.type'
    )
    foreach ($property in $Policy.PSObject.Properties | Where-Object MemberType -In @('NoteProperty', 'Property')) {
        if ($property.Name -in $excluded -or $null -eq $property.Value) { continue }
        if ($property.Value -is [string] -and [string]::IsNullOrWhiteSpace($property.Value)) { continue }
        [PSCustomObject] @{
            PSTypeName          = 'IntuneAccess.PolicySettingValue'
            WorkloadId          = [string] $Workload.Id
            WorkloadName        = [string] $Workload.Name
            WorkloadType        = [string] $Workload.WorkloadType
            SettingDefinitionId = "legacy::$($property.Name)"
            ValueJson           = ConvertTo-IntuneAccessCanonicalJson -Value $property.Value
            InstancePath        = "profile.$($property.Name)"
            ODataType           = [string] (Get-IntuneAccessProperty $Policy '@odata.type' '')
            SourceApiVersion    = 'v1.0'
            EvidenceState       = 'ObservedProfileProperty'
        }
    }
}
