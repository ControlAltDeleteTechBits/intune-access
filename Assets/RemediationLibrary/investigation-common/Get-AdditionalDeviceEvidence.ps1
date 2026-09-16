#requires -Version 5.1
function Get-AdditionalDeviceEvidence {
    [CmdletBinding()]
    param([switch]$Certificates,[switch]$Events)
    if($Certificates){
        foreach($store in @('Cert:\LocalMachine\My','Cert:\CurrentUser\My')){
            try {
                $items=@(Get-ChildItem -LiteralPath $store -ErrorAction Stop | Select-Object -First 501)
                if($items.Count -gt 500){throw 'Certificate store exceeds the 500-record limit.'}
                $metadata=@($items | ForEach-Object {
                    [pscustomobject]@{Thumbprint=$_.Thumbprint;Issuer=$_.Issuer;NotBefore=$_.NotBefore.ToUniversalTime().ToString('o');NotAfter=$_.NotAfter.ToUniversalTime().ToString('o');HasPrivateKey=[bool]$_.HasPrivateKey;EnhancedKeyUsage=@($_.EnhancedKeyUsageList | ForEach-Object {[string]$_.ObjectId} | Sort-Object)}
                } | Sort-Object Thumbprint)
                [pscustomobject]@{Key="certificates/$store";State='Observed';Value=$metadata;Source=$store;Detail='Metadata only. No private key material, subject or SAN exported. Key presence does not prove the application can use it. CurrentUser is the executing identity.'}
            } catch {[pscustomobject]@{Key="certificates/$store";State='Unavailable';Value=$null;Source=$store;Detail=$_.Exception.Message}}
        }
    }
    if($Events){
        $end=Get-Date;$start=$end.AddDays(-7)
        foreach($log in @('Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Admin','Microsoft-Windows-WindowsUpdateClient/Operational')){
            try {
                $items=@(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=$start;EndTime=$end;Level=@(2,3)} -MaxEvents 101 -ErrorAction Stop)
                $metadata=@($items | Select-Object -First 100 | ForEach-Object {[pscustomobject]@{Id=$_.Id;RecordId=$_.RecordId;TimeCreated=$_.TimeCreated.ToUniversalTime().ToString('o');Level=$_.Level;Provider=$_.ProviderName}})
                [pscustomobject]@{Key="events/$log";State='Observed';Value=@{WindowStart=$start.ToUniversalTime().ToString('o');WindowEnd=$end.ToUniversalTime().ToString('o');LimitReached=($items.Count -gt 100);Events=$metadata};Source=$log;Detail='Last seven days, warning/error metadata only, newest 100 records. No event messages or XML payloads. Event absence does not prove health.'}
            } catch {
                if($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*'){
                    [pscustomobject]@{Key="events/$log";State='Observed';Value=@{WindowStart=$start.ToUniversalTime().ToString('o');WindowEnd=$end.ToUniversalTime().ToString('o');LimitReached=$false;Events=@()};Source=$log;Detail='No matching events returned in the bounded query. This is not proof of health.'}
                } else {[pscustomobject]@{Key="events/$log";State='Unavailable';Value=$null;Source=$log;Detail=$_.Exception.Message}}
            }
        }
    }
}
