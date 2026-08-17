function Get-IntuneAccessProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] [object] $InputObject,
        [Parameter(Mandatory)] [string] $Name,
        [AllowNull()] [object] $Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $Default
}
