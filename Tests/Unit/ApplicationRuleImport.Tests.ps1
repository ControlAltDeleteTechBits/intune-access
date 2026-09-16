BeforeAll {
    $script:converter=Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/application-detection/Convert-ApplicationRules.ps1'
    $script:reviewer=Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/investigation-common/Review-Evidence.ps1'
    function Save-AppFixture {
        param($Rules)
        $path=Join-Path $TestDrive 'app.json'
        @{ '@odata.type'='#microsoft.graph.win32LobApp';id='fixture-app';displayName='Fixture';installExperience=@{runAsAccount='system'};rules=@($Rules) } | ConvertTo-Json -Depth 15 | Set-Content $path
        $path
    }
}
Describe 'Graph application rule import' {
    It 'preserves imported file-version operators and numeric version ordering' -TestCases @(
        @{Operator='greaterThan';Observed='1.10.0';ExpectedValue='1.9.0';State='Matches'},
        @{Operator='greaterThanOrEqual';Observed='1.9.0';ExpectedValue='1.9.0';State='Matches'},
        @{Operator='lessThan';Observed='1.9.0';ExpectedValue='1.10.0';State='Matches'},
        @{Operator='lessThanOrEqual';Observed='1.9.0';ExpectedValue='1.9.0';State='Matches'},
        @{Operator='equal';Observed='1.9.0';ExpectedValue='1.9.0';State='Matches'},
        @{Operator='notEqual';Observed='1.9.0';ExpectedValue='1.9.0';State='Mismatch'},
        @{Operator='equal';Observed='release-1';ExpectedValue='1.9.0';State='NotEvaluated'},
        @{Operator='equal';Observed=$null;ExpectedValue='1.9.0';State='NotEvaluated'}
    ) {
        param($Operator,$Observed,$ExpectedValue,$State)
        $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppFileSystemRule';ruleType='detection';path='C:\Apps';fileOrFolderName='app.exe';operationType='version';operator=$Operator;comparisonValue=$ExpectedValue;check32BitOn64System=$false})
        $configuration=& $converter -ApplicationPath $path | ConvertFrom-Json
        $configuration.Rules[0].Type | Should -Be 'File'
        $configuration.Rules[0].AllowDirectory | Should -BeFalse
        $configuration.Rules[0].Operator | Should -Be $Operator
        $evidence=Join-Path $TestDrive 'version-evidence.json'
        @{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='ApplicationDetection';Context=@{IsSystem=$true;UserSid='S-1-5-18'};Configuration=$configuration;Facts=@(@{Key='rule/detection-1/File';State='Observed';Value=@{Version=$Observed}})} | ConvertTo-Json -Depth 20 | Set-Content $evidence
        (& $reviewer -EvidencePath $evidence | ConvertFrom-Json).DetectionConditions | Should -Be $State
    }
    It 'collects real executable version metadata without executing the target file' -Skip:(-not $IsWindows) {
        $target=Join-Path $PSHOME 'pwsh.exe'
        $expected=(Get-Item -LiteralPath $target).VersionInfo.FileVersion
        $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppFileSystemRule';ruleType='detection';path=$PSHOME;fileOrFolderName='pwsh.exe';operationType='version';operator='equal';comparisonValue=$expected;check32BitOn64System=$false})
        $configuration=& $converter -ApplicationPath $path | ConvertFrom-Json
        $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
        $configuration.InstallContext=if($identity.User.Value -eq 'S-1-5-18'){'system'}else{'user'}
        $configuration | Add-Member -NotePropertyName ExpectedUserSid -NotePropertyValue $identity.User.Value
        $configPath=Join-Path $TestDrive 'real-version-config.json'
        $configuration | ConvertTo-Json -Depth 20 | Set-Content $configPath
        $evidence=Join-Path $TestDrive 'real-version-evidence.json'
        & (Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/investigation-common/Collect-Evidence.ps1') -Investigation ApplicationDetection -ConfigurationPath $configPath | Set-Content $evidence
        $collected=Get-Content $evidence -Raw | ConvertFrom-Json
        $collected.Facts[0].Value.Version | Should -Be $expected
        $collected.DeviceConfigurationChanged | Should -BeFalse
        (& $reviewer -EvidencePath $evidence | ConvertFrom-Json).DetectionConditions | Should -Be 'Matches'
    }
    It 'imports literal file and folder existence and reviews local observations' -Skip:(-not $IsWindows) {
        $folder=Join-Path $TestDrive 'present'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $TestDrive 'marker.txt') -Force | Out-Null
        foreach($name in @('present','marker.txt','missing')){
            $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppFileSystemRule';ruleType='detection';path=[string]$TestDrive;fileOrFolderName=$name;operationType='exists';operator='notConfigured';check32BitOn64System=$false})
            $configuration=& $converter -ApplicationPath $path | ConvertFrom-Json
            $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
            $configuration.InstallContext=if($identity.User.Value -eq 'S-1-5-18'){'system'}else{'user'}
            $configuration | Add-Member -NotePropertyName ExpectedUserSid -NotePropertyValue $identity.User.Value
            $configuration.Rules[0].Type | Should -Be 'File'
            $configuration.Rules[0].AllowDirectory | Should -BeTrue
            $configPath=Join-Path $TestDrive 'file-config.json'
            $configuration | ConvertTo-Json -Depth 20 | Set-Content $configPath
            $collector=Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/investigation-common/Collect-Evidence.ps1'
            $evidence=Join-Path $TestDrive 'file-evidence.json'
            & $collector -Investigation ApplicationDetection -ConfigurationPath $configPath | Set-Content $evidence
            $review=& $reviewer -EvidencePath $evidence | ConvertFrom-Json
            $expected=if($name -ne 'missing'){'Matches'}else{'Mismatch'}
            $review.DetectionConditions | Should -Be $expected
        }
    }
    It 'retains unsafe or context-dependent file paths as blockers' -TestCases @(
        @{Directory='%ProgramFiles%';Name='app.exe'},
        @{Directory='\\server\share';Name='app.exe'},
        @{Directory='C:\Apps';Name='..\app.exe'},
        @{Directory='C:\Apps\..\Windows';Name='app.exe'},
        @{Directory='C:\Apps';Name='*.exe'}
    ) {
        param($Directory,$Name)
        $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppFileSystemRule';ruleType='detection';path=$Directory;fileOrFolderName=$Name;operationType='exists';operator='notConfigured';check32BitOn64System=$true})
        (& $converter -ApplicationPath $path | ConvertFrom-Json).Rules[0].Type | Should -Be 'Unsupported'
    }
    It 'preserves a numeric comparison instead of substituting exact equality' {
        $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';keyPath='HKLM\SOFTWARE\Fixture';valueName='Build';operationType='integer';operator='greaterThanOrEqual';comparisonValue='10';check32BitOn64System=$false})
        $result=& $converter -ApplicationPath $path | ConvertFrom-Json
        $result.Rules[0].ComparisonType | Should -Be 'integer'
        $result.Rules[0].Operator | Should -Be 'greaterThanOrEqual'
        $result.Rules[0].ExpectedValue | Should -Be '10'
    }
    It 'exports only an architecture correction and never applies it' {
        $rule=@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';keyPath='HKLM\SOFTWARE\Fixture';valueName='Version';operationType='string';operator='equal';comparisonValue='1.2';check32BitOn64System=$false}
        $path=Save-AppFixture -Rules @($rule)
        $configuration=& $converter -ApplicationPath $path | ConvertFrom-Json
        $evidence=Join-Path $TestDrive 'proposal-evidence.json'
        @{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='ApplicationDetection';Context=@{IsSystem=$true;UserSid='S-1-5-18'};Configuration=$configuration;Facts=@(
            @{Key='rule/detection-1/Registry64';State='Absent';Value=$null},
            @{Key='rule/detection-1/Registry32';State='Observed';Value='1.2'}
        )} | ConvertTo-Json -Depth 20 | Set-Content $evidence
        Copy-Item -LiteralPath $reviewer -Destination (Join-Path $TestDrive 'Review-Evidence.ps1')
        $proposalScript=Join-Path $TestDrive 'New-DetectionProposal.ps1'
        Copy-Item -LiteralPath (Join-Path (Split-Path $converter) 'New-DetectionProposal.ps1') -Destination $proposalScript
        $proposal=& $proposalScript -EvidencePath $evidence | ConvertFrom-Json
        @($proposal.Changes).Count | Should -Be 1
        $proposal.Applied | Should -BeFalse
        $proposal.ReadyToApply | Should -BeFalse
        $proposal.Changes[0].OriginalRule.check32BitOn64System | Should -BeFalse
        $proposal.Changes[0].ProposedRule.check32BitOn64System | Should -BeTrue
        $proposal.Changes[0].ProposedRule.comparisonValue | Should -Be '1.2'
        $data=Get-Content $evidence -Raw | ConvertFrom-Json
        $data.Configuration.Rules[0].SourceRule.comparisonValue='tampered'
        $data | ConvertTo-Json -Depth 20 | Set-Content $evidence
        {& $proposalScript -EvidencePath $evidence} | Should -Throw '*does not match*'
    }
    It 'retains source data and separates detection from requirements' {
        $rule=@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';keyPath='HKEY_LOCAL_MACHINE\SOFTWARE\Fixture';valueName='Version';operationType='string';operator='equal';comparisonValue='1.2';check32BitOn64System=$true}
        $path=Save-AppFixture -Rules @($rule,@{ruleType='requirement'})
        $result=& $converter -ApplicationPath $path | ConvertFrom-Json
        @($result.Rules).Count | Should -Be 1
        $result.RuleCombination | Should -Be 'All'
        $result.Rules[0].View | Should -Be 'Registry32'
        $result.Rules[0].Path | Should -Be 'HKLM\SOFTWARE\Fixture'
        $result.Rules[0].SourceRule.comparisonValue | Should -Be '1.2'
    }
    It 'preserves unsupported operators as blockers instead of dropping conditions' {
        $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';operator='greaterThan';operationType='version'})
        $result=& $converter -ApplicationPath $path | ConvertFrom-Json
        $result.Rules[0].Type | Should -Be 'Unsupported'
        $evidence=Join-Path $TestDrive 'evidence.json'
        @{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='ApplicationDetection';Configuration=$result;Facts=@()} | ConvertTo-Json -Depth 20 | Set-Content $evidence
        $review=& $reviewer -EvidencePath $evidence | ConvertFrom-Json
        $review.DetectionConditions | Should -Be 'NotEvaluated'
        $review.Findings[0].State | Should -Be 'NotEvaluated'
    }
    It 'does not convert a missing architecture flag into a 64-bit assertion' {
        $path=Save-AppFixture -Rules @(@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';keyPath='HKLM\SOFTWARE\Fixture';valueName='Version';operator='equal';operationType='string';comparisonValue='1'})
        (& $converter -ApplicationPath $path | ConvertFrom-Json).Rules[0].Type | Should -Be 'Unsupported'
    }
    It 'rejects an application without detection rules' {
        $path=Save-AppFixture -Rules @(@{ruleType='requirement'})
        {& $converter -ApplicationPath $path} | Should -Throw '*detection rules*'
    }
}
