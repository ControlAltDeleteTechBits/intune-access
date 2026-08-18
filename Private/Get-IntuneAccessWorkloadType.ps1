function Get-IntuneAccessWorkloadType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [object] $InputObject,
        [Parameter(Mandatory)] [string] $DefaultType
    )

    if ($DefaultType -ne 'Configuration') {
        return $DefaultType
    }

    $odataType = [string] (Get-IntuneAccessProperty $InputObject '@odata.type' '')
    $technologies = [string] (Get-IntuneAccessProperty $InputObject 'technologies' '')
    $template = Get-IntuneAccessProperty $InputObject 'templateReference'
    $templateFamily = [string] (Get-IntuneAccessProperty $template 'templateFamily' '')
    $templateName = [string] (Get-IntuneAccessProperty $template 'templateDisplayName' '')
    $classificationText = "$odataType $technologies $templateFamily $templateName".ToLowerInvariant()

    if ($classificationText -match 'endpointsecurity|microsoftsense|securitybaseline|antivirus|firewall|attack surface|account protection|disk encryption') {
        return 'Endpoint security'
    }
    if ($classificationText -match 'windowsupdate|featureupdate|qualityupdate|driverupdate|update ring|deliveryoptimization') {
        return 'Updates'
    }

    return 'Configuration'
}
