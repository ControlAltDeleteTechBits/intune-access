BeforeAll {
    $script:common = Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/investigation-common'
    function Save-TestEvidence {
        param($Name,$Investigation,$Facts,$Configuration)
        $path=Join-Path $TestDrive $Name
        [pscustomobject]@{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation=$Investigation;ComputerName='Fixture';CollectedAt='2026-09-15T10:00:00Z';Context=@{UserSid='fixture';IsSystem=$false};Facts=@($Facts);Configuration=$Configuration} | ConvertTo-Json -Depth 15 | Set-Content $path
        $path
    }
}
Describe 'Bounded endpoint investigations' {
    It 'uses typed comparison for <ComparisonType> <Operator>' -ForEach @(
        @{ComparisonType='integer';Operator='greaterThan';Observed='10';Expected='9';State='Matches'},
        @{ComparisonType='integer';Operator='lessThan';Observed='10';Expected='9';State='Mismatch'},
        @{ComparisonType='integer';Operator='equal';Observed='10';Expected='10';State='Matches'},
        @{ComparisonType='integer';Operator='notEqual';Observed='10';Expected='9';State='Matches'},
        @{ComparisonType='version';Operator='greaterThanOrEqual';Observed='1.10.0';Expected='1.9.0';State='Matches'},
        @{ComparisonType='version';Operator='lessThanOrEqual';Observed='1.9.0';Expected='1.10.0';State='Matches'},
        @{ComparisonType='version';Operator='equal';Observed='release-1';Expected='1.0';State='NotEvaluated'},
        @{ComparisonType='integer';Operator='equal';Observed='999999999999999999999';Expected='1';State='NotEvaluated'},
        @{ComparisonType='integer';Operator='equal';Observed='1.2';Expected='1';State='NotEvaluated'}
    ) {
        $path=Save-TestEvidence -Name 'typed.json' -Investigation 'ApplicationDetection' -Facts @(@{Key='rule/app/Registry64';State='Observed';Value=$Observed}) -Configuration @{Rules=@(@{Id='app';Type='Registry';View='Registry64';ComparisonType=$ComparisonType;Operator=$Operator;ExpectedValue=$Expected})}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be $State
        $result.DetectionConditions | Should -Be $State
    }
    It 'does not silently convert an unsupported operator into equality' {
        $path=Save-TestEvidence -Name 'operator.json' -Investigation 'ApplicationDetection' -Facts @(@{Key='rule/app/Registry64';State='Observed';Value='1'}) -Configuration @{Rules=@(@{Id='app';Type='Registry';View='Registry64';ExpectedValue='1';Operator='greaterThan'})}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'NotEvaluated'
        $result.DetectionConditions | Should -Be 'NotEvaluated'
    }
    It 'requires every supported detection condition to match' {
        $path=Save-TestEvidence -Name 'all-rules.json' -Investigation 'ApplicationDetection' -Facts @(@{Key='rule/a/File';State='Observed';Value=@{Exists=$true}},@{Key='rule/b/File';State='Absent';Value=$null}) -Configuration @{Rules=@(@{Id='a';Type='File'},@{Id='b';Type='File'})}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.DetectionConditions | Should -Be 'Mismatch'
    }
    It 'flags stale evidence and incomplete execution context' {
        $path=Save-TestEvidence -Name 'old.json' -Investigation 'DeviceComparison' -Facts @(@{Key='a';State='Observed';Value=1}) -Configuration @{}
        $data=Get-Content $path -Raw | ConvertFrom-Json
        $data.CollectedAt='2000-01-01T00:00:00Z'
        $data | ConvertTo-Json -Depth 15 | Set-Content $path
        $result=& "$common/Compare-Evidence.ps1" -ReferencePath $path -DifferencePath $path | ConvertFrom-Json
        $result.ContextMatches | Should -BeFalse
        $result.IdentityVerified | Should -BeFalse
        ($result.Warnings -join ' ') | Should -Match 'older than'
        ($result.Warnings -join ' ') | Should -Match 'same computer'
        $result.Rows[0].NextCheck | Should -Not -BeNullOrEmpty
    }
    It 'rejects invented evidence states instead of reporting a match' {
        $path=Save-TestEvidence -Name 'invalid-state.json' -Investigation 'ApplicationDetection' -Facts @(@{Key='a';State='Success';Value=1}) -Configuration @{}
        {& "$common/Review-Evidence.ps1" -EvidencePath $path} | Should -Throw '*Unsupported fact state*'
    }
    It 'explains alternate registry view without applying a correction' {
        $path=Save-TestEvidence -Name 'app.json' -Investigation 'ApplicationDetection' -Facts @(
            @{Key='rule/app/Registry64';State='Absent';Value=$null},
            @{Key='rule/app/Registry32';State='Observed';Value='1.0'}
        ) -Configuration @{Rules=@(@{Id='app';Type='Registry';Path='HKLM\SOFTWARE\Example';Name='Version';View='Registry64';ExpectedValue='1.0'})}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'ArchitectureMismatchCandidate'
        $result.Findings[0].Proposal.ProposedView | Should -Be 'Registry32'
        $result.Findings[0].Applied | Should -BeFalse
    }
    It 'does not call unavailable application evidence absent' {
        $path=Save-TestEvidence -Name 'unknown.json' -Investigation 'ApplicationDetection' -Facts @(@{Key='rule/app/Registry64';State='Unavailable';Value=$null}) -Configuration @{Rules=@(@{Id='app';Type='Registry';View='Registry64';ExpectedValue='1'})}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'NotEvaluated'
    }
    It 'evaluates update sources per category and retains conflicting stores' {
        $path=Save-TestEvidence -Name 'update.json' -Investigation 'UpdateSources' -Facts @(
            @{Key='update/SetPolicyDrivenUpdateSourceForQualityUpdates';State='Observed';Value=1},
            @{Key='mdm-update/SetPolicyDrivenUpdateSourceForQualityUpdates';State='Observed';Value=0},
            @{Key='update/SetPolicyDrivenUpdateSourceForFeatureUpdates';State='Observed';Value=1}
        ) -Configuration @{ExpectedSources=@{Quality='WindowsUpdate';Feature='WindowsUpdate'}}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'ConflictingEvidence'
        $result.Findings[1].State | Should -Be 'MigrationMismatch'
        $result.Findings[2].State | Should -Be 'NotEvaluated'
        $result.Findings[1].Proposal.ProposedValue | Should -Be 0
        $result.Findings[1].Proposal.CleanupAllowed | Should -BeFalse
        $result.Findings[1].Proposal.OwnershipState | Should -Be 'NotEstablished'
        $result.Findings[1].Proposal.CspPath | Should -Match '/SetPolicyDrivenUpdateSourceForFeatureUpdates$'
    }
    It 'retains recorded GPO ownership without declaring current enforcement' {
        $path=Save-TestEvidence -Name 'rsop.json' -Investigation 'UpdateSources' -Facts @(
            @{Key='update/GroupPolicyResults';State='Observed';Value=@(
                @{valueName='SetPolicyDrivenUpdateSourceForQualityUpdates';GPOID='fixture-gpo';precedence=1;deleted=$false},
                @{valueName='SetPolicyDrivenUpdateSourceForQualityUpdates';GPOID='deleted-gpo';precedence=2;deleted=$true}
            )}
        ) -Configuration @{ExpectedSources=@{Quality='WindowsUpdate'}}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'NotEvaluated'
        $proposal=$result.Findings[0].Proposal
        $proposal.OwnershipState | Should -Be 'RecordedGroupPolicyCandidate'
        @($proposal.RecordedGroupPolicies).Count | Should -Be 1
        $proposal.RecordedGroupPolicies[0].GPOID | Should -Be 'fixture-gpo'
        $proposal.CleanupAllowed | Should -BeFalse
        $result.Findings[1].Proposal.ProposedValue | Should -BeNullOrEmpty
    }
    It 'does not infer orphaned policy ownership from a present value' {
        $path=Save-TestEvidence -Name 'policy.json' -Investigation 'PolicyResidue' -Facts @(@{Key='rule/policy/Registry64';State='Observed';Value=1}) -Configuration @{Rules=@(@{Id='policy';View='Registry64'})}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'OwnershipReviewRequired'
    }
    It 'only proposes review of parallel user and machine installations' {
        $app=@{Name='Example';Publisher='Vendor';Version='1';ProductKey='example'}
        $path=Save-TestEvidence -Name 'user.json' -Investigation 'UserApplication' -Facts @(@{Key='applications/HKCU:\Software\Example';State='Observed';Value=@($app)},@{Key='applications/HKLM:\Software\Example';State='Observed';Value=@($app)}) -Configuration @{}
        $result=& "$common/Review-Evidence.ps1" -EvidencePath $path | ConvertFrom-Json
        $result.Findings[1].State | Should -Be 'ParallelInstallationCandidate'
    }
    It 'compares different values and never clears absent evidence' {
        $before=Save-TestEvidence -Name 'before.json' -Investigation 'DeviceComparison' -Facts @(@{Key='a';State='Observed';Value=1},@{Key='missing';State='Observed';Value=1}) -Configuration @{}
        $after=Save-TestEvidence -Name 'after.json' -Investigation 'DeviceComparison' -Facts @(@{Key='a';State='Observed';Value=2}) -Configuration @{}
        $result=& "$common/Compare-Evidence.ps1" -ReferencePath $before -DifferencePath $after | ConvertFrom-Json
        ($result.Rows|Where-Object Key -eq 'a').State | Should -Be 'Different'
        ($result.Rows|Where-Object Key -eq 'missing').State | Should -Be 'NotEvaluated'
    }
    It 'rejects mixed investigations and duplicate keys' {
        $before=Save-TestEvidence -Name 'one.json' -Investigation 'DeviceComparison' -Facts @(@{Key='a';State='Observed';Value=1}) -Configuration @{}
        $after=Save-TestEvidence -Name 'two.json' -Investigation 'UpdateSources' -Facts @(@{Key='a';State='Observed';Value=1}) -Configuration @{}
        {& "$common/Compare-Evidence.ps1" -ReferencePath $before -DifferencePath $after} | Should -Throw '*matching investigation*'
        $duplicate=Save-TestEvidence -Name 'duplicate.json' -Investigation 'DeviceComparison' -Facts @(@{Key='a';State='Observed';Value=1},@{Key='a';State='Observed';Value=1}) -Configuration @{}
        {& "$common/Compare-Evidence.ps1" -ReferencePath $before -DifferencePath $duplicate} | Should -Throw '*duplicate*'
    }
}
