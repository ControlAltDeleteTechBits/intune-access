#requires -Version 7.0
<#
.SYNOPSIS
Relates selected local policy observations to two integrity-checked tenant snapshots.
.DESCRIPTION
Analyst-side, read-only review. Snapshot hashes detect modification, not authenticity.
Tenant and device IDs are explicitly selected, not automatically trusted from a hostname.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [Parameter(Mandatory)][string]$ReferencePath,
    [Parameter(Mandatory)][string]$CurrentPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TenantId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DeviceId,
    [ValidateRange(1,720)][int]$MaximumAgeHours=24
)
$ErrorActionPreference='Stop'
$parser=Join-Path $PSScriptRoot 'ConvertFrom-IntuneAccessSnapshotJson.ps1'
if(-not (Test-Path -LiteralPath $parser)){$parser=Join-Path $PSScriptRoot '../../../Private/ConvertFrom-IntuneAccessSnapshotJson.ps1'}
. $parser
. (Join-Path (Split-Path $parser) 'Get-IntuneAccessByteHash.ps1')
function Read-BoundedJson {
    param($Path)
    $file=Get-Item -LiteralPath $Path
    if($file.Length -gt 52428800){throw 'Input exceeds 50 MiB.'}
    ConvertFrom-IntuneAccessSnapshotJson -Json (Get-Content -LiteralPath $file.FullName -Raw)
}
$before=Read-BoundedJson -Path $ReferencePath
$current=Read-BoundedJson -Path $CurrentPath
foreach($snapshot in @($before,$current)){
    if($snapshot.SchemaVersion -ne '2.0' -or $snapshot.Schema -ne 'https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-2.0.json' -or $snapshot.IdentityMode -ne 'Full'){throw 'Use full-identity schema 2.0 snapshots.'}
    if($snapshot.Tenant.Id -cne $TenantId){throw 'Snapshot tenant does not match the selected tenant.'}
    $bytes=[Text.Encoding]::UTF8.GetBytes(($snapshot.Data | ConvertTo-Json -Depth 40 -Compress))
    $hash=Get-IntuneAccessByteHash -Bytes $bytes
    if($hash -cne $snapshot.IntegritySha256){throw 'Snapshot integrity validation failed.'}
}
$referenceTime=[DateTimeOffset]::Parse($before.Data.CollectedAt)
$currentTime=[DateTimeOffset]::Parse($current.Data.CollectedAt)
if($currentTime -le $referenceTime){throw 'Current collection must be later than reference collection.'}
$data=Read-BoundedJson -Path $EvidencePath
if($data.Kind -ne 'IntuneAccess.EndpointEvidence' -or $data.SchemaVersion -ne '1.0' -or $data.Investigation -ne 'PolicyResidue'){throw 'Use policy residue endpoint evidence.'}
if(@($data.Facts).Count -gt 1000 -or @($data.Configuration.Rules).Count -gt 50){throw 'Too many rules or facts.'}
$endpointTime=[DateTimeOffset]::Parse($data.CollectedAt)
$fresh=$true
foreach($time in @($currentTime,$endpointTime)){
    $hours=([DateTimeOffset]::UtcNow-$time).TotalHours
    if($hours -lt -0.083333 -or $hours -gt $MaximumAgeHours){$fresh=$false}
}
$index=@{}
foreach($fact in $data.Facts){
    if([string]::IsNullOrWhiteSpace($fact.Key) -or $index.ContainsKey($fact.Key) -or $fact.State -notin @('Observed','Absent','Unavailable')){throw 'Invalid endpoint facts.'}
    $index[$fact.Key]=$fact
}
$rows=@(foreach($rule in $data.Configuration.Rules){
    $state='NotEvaluated';$reason='Exact workload and setting identifiers, fresh evidence and successful collection are required.'
    $prior=@();$present=@();$assignment=@()
    $fact=$index["rule/$($rule.Id)/$($rule.View)"]
    if($fresh -and -not [string]::IsNullOrWhiteSpace($rule.WorkloadId) -and -not [string]::IsNullOrWhiteSpace($rule.SettingDefinitionId)){
        $prior=@($before.Data.PolicySettings | Where-Object {$_.WorkloadId -ceq $rule.WorkloadId -and $_.SettingDefinitionId -ceq $rule.SettingDefinitionId})
        $present=@($current.Data.PolicySettings | Where-Object {$_.WorkloadId -ceq $rule.WorkloadId -and $_.SettingDefinitionId -ceq $rule.SettingDefinitionId})
        $status=@($current.Data.PolicyConflictCollectionStatus | Where-Object WorkloadId -CEQ $rule.WorkloadId)
        $assignment=@($current.Data.DeviceAssignmentExplanations | Where-Object {$_.DeviceId -ceq $DeviceId -and $_.WorkloadId -ceq $rule.WorkloadId})
        if($null -eq $fact -or $fact.State -eq 'Unavailable'){$reason='Local setting evidence is unavailable.'}
        elseif($fact.State -eq 'Absent'){$state='ValueAbsent';$reason='Local value is absent. Effective default and problem resolution are not established.'}
        elseif($present.Count -gt 0){
            $state='StillConfigured';$reason='This exact setting remains in the selected current policy. Do not classify it as residue.'
            if($assignment.Count -eq 1 -and $assignment[0].AssignmentState -eq 'Included'){$state='CurrentlyTargeted';$reason='Current evidence includes this device in the policy assignment. Targeting is not proof of delivery or enforcement.'}
        }
        elseif($prior.Count -gt 0 -and $status.Count -eq 1 -and $status[0].State -eq 'Available'){
            $state='PossibleResidue';$reason='The setting was observed in this policy previously and is absent from its successfully collected current settings, while the local value remains. Other policy owners and setting removal behaviour still require review.'
        }
    }
    [pscustomobject]@{Id=$rule.Id;State=$state;Explanation=$reason;Applied=$false
        Proposal='Review other Intune policies, current Group Policy results and the exact CSP removal contract. No registry removal is authorised by this result.'
        Evidence=@{Local=$fact;PreviousSettings=$prior;CurrentSettings=$present;CurrentAssignments=$assignment;SelectedSetting=$rule;Mapping='Administrator-supplied exact workload and setting IDs; mapping has not been independently verified.'}}
})
[pscustomobject]@{SchemaVersion='1.0';Kind='IntuneAccess.EndpointReview';Investigation='PolicyResidue';ComputerName=$data.ComputerName;CollectedAt=$data.CollectedAt;TenantId=$TenantId;SelectedDeviceId=$DeviceId;IdentityVerified=$false;DeviceConfigurationChanged=$false;Findings=$rows} | ConvertTo-Json -Depth 30
