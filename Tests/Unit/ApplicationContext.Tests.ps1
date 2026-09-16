BeforeAll {
    $script:reviewer=Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/investigation-common/Review-Evidence.ps1'
}
Describe 'Imported application execution context' {
    It 'only accepts evidence from the declared installation context' -TestCases @(
        @{Install='system';Context=@{IsSystem=$true;UserSid='S-1-5-18'};ExpectedSid='';Expected='Matches'},
        @{Install='system';Context=@{IsSystem=$false;UserSid='S-1-5-21-1'};ExpectedSid='';Expected='NotEvaluated'},
        @{Install='system';Context=@{IsSystem=$true;UserSid='S-1-5-21-1'};ExpectedSid='';Expected='NotEvaluated'},
        @{Install='system';Context=$null;ExpectedSid='';Expected='NotEvaluated'},
        @{Install='system';Context=@{IsSystem='true';UserSid='S-1-5-18'};ExpectedSid='';Expected='NotEvaluated'},
        @{Install='user';Context=@{IsSystem=$false;UserSid='S-1-5-21-1'};ExpectedSid='S-1-5-21-1';Expected='Matches'},
        @{Install='user';Context=@{IsSystem=$false;UserSid='S-1-5-21-1'};ExpectedSid='S-1-5-21-2';Expected='NotEvaluated'},
        @{Install='user';Context=@{IsSystem=$false;UserSid='S-1-5-21-1'};ExpectedSid='';Expected='NotEvaluated'},
        @{Install='user';Context=@{IsSystem=$true;UserSid='S-1-5-18'};ExpectedSid='S-1-5-18';Expected='NotEvaluated'},
        @{Install='unknown';Context=@{IsSystem=$false;UserSid='S-1-5-21-1'};ExpectedSid='S-1-5-21-1';Expected='NotEvaluated'}
    ) {
        param($Install,$Context,$ExpectedSid,$Expected)
        $path=Join-Path $TestDrive 'context.json'
        @{
            SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='ApplicationDetection';Context=$Context
            Configuration=@{ApplicationId='fixture-app';InstallContext=$Install;ExpectedUserSid=$ExpectedSid;Rules=@(@{Id='rule';Type='Registry';View='Registry64';ExpectedValue='1'})}
            Facts=@(@{Key='rule/rule/Registry64';State='Observed';Value='1'})
        } | ConvertTo-Json -Depth 20 | Set-Content $path
        $result=& $reviewer -EvidencePath $path | ConvertFrom-Json
        $result.DetectionConditions | Should -Be $Expected
        $result.Findings[0].State | Should -Be 'Matches'
        if($Expected -eq 'NotEvaluated'){
            $result.ContextAssessment | Should -Be 'NotEvaluated'
            $result.Findings[-1].Id | Should -Be 'execution-context'
        }
    }
    It 'refuses a correction proposal when the account context is unknown' {
        $path=Join-Path $TestDrive 'unknown-context.json'
        @{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='ApplicationDetection';Configuration=@{ApplicationId='fixture-app';InstallContext='system';Rules=@()};Facts=@()} | ConvertTo-Json -Depth 10 | Set-Content $path
        Copy-Item $reviewer (Join-Path $TestDrive 'Review-Evidence.ps1')
        $proposal=Join-Path $TestDrive 'New-DetectionProposal.ps1'
        Copy-Item (Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/application-detection/New-DetectionProposal.ps1') $proposal
        {& $proposal -EvidencePath $path} | Should -Throw '*context*'
    }
}
