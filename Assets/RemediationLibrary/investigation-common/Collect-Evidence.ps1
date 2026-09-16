#requires -Version 5.1
<#
.SYNOPSIS
Collects bounded local evidence without changing device configuration.
.DESCRIPTION
Run externally after reviewing this source. Writes JSON to the pipeline only.
No scripts, installers, registry values or commands found in input are executed.
#>
[CmdletBinding()]
param(
    [ValidateSet('ApplicationDetection','UpdateSources','PolicyResidue','UserApplication','DeviceComparison')]
    [string] $Investigation = 'DeviceComparison',
    [string] $ConfigurationPath
)
$ErrorActionPreference = 'Stop'
$facts = [Collections.Generic.List[object]]::new()
function Add-Fact {
    param($Key, $State, $Value, $Source, $Detail)
    $facts.Add([pscustomobject]@{ Key=$Key; State=$State; Value=$Value; Source=$Source; Detail=$Detail })
}
function Read-RegistryFact {
    param([string]$Key, [string]$Path, [string]$Name, [string]$View = 'Registry64')
    $base = $null; $registryKey = $null
    try {
        if ($Path -notmatch '^(HKLM|HKCU)\\(.+)$') { throw 'Only HKLM and the current user HKCU are supported.' }
        $hiveName=$Matches[1]; $subkey=$Matches[2]
        $hive=if($hiveName -eq 'HKLM'){'LocalMachine'}else{'CurrentUser'}
        $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]$hive,[Microsoft.Win32.RegistryView]$View)
        $registryKey=$base.OpenSubKey($subkey,$false)
        if ($null -eq $registryKey -or $Name -notin $registryKey.GetValueNames()) {
            Add-Fact -Key $Key -State 'Absent' -Value $null -Source "$Path [$View]::$Name" -Detail 'Value was not present in this context.'
        } else {
            $value=$registryKey.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($value -is [byte[]]) { throw 'Binary values are not collected.' }
            Add-Fact -Key $Key -State 'Observed' -Value $value -Source "$Path [$View]::$Name" -Detail ([string]$registryKey.GetValueKind($Name))
        }
    } catch { Add-Fact -Key $Key -State 'Unavailable' -Value $null -Source "$Path [$View]::$Name" -Detail $_.Exception.Message }
    finally { if($registryKey){$registryKey.Dispose()}; if($base){$base.Dispose()} }
}
$configuration=$null
if ($ConfigurationPath) {
    $file=Get-Item -LiteralPath $ConfigurationPath
    if($file.Length -gt 1048576){throw 'Configuration exceeds 1 MiB.'}
    $configuration=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
}
if ($env:OS -ne 'Windows_NT') { throw 'This collector supports Windows only.' }
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$systemContext=$identity.User.Value -eq 'S-1-5-18'
if($Investigation -in @('ApplicationDetection','PolicyResidue') -and $null -eq $configuration){throw 'Provide a reviewed configuration JSON file.'}
if($Investigation -in @('ApplicationDetection','PolicyResidue')) {
    $rules=@($configuration.Rules)
    if($rules.Count -lt 1 -or $rules.Count -gt 50){throw 'Specify between 1 and 50 rules.'}
    $ids=@{}
    foreach($rule in $rules){
        if([string]::IsNullOrWhiteSpace($rule.Id) -or $ids.ContainsKey([string]$rule.Id)){throw 'Rule IDs must be nonempty and unique.'}
        $ids[[string]$rule.Id]=$true
        if($rule.Type -eq 'Unsupported'){
            Add-Fact -Key "rule/$($rule.Id)/Unsupported" -State 'Unavailable' -Value $null -Source 'Imported application rule' -Detail 'Unsupported condition retained; no input code was executed.'
        } elseif($rule.Type -eq 'Registry'){
            foreach($view in @('Registry64','Registry32')){Read-RegistryFact -Key "rule/$($rule.Id)/$view" -Path $rule.Path -Name $rule.Name -View $view}
        } elseif($rule.Type -eq 'File' -and $Investigation -eq 'ApplicationDetection'){
            $path=[Environment]::ExpandEnvironmentVariables([string]$rule.Path)
            if($path -notmatch '^[A-Za-z]:\\' -or $path -match '[*?]'){throw 'File rules require an exact local drive path; no UNC paths or wildcards.'}
            try {
                if($rule.Require64BitProcess -eq $true -and -not [Environment]::Is64BitProcess){throw 'Imported literal path requires a 64-bit collector to avoid filesystem redirection.'}
                $item=Get-Item -LiteralPath $path -ErrorAction Stop
                if($item.PSIsContainer -and $rule.AllowDirectory -ne $true){throw 'File rule points to a directory.'}
                Add-Fact -Key "rule/$($rule.Id)/File" -State 'Observed' -Value ([pscustomobject]@{Exists=$true;Version=$item.VersionInfo.FileVersion}) -Source $path -Detail 'File metadata only; content was not executed.'
            } catch [System.Management.Automation.ItemNotFoundException] {Add-Fact -Key "rule/$($rule.Id)/File" -State 'Absent' -Value $null -Source $path -Detail 'File not found.'}
            catch {Add-Fact -Key "rule/$($rule.Id)/File" -State 'Unavailable' -Value $null -Source $path -Detail $_.Exception.Message}
        } else {throw 'Unsupported rule type. Custom PowerShell and MSI detection are not executed.'}
    }
}
if($Investigation -in @('UpdateSources','DeviceComparison')){
    $wu='HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    foreach($name in @('WUServer','WUStatusServer','SetPolicyDrivenUpdateSourceForQualityUpdates','SetPolicyDrivenUpdateSourceForFeatureUpdates','SetPolicyDrivenUpdateSourceForDriverUpdates','SetPolicyDrivenUpdateSourceForOtherUpdates','TargetReleaseVersion','TargetReleaseVersionInfo','ProductVersion')){
        Read-RegistryFact -Key "update/$name" -Path $wu -Name $name
    }
    Read-RegistryFact -Key 'update/UseWUServer' -Path "$wu\AU" -Name 'UseWUServer'
    Read-RegistryFact -Key 'update/UseUpdateClassPolicySource' -Path "$wu\AU" -Name 'UseUpdateClassPolicySource'
    try {
        $policyRows=@(Get-CimInstance -Namespace 'root/RSOP/Computer' -ClassName RSOP_RegistryPolicySetting -OperationTimeoutSec 15 -ErrorAction Stop |
            Where-Object { $_.registryKey -match '^(HKEY_LOCAL_MACHINE\\|HKLM\\)?SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate(\\AU)?$' } |
            Select-Object -First 201 -Property registryKey,valueName,GPOID,precedence,deleted)
        if($policyRows.Count -gt 200){throw 'Update RSoP evidence exceeds 200 rows.'}
        Add-Fact -Key 'update/GroupPolicyResults' -State 'Observed' -Value $policyRows -Source 'root/RSOP/Computer:RSOP_RegistryPolicySetting' -Detail 'Cached computer policy results only; not proof of current enforcement or absence of other owners.'
    } catch {Add-Fact -Key 'update/GroupPolicyResults' -State 'Unavailable' -Value $null -Source 'root/RSOP/Computer:RSOP_RegistryPolicySetting' -Detail $_.Exception.Message}
    foreach($name in @('SetPolicyDrivenUpdateSourceForQualityUpdates','SetPolicyDrivenUpdateSourceForFeatureUpdates','SetPolicyDrivenUpdateSourceForDriverUpdates','SetPolicyDrivenUpdateSourceForOtherUpdates','UpdateServiceUrl')){
        Read-RegistryFact -Key "mdm-update/$name" -Path 'HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update' -Name $name
    }
    try {Add-Fact -Key 'management/ConfigMgrService' -State 'Observed' -Value ([string](Get-Service -Name CcmExec -ErrorAction Stop).Status) -Source 'Service Control Manager' -Detail 'Presence is not proof of update workload ownership.'}
    catch {Add-Fact -Key 'management/ConfigMgrService' -State 'Unavailable' -Value $null -Source 'Service Control Manager' -Detail $_.Exception.Message}
}
if($Investigation -in @('UserApplication','DeviceComparison')){
    foreach($root in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')){
        try {
            $entries=@(Get-ChildItem -LiteralPath $root -ErrorAction Stop)
            if($entries.Count -gt 2000){throw 'Inventory exceeds the per-root limit.'}
            $apps=@($entries | ForEach-Object {Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop} | Where-Object DisplayName | ForEach-Object {
                [pscustomobject]@{Name=[string]$_.DisplayName;Version=[string]$_.DisplayVersion;Publisher=[string]$_.Publisher;ProductKey=[string]$_.PSChildName}
            } | Sort-Object Name,Version,ProductKey)
            Add-Fact -Key "applications/$root" -State 'Observed' -Value $apps -Source $root -Detail 'No uninstall commands collected or executed. HKCU covers only the executing identity.'
        } catch {Add-Fact -Key "applications/$root" -State 'Unavailable' -Value $null -Source $root -Detail $_.Exception.Message}
    }
}
if($Investigation -eq 'DeviceComparison'){
    if($null -ne $configuration){
        foreach($option in @('IncludeCertificateMetadata','IncludeEventMetadata')){
            if($configuration.PSObject.Properties[$option] -and $configuration.$option -isnot [bool]){throw "$option must be a JSON Boolean."}
        }
        if($configuration.IncludeCertificateMetadata -eq $true -or $configuration.IncludeEventMetadata -eq $true){
            . (Join-Path $PSScriptRoot 'Get-AdditionalDeviceEvidence.ps1')
            foreach($extra in @(Get-AdditionalDeviceEvidence -Certificates:($configuration.IncludeCertificateMetadata -eq $true) -Events:($configuration.IncludeEventMetadata -eq $true))){$facts.Add($extra)}
        }
    }
    try {$os=Get-CimInstance Win32_OperatingSystem; Add-Fact -Key 'os/version' -State 'Observed' -Value $os.Version -Source 'Win32_OperatingSystem' -Detail ''; Add-Fact -Key 'os/build' -State 'Observed' -Value $os.BuildNumber -Source 'Win32_OperatingSystem' -Detail ''}catch{Add-Fact -Key 'os/version' -State 'Unavailable' -Value $null -Source 'Win32_OperatingSystem' -Detail $_.Exception.Message}
    foreach($name in @('IntuneManagementExtension','wuauserv','BITS')){
        try {$svc=Get-Service $name -ErrorAction Stop; Add-Fact -Key "service/$name" -State 'Observed' -Value ([pscustomobject]@{Status=[string]$svc.Status;StartType=[string]$svc.StartType}) -Source 'Service Control Manager' -Detail 'A stopped trigger-start service is not necessarily faulty.'}
        catch{Add-Fact -Key "service/$name" -State 'Unavailable' -Value $null -Source 'Service Control Manager' -Detail $_.Exception.Message}
    }
}
[pscustomobject]@{
    SchemaVersion='1.0'; Kind='IntuneAccess.EndpointEvidence'; Investigation=$Investigation
    CollectedAt=[DateTimeOffset]::UtcNow.ToString('o'); ComputerName=$env:COMPUTERNAME
    Context=[pscustomobject]@{UserSid=$identity.User.Value;IsSystem=$systemContext;Process64Bit=[Environment]::Is64BitProcess}
    Facts=$facts.ToArray(); Configuration=$configuration; DeviceConfigurationChanged=$false
    Limitations=@('Local evidence is not proof of tenant assignment or effective policy ownership.','Cloud reporting freshness and device identity must be checked separately.','Output may contain sensitive paths, application names and configuration.','No automatic repair is performed.')
} | ConvertTo-Json -Depth 15
