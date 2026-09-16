#requires -Version 5.1
<#
.SYNOPSIS
Produces a review-only registry-view correction proposal from endpoint evidence.
.DESCRIPTION
Writes JSON to the pipeline. Does not update Intune or execute imported content.
The proposal is not a Graph PATCH body and requires comparison with current tenant rules.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidencePath)
$ErrorActionPreference='Stop'
$file=Get-Item -LiteralPath $EvidencePath
if($file.Length -gt 10485760){throw 'Evidence exceeds 10 MiB.'}
$data=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
if($data.Investigation -ne 'ApplicationDetection' -or [string]::IsNullOrWhiteSpace($data.Configuration.ApplicationId)){throw 'Use evidence collected from an imported application configuration.'}
$review=& (Join-Path $PSScriptRoot 'Review-Evidence.ps1') -EvidencePath $EvidencePath | ConvertFrom-Json
if($review.ContextAssessment -notin @('SystemContextMatched','SelectedUserContextMatched')){throw 'Application execution context has not been matched. Recollect in the required context before proposing a correction.'}
$changes=[Collections.Generic.List[object]]::new()
foreach($finding in $review.Findings){
    if($finding.State -ne 'ArchitectureMismatchCandidate'){continue}
    $rules=@($data.Configuration.Rules | Where-Object Id -eq $finding.Id)
    if($rules.Count -ne 1){throw 'Rule identity is not unique.'}
    $rule=$rules[0];$source=$rule.SourceRule
    if($null -eq $source -or $source.ruleType -ne 'detection' -or $source.operationType -ne 'string' -or $source.operator -ne 'equal' -or
       $source.check32BitOn64System -isnot [bool] -or $source.valueName -cne $rule.Name -or $source.comparisonValue -cne $rule.ExpectedValue){throw 'Source rule does not match the evaluated condition.'}
    $path=([string]$source.keyPath) -replace '^HKEY_LOCAL_MACHINE\\','HKLM\' -replace '^HKEY_CURRENT_USER\\','HKCU\'
    $view=if($source.check32BitOn64System){'Registry32'}else{'Registry64'}
    if($path -cne $rule.Path -or $view -ne $rule.View){throw 'Source path or architecture does not match the evaluated condition.'}
    $proposed=$source | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $proposed.check32BitOn64System=$finding.Proposal.ProposedView -eq 'Registry32'
    $changes.Add([pscustomobject]@{RuleId=$rule.Id;OriginalRule=$source;ProposedRule=$proposed;Reason=$finding.Explanation;Evidence=$finding.Evidence})
}
[pscustomobject]@{
    SchemaVersion='1.0';Kind='IntuneAccess.DetectionCorrectionProposal';ApplicationId=$data.Configuration.ApplicationId
    Changes=$changes.ToArray();Applied=$false;ReadyToApply=$false
    Preconditions=@('Verify the source application and all its current rules in the intended tenant.','Confirm the alternative registry value identifies the intended product and version.','Confirm the affected user or SYSTEM context matches the Intune application context.','Retain all other detection and requirement rules. Unsupported conditions still require manual review.')
    Verification='Pilot the reviewed rule change, recollect evidence and check Intune detection results. A matching value is not proof that the application works.'
    Recovery='Record the complete original rules before any external change and restore the reviewed original rule if the pilot fails.'
} | ConvertTo-Json -Depth 30
