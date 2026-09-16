#requires -Version 5.1
<#
.SYNOPSIS
Compares two explicitly selected endpoint evidence files without running their contents.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReferencePath,[Parameter(Mandatory)][string]$DifferencePath,
    [ValidateRange(1,720)][int]$MaximumAgeHours=24)
$ErrorActionPreference='Stop'
function Read-Evidence {
    param($Path)
    $file=Get-Item -LiteralPath $Path
    if($file.Length -gt 10485760){throw 'Evidence exceeds 10 MiB.'}
    $data=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    if($data.SchemaVersion -ne '1.0' -or $data.Kind -ne 'IntuneAccess.EndpointEvidence'){throw 'Unsupported evidence schema.'}
    if(@($data.Facts).Count -gt 1000){throw 'Too many evidence facts.'}
    $keys=@{}
    foreach($fact in $data.Facts){if([string]::IsNullOrWhiteSpace($fact.Key) -or $keys.ContainsKey([string]$fact.Key)){throw 'Invalid or duplicate evidence key.'}; if($fact.State -notin @('Observed','Absent','Unavailable')){throw 'Unsupported fact state.'}; $keys[[string]$fact.Key]=$true}
    return $data
}
$before=Read-Evidence $ReferencePath; $after=Read-Evidence $DifferencePath
if($before.Investigation -ne $after.Investigation){throw 'Choose matching investigation types.'}
$warnings=[Collections.Generic.List[string]]::new()
$contextMatches=($null -ne $before.Context -and $null -ne $after.Context -and
    -not [string]::IsNullOrWhiteSpace($before.Context.UserSid) -and
    $before.Context.UserSid -eq $after.Context.UserSid -and
    $null -ne $before.Context.IsSystem -and $null -ne $after.Context.IsSystem -and
    $before.Context.IsSystem -eq $after.Context.IsSystem -and
    $null -ne $before.Context.Process64Bit -and $null -ne $after.Context.Process64Bit -and
    $before.Context.Process64Bit -eq $after.Context.Process64Bit)
if(-not $contextMatches){$warnings.Add('Execution contexts differ or are incomplete. User-scoped observations are not directly comparable.')}
foreach($item in @($before,$after)){
    $time=[DateTimeOffset]::MinValue
    if(-not [DateTimeOffset]::TryParse([string]$item.CollectedAt,[ref]$time)){$warnings.Add('Collection time is missing or invalid.');continue}
    $age=([DateTimeOffset]::UtcNow-$time.ToUniversalTime()).TotalHours
    if($age -lt -0.083333){$warnings.Add('Collection time is in the future. Check the endpoint clock.')}
    elseif($age -gt $MaximumAgeHours){$warnings.Add("Evidence is older than the configured $MaximumAgeHours-hour limit.")}
}
if((ConvertTo-Json -InputObject $before.Configuration -Depth 15 -Compress) -cne (ConvertTo-Json -InputObject $after.Configuration -Depth 15 -Compress)){$warnings.Add('Collection configurations differ. Compare identical rules before attributing a difference to the endpoint.')}
if($before.ComputerName -eq $after.ComputerName){$warnings.Add('Both files report the same computer name. This is not evidence of a separate working reference device.')}
$beforeIndex=@{}; $afterIndex=@{}
foreach($fact in $before.Facts){$beforeIndex[[string]$fact.Key]=$fact}
foreach($fact in $after.Facts){$afterIndex[[string]$fact.Key]=$fact}
$rows=@(foreach($key in @(@($beforeIndex.Keys)+@($afterIndex.Keys) | Sort-Object -Unique)){
    $left=$beforeIndex[$key]; $right=$afterIndex[$key]
    $state=if($null -eq $left -or $null -eq $right -or $left.State -eq 'Unavailable' -or $right.State -eq 'Unavailable'){'NotEvaluated'}
    elseif($left.State -eq $right.State -and (ConvertTo-Json -InputObject $left.Value -Depth 12 -Compress) -ceq (ConvertTo-Json -InputObject $right.Value -Depth 12 -Compress)){'Same'}else{'Different'}
    $nextCheck=if($state -eq 'NotEvaluated'){'Recollect the missing or unavailable fact in the required context.'}
    elseif($state -eq 'Same'){'No difference observed for this fact. This does not establish application or device health.'}
    elseif($key -like 'update/*' -or $key -like 'mdm-update/*'){'Compare the owning Group Policy or CSP and intended update class before changing either device.'}
    elseif($key -like 'applications/*'){'Confirm product identity, architecture and install scope; do not uninstall based on a display-name difference.'}
    elseif($key -like 'certificates/*'){'Different device certificates are expected. Compare purpose, issuer, validity, store and application context. Do not copy private keys or delete certificates based on this difference.'}
    elseif($key -like 'events/*'){'Compare the time window, provider and event ID with the reported incident. Inspect the selected records locally for details; disappearance of an event does not prove a fix.'}
    else {'Check whether this difference is relevant to the reported symptom. Change one approved variable and recollect both observations.'}
    [pscustomobject]@{Key=$key;State=$state;Reference=$left;Difference=$right;NextCheck=$nextCheck}
})
[pscustomobject]@{SchemaVersion='1.0';Kind='IntuneAccess.EndpointComparison';ReferenceComputer=$before.ComputerName;DifferenceComputer=$after.ComputerName;ReferenceTime=$before.CollectedAt;DifferenceTime=$after.CollectedAt;ContextMatches=$contextMatches;Warnings=$warnings.ToArray();IdentityVerified=$false;DeviceConfigurationChanged=$false;Rows=$rows;Conclusion='Differences are observations, not proven causes or proof that a problem is resolved.'} | ConvertTo-Json -Depth 18
