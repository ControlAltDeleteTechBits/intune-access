#requires -Version 5.1
<#
.SYNOPSIS
Explains supported local evidence and produces proposals, never device changes.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidencePath)
$ErrorActionPreference='Stop'
$file=Get-Item -LiteralPath $EvidencePath
if($file.Length -gt 10485760){throw 'Evidence exceeds 10 MiB.'}
$data=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
if($data.Kind -ne 'IntuneAccess.EndpointEvidence' -or $data.SchemaVersion -ne '1.0'){throw 'Unsupported evidence schema.'}
$index=@{}
if(@($data.Facts).Count -gt 1000){throw 'Too many evidence facts.'}
foreach($fact in $data.Facts){if([string]::IsNullOrWhiteSpace($fact.Key) -or $index.ContainsKey([string]$fact.Key)){throw 'Invalid or duplicate fact key.'};if($fact.State -notin @('Observed','Absent','Unavailable')){throw 'Unsupported fact state.'};$index[[string]$fact.Key]=$fact}
$findings=[Collections.Generic.List[object]]::new()
function Add-Review {
    param($Id,$State,$Explanation,$Proposal,$Evidence)
    $findings.Add([pscustomobject]@{Id=$Id;State=$State;Explanation=$Explanation;Proposal=$Proposal;Evidence=$Evidence;Applied=$false})
}
function Compare-TypedDetection {
    param($Observed,$Expected,$ComparisonType,$Operator)
    if($null -eq $Observed -or $null -eq $Expected -or $Observed -is [array]){return 'NotEvaluated'}
    if($ComparisonType -eq 'integer'){
        $left=0L;$right=0L
        if([string]$Observed -notmatch '^[+-]?\d+$' -or [string]$Expected -notmatch '^[+-]?\d+$' -or
            -not [long]::TryParse([string]$Observed,[ref]$left) -or -not [long]::TryParse([string]$Expected,[ref]$right)){return 'NotEvaluated'}
    } elseif($ComparisonType -eq 'version'){
        $left=$null;$right=$null
        if([string]$Observed -notmatch '^\d+\.\d+(\.\d+){0,2}$' -or [string]$Expected -notmatch '^\d+\.\d+(\.\d+){0,2}$' -or
            -not [version]::TryParse([string]$Observed,[ref]$left) -or -not [version]::TryParse([string]$Expected,[ref]$right)){return 'NotEvaluated'}
    } else {return 'NotEvaluated'}
    $order=$left.CompareTo($right)
    $match=switch($Operator){
        'equal' {$order -eq 0}
        'notEqual' {$order -ne 0}
        'greaterThan' {$order -gt 0}
        'greaterThanOrEqual' {$order -ge 0}
        'lessThan' {$order -lt 0}
        'lessThanOrEqual' {$order -le 0}
        default {return 'NotEvaluated'}
    }
    if($match){'Matches'}else{'Mismatch'}
}
switch($data.Investigation){
    'ApplicationDetection' {
        foreach($rule in $data.Configuration.Rules){
            if($rule.Type -in @('Registry','File') -and $rule.PSObject.Properties['ComparisonType']){
                $view=if($rule.Type -eq 'File'){'File'}else{[string]$rule.View}
                $fact=$index["rule/$($rule.Id)/$view"]
                $result='NotEvaluated'
                if($view -in @('Registry32','Registry64','File') -and $null -ne $fact){
                    if($fact.State -eq 'Absent'){$result='Mismatch'}
                    elseif($fact.State -eq 'Observed'){
                        $observed=if($rule.Type -eq 'File'){$fact.Value.Version}else{$fact.Value}
                        $result=Compare-TypedDetection -Observed $observed -Expected $rule.ExpectedValue -ComparisonType $rule.ComparisonType -Operator $rule.Operator
                    }
                }
                Add-Review -Id $rule.Id -State $result -Explanation "Comparison: $($rule.ComparisonType), operator $($rule.Operator), expected $($rule.ExpectedValue), view $view." -Proposal 'Review the observed value and original rule. Unsupported formats and Intune version string fallback are not emulated; no threshold is weakened automatically.' -Evidence $fact
                continue
            }
            if($rule.PSObject.Properties['Operator'] -and $rule.Operator -ne 'equal'){
                Add-Review -Id $rule.Id -State 'NotEvaluated' -Explanation 'This comparison operator is not supported by this reviewer.' -Proposal 'Preserve the original Intune operator; do not substitute an equality check.' -Evidence $rule;continue
            }
            if($rule.Type -eq 'Registry'){
                $view=[string]$rule.View
                if($view -notin @('Registry32','Registry64')){Add-Review -Id $rule.Id -State 'NotEvaluated' -Explanation 'The intended registry view is not configured.' -Proposal 'Specify the view configured in Intune.' -Evidence @();continue}
                $fact=$index["rule/$($rule.Id)/$view"]
                $otherView=if($view -eq 'Registry64'){'Registry32'}else{'Registry64'}
                $other=$index["rule/$($rule.Id)/$otherView"]
                $expectedProperty=$rule.PSObject.Properties['ExpectedValue']
                if($null -eq $expectedProperty -or $null -eq $fact -or $fact.State -eq 'Unavailable'){
                    Add-Review -Id $rule.Id -State 'NotEvaluated' -Explanation 'Expected value or evidence is unavailable.' -Proposal 'Review configuration and collection errors.' -Evidence $fact
                } elseif($fact.State -eq 'Observed' -and [string]$fact.Value -ceq [string]$rule.ExpectedValue){
                    Add-Review -Id $rule.Id -State 'Matches' -Explanation 'The value matches in the configured registry view.' -Proposal 'No correction proposed. This is not proof of application health.' -Evidence $fact
                } elseif($null -ne $other -and $other.State -eq 'Observed' -and [string]$other.Value -ceq [string]$rule.ExpectedValue){
                    Add-Review -Id $rule.Id -State 'ArchitectureMismatchCandidate' -Explanation 'The expected value exists only in the alternative registry view or differs in the configured view.' -Proposal ([pscustomobject]@{Action='ReviewDetectionRule';Path=$rule.Path;Name=$rule.Name;ProposedView=$otherView;ExpectedValue=$rule.ExpectedValue;Reason='Confirm this identifies the intended application before editing Intune.'}) -Evidence @($fact,$other)
                } else {Add-Review -Id $rule.Id -State 'Mismatch' -Explanation 'The configured exact value is not observed.' -Proposal 'Check installation, version and execution context. Do not weaken detection to make the error disappear.' -Evidence @($fact,$other)}
            } elseif($rule.Type -eq 'File'){
                $fact=$index["rule/$($rule.Id)/File"]
                if($null -eq $fact -or $fact.State -eq 'Unavailable'){Add-Review -Id $rule.Id -State 'NotEvaluated' -Explanation 'File evidence is unavailable.' -Proposal 'Review the path and execution context.' -Evidence $fact}
                elseif($fact.State -eq 'Absent'){Add-Review -Id $rule.Id -State 'Mismatch' -Explanation 'The expected file was absent in the executing context.' -Proposal 'Check install context and actual path; do not fabricate a detection marker.' -Evidence $fact}
                elseif($rule.PSObject.Properties['ExpectedVersion'] -and [string]$fact.Value.Version -cne [string]$rule.ExpectedVersion){Add-Review -Id $rule.Id -State 'Mismatch' -Explanation 'File version differs from the configured exact version.' -Proposal 'Review whether exact matching is appropriate for a self-updating application.' -Evidence $fact}
                else {Add-Review -Id $rule.Id -State 'Matches' -Explanation 'The configured file observation matches.' -Proposal 'No correction proposed. File presence is not proof of a healthy application.' -Evidence $fact}
            } else {Add-Review -Id $rule.Id -State 'NotEvaluated' -Explanation 'Unsupported detection rule type.' -Proposal 'Review this condition in Intune; it has not been treated as a passing rule.' -Evidence $rule}
        }
    }
    'UpdateSources' {
        foreach($category in @('Quality','Feature','Driver','Other')){
            $name="SetPolicyDrivenUpdateSourceFor${category}Updates"
            $gp=$index["update/$name"]; $mdm=$index["mdm-update/$name"]
            $observed=@(@($gp,$mdm)|Where-Object {$null -ne $_ -and $_.State -eq 'Observed'})
            $expected=$null
            if($null -ne $data.Configuration -and $null -ne $data.Configuration.ExpectedSources){$expected=$data.Configuration.ExpectedSources.$category}
            if($observed.Count -eq 0){Add-Review -Id $category -State 'NotEvaluated' -Explanation 'No explicit per-category source was observed; defaults and other policy conditions require investigation.' -Proposal 'Do not infer the effective source from UseWUServer alone.' -Evidence @($gp,$mdm);continue}
            $values=@($observed|ForEach-Object {[string]$_.Value}|Select-Object -Unique)
            if($values.Count -gt 1){Add-Review -Id $category -State 'ConflictingEvidence' -Explanation 'Policy stores contain different source values; effective ownership is not proven.' -Proposal 'Review Group Policy results and Configuration Manager workload ownership before changing values.' -Evidence $observed}
            elseif($values[0] -notin @('0','1')){Add-Review -Id $category -State 'NotEvaluated' -Explanation 'Unrecognised source value.' -Proposal 'Check the supported Windows policy contract.' -Evidence $observed}
            else {
                $source=if($values[0] -eq '1'){'WSUS'}else{'WindowsUpdate'}
                $state=if($expected -in @('WSUS','WindowsUpdate')){if($expected -eq $source){'Matches'}else{'MigrationMismatch'}}else{'ReviewRequired'}
                Add-Review -Id $category -State $state -Explanation "The observed explicit policy value selects $source. This is not a live scan trace." -Proposal 'Correct the owning policy first. Only consider local cleanup after confirming the previous owner is retired.' -Evidence $observed
            }
        }
    }
    'PolicyResidue' {
        foreach($rule in $data.Configuration.Rules){
            $fact=$index["rule/$($rule.Id)/$($rule.View)"]
            if($null -eq $fact -or $fact.State -eq 'Unavailable'){Add-Review -Id $rule.Id -State 'NotEvaluated' -Explanation 'The configured value could not be evaluated.' -Proposal 'Review the exact registry view and collection errors.' -Evidence $fact}
            elseif($fact.State -eq 'Absent'){Add-Review -Id $rule.Id -State 'ValueAbsent' -Explanation 'The selected value was not observed.' -Proposal 'Absence alone does not establish the effective policy default or resolved behaviour.' -Evidence $fact}
            else {Add-Review -Id $rule.Id -State 'OwnershipReviewRequired' -Explanation 'The selected value remains present. This does not prove it is a policy remnant.' -Proposal 'Compare current assignments, prior snapshot, Group Policy results and setting-specific removal behaviour before any cleanup.' -Evidence $fact}
        }
    }
    'UserApplication' {
        Add-Review -Id 'coverage' -State 'ReviewRequired' -Explanation 'Inventory covers machine installations and only the executing user, not every profile.' -Proposal 'Collect under the affected user. Choose a vendor-specific migration adapter before producing an uninstall package.' -Evidence $data.Context
        $userApps=@($data.Facts|Where-Object {$_.Key -like 'applications/HKCU:*' -and $_.State -eq 'Observed'}|ForEach-Object Value)
        $machineApps=@($data.Facts|Where-Object {$_.Key -like 'applications/HKLM:*' -and $_.State -eq 'Observed'}|ForEach-Object Value)
        foreach($app in $userApps){
            $applicationMatches=@($machineApps|Where-Object {$_.Name -eq $app.Name -and $_.Publisher -eq $app.Publisher})
            if($applicationMatches.Count){Add-Review -Id $app.ProductKey -State 'ParallelInstallationCandidate' -Explanation 'The same display name and publisher appear in user and machine inventory. Product identity and replacement health are not proven.' -Proposal 'Validate the vendor, supported versions, replacement launch and settings backup before migration. No uninstall command is executed.' -Evidence (@($app)+@($applicationMatches))}
        }
    }
    'DeviceComparison' {Add-Review -Id 'comparison' -State 'ReferenceRequired' -Explanation 'This file is one endpoint observation.' -Proposal 'Collect the same investigation on a known-working reference and use Compare-Evidence.ps1. Differences are not automatically causes.' -Evidence $data.Context}
    default {throw 'Unsupported investigation type.'}
}
$combined=$null
$contextAssessment='NotSpecified'
if($data.Investigation -eq 'ApplicationDetection' -and -not [string]::IsNullOrWhiteSpace($data.Configuration.ApplicationId)){
    $contextAssessment='NotEvaluated'
    $context=$data.Context
    $expectedContext=[string]$data.Configuration.InstallContext
    $expectedSid=[string]$data.Configuration.ExpectedUserSid
    if($null -ne $context -and $context.IsSystem -is [bool]){
        if($expectedContext -eq 'system' -and $context.IsSystem -eq $true -and $context.UserSid -eq 'S-1-5-18'){$contextAssessment='SystemContextMatched'}
        elseif($expectedContext -eq 'user' -and $context.IsSystem -eq $false -and $context.UserSid -ne 'S-1-5-18' -and
            $expectedSid -match '^S-1-\d+(-\d+)+$' -and $context.UserSid -ceq $expectedSid){$contextAssessment='SelectedUserContextMatched'}
    }
    if($contextAssessment -eq 'NotEvaluated'){
        Add-Review -Id 'execution-context' -State 'NotEvaluated' -Explanation 'The collected account context has not been matched to the imported application installation context. Individual observations cannot establish the combined detection result.' -Proposal 'Collect SYSTEM applications as SYSTEM. For user applications, explicitly set ExpectedUserSid to the affected user SID and collect as that user. Do not change installation context merely to make a check pass.' -Evidence ([pscustomobject]@{InstallContext=$expectedContext;ExpectedUserSid=$expectedSid;CollectedContext=$context})
    }
}
if($data.Investigation -eq 'UpdateSources'){
    foreach($finding in $findings){
        $category=$finding.Id
        $setting="SetPolicyDrivenUpdateSourceFor${category}Updates"
        $owners=@()
        $rsop=$index['update/GroupPolicyResults']
        if($null -ne $rsop -and $rsop.State -eq 'Observed'){
            $owners=@($rsop.Value | Where-Object {$_.valueName -eq $setting -and $_.deleted -eq $false} |
                Select-Object GPOID,precedence,registryKey,valueName)
        }
        $expected=$null
        if($null -ne $data.Configuration -and $null -ne $data.Configuration.ExpectedSources){$expected=$data.Configuration.ExpectedSources.$category}
        $target=if($expected -in @('WSUS','WindowsUpdate')){$expected}else{'NotSpecified'}
        $finding.Proposal=[pscustomobject]@{
            Action='ReviewOwningUpdatePolicy';ExpectedSource=$target
            ExpectedSourceProvenance='Administrator-supplied collection configuration, not inferred from registry observations.'
            Setting=$setting
            CspPath="./Device/Vendor/MSFT/Policy/Config/Update/$setting"
            GroupPolicyPath='Computer Configuration > Administrative Templates > Windows Components > Windows Update > Manage updates offered from Windows Server Update Service > Specify source service for specific classes of Windows Updates'
            RecordedGroupPolicies=$owners
            OwnershipState=if($owners.Count){'RecordedGroupPolicyCandidate'}else{'NotEstablished'}
            CollectionEvidence=@($rsop,$index['management/ConfigMgrService'],$index['update/UseUpdateClassPolicySource'])
            NextStep=if($target -eq 'NotSpecified'){'Declare the intended source for this update class before proposing a value change.'}
                elseif($owners.Count){'Review the recorded GPO IDs and their current settings in Group Policy Management. Check co-management ownership and MDM policy targeting before changing the owning policy.'}
                else {'Identify the assigned Intune Update CSP policy and check Group Policy results and co-management ownership. Missing RSoP evidence is not proof that Group Policy is absent.'}
            ProposedValue=if($target -eq 'WSUS'){1}elseif($target -eq 'WindowsUpdate'){0}else{$null}
            CleanupAllowed=$false;Applied=$false
            Verification='After an externally approved policy correction, collect fresh evidence and check a subsequent Windows Update scan. Registry agreement alone does not prove the scan source.'
            Recovery='Record the owning policy and its original values before changing it. Restore through the same management authority if the pilot fails.'
            Reference='https://learn.microsoft.com/en-us/windows/deployment/update/wufb-wsus'
        }
    }
}
if($data.Investigation -eq 'ApplicationDetection'){
    $combined=if($findings.Count -eq 0 -or @($findings|Where-Object State -eq 'NotEvaluated').Count){'NotEvaluated'}
    elseif(@($findings|Where-Object State -ne 'Matches').Count){'Mismatch'}else{'Matches'}
    if($data.Configuration.PSObject.Properties['RuleCombination'] -and $data.Configuration.RuleCombination -ne 'All'){$combined='NotEvaluated'}
}
[pscustomobject]@{SchemaVersion='1.0';Kind='IntuneAccess.EndpointReview';Investigation=$data.Investigation;ComputerName=$data.ComputerName;CollectedAt=$data.CollectedAt;ContextAssessment=$contextAssessment;DetectionConditions=$combined;Findings=$findings.ToArray();DeviceConfigurationChanged=$false} | ConvertTo-Json -Depth 18
