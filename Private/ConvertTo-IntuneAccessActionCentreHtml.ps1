function ConvertTo-IntuneAccessActionCentreHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [object] $Collection)

    $centre = Get-IntuneAccessProperty $Collection 'ActionCentre'
    if ($null -eq $centre) { $centre = Get-IntuneAccessActionCentre -Collection $Collection }
    $tenantId = [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $Collection 'Tenant') 'Id' '')
    $payload = [pscustomobject] @{
        TenantId = $tenantId
        Findings = @($centre.Findings)
        Remediations = @($centre.RemediationEffectiveness)
        Library = @(Get-IntuneAccessRemediationLibrary)
        Applications = @((Get-IntuneAccessProperty $Collection 'ApplicationDefinitions' @()) | Where-Object {
            ([string](Get-IntuneAccessProperty $_ 'ODataType')).TrimStart('#') -eq 'microsoft.graph.win32LobApp'
        } | ForEach-Object {
            [pscustomobject]@{
                '@odata.type'='#microsoft.graph.win32LobApp'
                id=Get-IntuneAccessProperty $_ 'Id'
                displayName=Get-IntuneAccessProperty $_ 'DisplayName'
                rules=@((Get-IntuneAccessProperty $_ 'Rules' @()) | ForEach-Object {
                    $sourceRule=$_;$safeRule=[ordered]@{}
                    foreach($field in @('@odata.type','ruleType','check32BitOn64System','keyPath','valueName','operationType','operator','comparisonValue','path','fileOrFolderName','productCode','productVersion')){
                        $value=Get-IntuneAccessProperty $sourceRule $field
                        if($null -ne $value){$safeRule[$field]=$value}
                    }
                    [pscustomobject]$safeRule
                })
                installExperience=Get-IntuneAccessProperty $_ 'InstallExperience'
                SourceApiVersion=Get-IntuneAccessProperty $_ 'SourceApiVersion'
                TenantId=$tenantId
                CollectedAt=Get-IntuneAccessProperty $Collection 'GeneratedAt'
            }
        })
        Verification = @(Get-IntuneAccessProperty $Collection 'FindingVerification' @())
        GeneratedAt = Get-IntuneAccessProperty $Collection 'GeneratedAt'
    } | ConvertTo-Json -Depth 45 -Compress
    # Inert JSON still needs escaping to prevent tenant values ending a script tag.
    $payload = $payload.Replace('&', '\u0026').Replace('<', '\u003c').Replace('>', '\u003e')
    $template = Get-Content -LiteralPath (Join-Path $script:IntuneAccessModuleRoot 'Assets/action-centre.html') -Raw
    $template.Replace('__INTUNEACCESS_ACTION_DATA__', $payload)
}
