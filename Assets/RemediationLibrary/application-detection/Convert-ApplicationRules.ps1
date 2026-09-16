#requires -Version 5.1
<#
.SYNOPSIS
Converts an exported Graph v1.0 Win32 application into local investigation configuration.
.DESCRIPTION
Reads JSON only. Unsupported rules remain explicit blockers. No Graph calls or device changes.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath)
$ErrorActionPreference='Stop'
$file=Get-Item -LiteralPath $ApplicationPath
if($file.Length -gt 10485760){throw 'Application export exceeds 10 MiB.'}
$app=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
if(([string]$app.'@odata.type').TrimStart('#') -ne 'microsoft.graph.win32LobApp'){throw 'Expected a Graph Win32 application object.'}
if([string]::IsNullOrWhiteSpace($app.id)){throw 'Application ID is required.'}
$rules=@($app.rules | Where-Object {$_.ruleType -eq 'detection'})
if($rules.Count -lt 1 -or $rules.Count -gt 50){throw 'Expected between 1 and 50 detection rules in the v1.0 rules collection.'}
$converted=[Collections.Generic.List[object]]::new()
$position=0
foreach($rule in $rules){
    $position++
    $item=[ordered]@{Id="detection-$position";Type='Unsupported';SourceRule=$rule;Reason='This rule cannot yet be evaluated without changing its semantics.'}
    $type=([string]$rule.'@odata.type').TrimStart('#')
    $supportedComparison=($rule.operationType -eq 'string' -and $rule.operator -eq 'equal') -or
        ($rule.operationType -in @('integer','version') -and $rule.operator -in @('equal','notEqual','greaterThan','greaterThanOrEqual','lessThan','lessThanOrEqual'))
    if($type -eq 'microsoft.graph.win32LobAppRegistryRule' -and $supportedComparison -and
       $rule.check32BitOn64System -is [bool] -and -not [string]::IsNullOrWhiteSpace($rule.valueName) -and $null -ne $rule.comparisonValue){
        $path=([string]$rule.keyPath) -replace '^HKEY_LOCAL_MACHINE\\','HKLM\' -replace '^HKEY_CURRENT_USER\\','HKCU\'
        if($path -match '^(HKLM|HKCU)\\.+'){
            $item.Type='Registry';$item.Remove('Reason')
            $item.Path=$path;$item.Name=[string]$rule.valueName
            $item.View=if($rule.check32BitOn64System){'Registry32'}else{'Registry64'}
            $item.Operator=[string]$rule.operator;$item.ExpectedValue=[string]$rule.comparisonValue
            if($rule.operationType -in @('integer','version')){$item.ComparisonType=[string]$rule.operationType}
        }
    }
    $supportedFileComparison=($rule.operationType -eq 'exists' -and $rule.operator -eq 'notConfigured') -or
        ($rule.operationType -eq 'version' -and $rule.operator -in @('equal','notEqual','greaterThan','greaterThanOrEqual','lessThan','lessThanOrEqual') -and $null -ne $rule.comparisonValue)
    if($type -eq 'microsoft.graph.win32LobAppFileSystemRule' -and $supportedFileComparison -and $rule.check32BitOn64System -is [bool]){
        $directory=[string]$rule.path; $name=[string]$rule.fileOrFolderName
        # Only literal paths: do not emulate Intune environment expansion or accept traversal.
        if($directory -match '^[A-Za-z]:\\' -and $directory -notmatch '[%*?<>|"/]' -and
           $directory.Substring(2) -notmatch ':' -and $directory -notmatch '(^|\\)\.{1,2}(\\|$)' -and
           -not [string]::IsNullOrWhiteSpace($name) -and $name -notmatch '[\\/%*?:<>|"]' -and
           $name -notin @('.','..') -and $name -notmatch '[. ]$'){
            $item.Type='File';$item.Remove('Reason')
            $item.Path=$directory.TrimEnd('\')+'\'+$name
            $item.AllowDirectory=$rule.operationType -eq 'exists';$item.Require64BitProcess=$true
            $item.Operation=[string]$rule.operationType
            if($rule.operationType -eq 'version'){
                $item.ComparisonType='version';$item.Operator=[string]$rule.operator;$item.ExpectedValue=[string]$rule.comparisonValue
            }
        }
    }
    $converted.Add([pscustomobject]$item)
}
[pscustomobject]@{
    SchemaVersion='1.0';Investigation='ApplicationDetection';RuleCombination='All'
    ApplicationId=$app.id;ApplicationName=$app.displayName;ApiVersion=if($app.SourceApiVersion){$app.SourceApiVersion}else{'Unspecified source; v1.0 rule schema'}
    InstallContext=$app.installExperience.runAsAccount
    ImportedAt=[DateTimeOffset]::UtcNow.ToString('o');Rules=$converted.ToArray()
    Limitations=@('Source JSON is untrusted and is not proof of tenant identity.','Named registry string equality, integer and regular version comparisons are supported. Version string fallback is not emulated. Literal file/folder existence and regular file versions require a 64-bit collector; environment expansion, dates and size are not evaluated. Other rules remain explicit NotEvaluated blockers.','No script content is executed. Review execution context before collection.')
} | ConvertTo-Json -Depth 30
