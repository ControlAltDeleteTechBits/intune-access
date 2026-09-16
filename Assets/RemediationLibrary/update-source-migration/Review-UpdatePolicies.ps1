#requires -Version 7.0
<#
.SYNOPSIS
Connects endpoint update observations to explicitly mapped tenant policy settings.
.DESCRIPTION
Read-only analyst review. Exact setting mappings are administrator supplied.
Targeting and a matching policy setting do not prove effective enforcement.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidencePath,
    [Parameter(Mandatory)][string]$SnapshotPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TenantId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$DeviceId,
    [ValidateRange(1,720)][int]$MaximumAgeHours=24
)
$ErrorActionPreference='Stop'
$parser=Join-Path $PSScriptRoot 'ConvertFrom-IntuneAccessSnapshotJson.ps1'
if(-not (Test-Path -LiteralPath $parser)){$parser=Join-Path $PSScriptRoot '../../../Private/ConvertFrom-IntuneAccessSnapshotJson.ps1'}
. $parser
. (Join-Path (Split-Path $parser) 'Get-IntuneAccessByteHash.ps1')
function Read-ReviewJson {
    param($Path)
    $file=Get-Item -LiteralPath $Path
    if($file.Length -gt 52428800){throw 'Input exceeds 50 MiB.'}
    ConvertFrom-IntuneAccessSnapshotJson -Json (Get-Content -LiteralPath $file.FullName -Raw)
}
$snapshot=Read-ReviewJson $SnapshotPath
if($snapshot.SchemaVersion -ne '2.0' -or $snapshot.Schema -ne 'https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-2.0.json' -or $snapshot.IdentityMode -ne 'Full'){throw 'Use a full-identity schema 2.0 snapshot.'}
if($snapshot.Tenant.Id -cne $TenantId){throw 'Snapshot tenant does not match the selected tenant.'}
$bytes=[Text.Encoding]::UTF8.GetBytes(($snapshot.Data | ConvertTo-Json -Depth 40 -Compress))
$hash=Get-IntuneAccessByteHash -Bytes $bytes
if($hash -cne $snapshot.IntegritySha256){throw 'Snapshot integrity validation failed.'}
$endpoint=Read-ReviewJson $EvidencePath
if($endpoint.Kind -ne 'IntuneAccess.EndpointEvidence' -or $endpoint.SchemaVersion -ne '1.0' -or $endpoint.Investigation -ne 'UpdateSources'){throw 'Use update-source endpoint evidence.'}
$mappings=@($endpoint.Configuration.PolicyMappings)
if($mappings.Count -gt 50){throw 'At most 50 policy mappings are supported.'}
$seen=@{}
foreach($mapping in $mappings){
    if($null -eq $mapping){continue}
    if($mapping.Category -notin @('Quality','Feature','Driver','Other') -or [string]::IsNullOrWhiteSpace($mapping.SettingDefinitionId)){throw 'Policy mappings require an update category and exact setting definition ID.'}
    if($seen.ContainsKey([string]$mapping.SettingDefinitionId)){throw 'Setting definition IDs must be unique across mappings.'}
    $seen[[string]$mapping.SettingDefinitionId]=$true
}
$fresh=$true
foreach($stamp in @($snapshot.Data.CollectedAt,$endpoint.CollectedAt)){
    $parsed=[DateTimeOffset]::MinValue
    if(-not [DateTimeOffset]::TryParse([string]$stamp,[ref]$parsed)){$fresh=$false;continue}
    $hours=([DateTimeOffset]::UtcNow-$parsed).TotalHours
    if($hours -lt -0.083333 -or $hours -gt $MaximumAgeHours){$fresh=$false}
}
$reviewer=Join-Path $PSScriptRoot 'Review-Evidence.ps1'
if(-not (Test-Path -LiteralPath $reviewer)){$reviewer=Join-Path $PSScriptRoot '../investigation-common/Review-Evidence.ps1'}
$review=& $reviewer -EvidencePath $EvidencePath | ConvertFrom-Json -Depth 40
foreach($finding in $review.Findings){
    $ids=@($mappings | Where-Object Category -EQ $finding.Id | ForEach-Object SettingDefinitionId)
    $candidates=@(foreach($setting in @($snapshot.Data.PolicySettings | Where-Object {$_.SettingDefinitionId -cin $ids})){
        $status=@($snapshot.Data.PolicyConflictCollectionStatus | Where-Object WorkloadId -CEQ $setting.WorkloadId)
        $assignment=@($snapshot.Data.DeviceAssignmentExplanations | Where-Object {$_.DeviceId -ceq $DeviceId -and $_.WorkloadId -ceq $setting.WorkloadId})
        $state='NotEvaluated'
        if($fresh -and $status.Count -eq 1 -and $status[0].State -eq 'Available' -and $assignment.Count -eq 1){
            if($assignment[0].AssignmentState -eq 'Included'){$state='TargetedPolicyCandidate'}
            elseif($assignment[0].AssignmentState -eq 'Excluded'){$state='ExcludedInSnapshot'}
        }
        [pscustomobject]@{
            PolicyId=$setting.WorkloadId;PolicyName=$setting.WorkloadName
            SettingDefinitionId=$setting.SettingDefinitionId;ConfiguredValueJson=$setting.ValueJson
            SourceEndpoint=$setting.SourceEndpoint;SourceApiVersion=$setting.SourceApiVersion
            State=$state;Assignments=$assignment;CollectionStatus=$status
            NextStep=if($state -eq 'TargetedPolicyCandidate'){'Open this exact policy and verify the mapped setting and intended source. Review competing GPO and co-management authority before a pilot change.'}
                elseif($state -eq 'ExcludedInSnapshot'){'This snapshot excludes the device. Do not propose changing this policy as its current owner without additional evidence.'}
                else {'Resolve stale, missing or ambiguous collection and assignment evidence before selecting this policy for correction.'}
        }
    })
    $finding.Proposal | Add-Member -NotePropertyName TenantPolicyCandidates -NotePropertyValue $candidates
    $finding.Proposal | Add-Member -NotePropertyName MappingProvenance -NotePropertyValue 'Administrator-supplied exact category/definition mapping; verify against the policy definition before changing anything.'
    $finding.Proposal | Add-Member -NotePropertyName TenantCorrelation -NotePropertyValue $(if(-not $fresh){'NotEvaluated: stale or invalid collection time'}elseif(-not $ids.Count){'NotEvaluated: no exact mapping supplied'}elseif(-not $candidates.Count){'No matching setting observed; absence does not establish absence of policy ownership'}else{'Candidates only; targeting is not proof of effective ownership'})
}
$review | Add-Member -NotePropertyName TenantId -NotePropertyValue $TenantId
$review | Add-Member -NotePropertyName SelectedDeviceId -NotePropertyValue $DeviceId
$review | Add-Member -NotePropertyName IdentityVerified -NotePropertyValue $false
$review | Add-Member -NotePropertyName SnapshotCollectedAt -NotePropertyValue $snapshot.Data.CollectedAt
$review | ConvertTo-Json -Depth 40
