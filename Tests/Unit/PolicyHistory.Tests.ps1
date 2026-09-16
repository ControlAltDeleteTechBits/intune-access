BeforeAll {
    $script:history=Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/policy-residue/Review-PolicyHistory.ps1'
    function New-HistoryFixture {
        param([string]$Status='Available',[switch]$Present,[switch]$Stale)
        $now=[DateTimeOffset]::UtcNow
        $setting=@{WorkloadId='policy';SettingDefinitionId='setting';ValueJson='1'}
        foreach($label in @('before','current')){
            $settings=if($label -eq 'before' -or $Present){@($setting)}else{@()}
            $time=if($label -eq 'before'){$now.AddDays(-3)}elseif($Stale){$now.AddDays(-2)}else{$now.AddMinutes(-1)}
            $data=[pscustomobject]@{CollectedAt=$time.ToString('o');PolicySettings=@($settings);PolicyConflictCollectionStatus=@(@{WorkloadId='policy';State=$Status});DeviceAssignmentExplanations=@(@{WorkloadId='policy';DeviceId='device';AssignmentState='Included'})}
            $json=$data|ConvertTo-Json -Depth 40 -Compress
            $stream=[IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($json),$false)
            try {$hash=(Get-FileHash -InputStream $stream -Algorithm SHA256).Hash.ToLowerInvariant()}finally{$stream.Dispose()}
            @{SchemaVersion='2.0';Schema='https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-2.0.json';IdentityMode='Full';Tenant=@{Id='tenant'};Data=$data;IntegritySha256=$hash}|ConvertTo-Json -Depth 40|Set-Content (Join-Path $TestDrive "$label.json")
        }
        @{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='PolicyResidue';CollectedAt=$now.ToString('o');ComputerName='fixture';Configuration=@{Rules=@(@{Id='rule';View='Registry64';WorkloadId='policy';SettingDefinitionId='setting'})};Facts=@(@{Key='rule/rule/Registry64';State='Observed';Value=1})}|ConvertTo-Json -Depth 15|Set-Content (Join-Path $TestDrive 'endpoint.json')
        @{EvidencePath=(Join-Path $TestDrive 'endpoint.json');ReferencePath=(Join-Path $TestDrive 'before.json');CurrentPath=(Join-Path $TestDrive 'current.json');TenantId='tenant';DeviceId='device'}
    }
}
Describe 'Policy history evidence review' {
    It 'reviews history from an exported archive with all parser dependencies' {
        Import-Module (Join-Path $PSScriptRoot '../../IntuneAccess.psd1') -Force
        $package=& (Get-Module IntuneAccess) {Get-IntuneAccessRemediationLibrary | Where-Object Id -EQ 'policy-residue'}
        $zipPath=Join-Path $TestDrive 'history.zip'
        [IO.File]::WriteAllBytes($zipPath,[Convert]::FromBase64String($package.PackageBase64))
        $target=Join-Path $TestDrive 'history-export'
        [IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$target)
        $parameters=New-HistoryFixture -Present
        $result=& (Join-Path $target 'Review-PolicyHistory.ps1') @parameters | ConvertFrom-Json -Depth 40
        $result.Findings[0].State | Should -Be 'CurrentlyTargeted'
        Test-Path (Join-Path $target 'ConvertFrom-IntuneAccessSnapshotJson.ps1') | Should -BeTrue
        Test-Path (Join-Path $target 'Get-IntuneAccessByteHash.ps1') | Should -BeTrue
    }
    It 'generates exact named CSP observations without a cleanup action' {
        $generator=Join-Path (Split-Path $history) 'New-PolicyObservationConfiguration.ps1'
        foreach($name in @('QualityUpdateSource','FeatureUpdateSource')){
            $config=& $generator -Setting $name -WorkloadId 'policy' -SettingDefinitionId 'setting' | ConvertFrom-Json
            $config.Rules[0].Name | Should -Match '^SetPolicyDrivenUpdateSourceFor(Quality|Feature)Updates$'
            $config.Rules[0].DocumentedDefault | Should -Be 1
            $config.Rules[0].RemovalContract | Should -Match 'never deletes'
            $config.Rules[0].WorkloadId | Should -Be 'policy'
        }
        {& $generator -Setting 'Unknown' -WorkloadId 'policy' -SettingDefinitionId 'setting'} | Should -Throw
    }
    It 'distinguishes a currently targeted setting from residue' {
        $parameters=New-HistoryFixture -Present
        $result=& $history @parameters | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'CurrentlyTargeted'
        $result.Findings[0].Explanation | Should -Match 'not proof'
    }
    It 'only labels a removed observed setting as possible residue' {
        $parameters=New-HistoryFixture
        $result=& $history @parameters | ConvertFrom-Json
        $result.Findings[0].State | Should -Be 'PossibleResidue'
        $result.DeviceConfigurationChanged | Should -BeFalse
        $result.IdentityVerified | Should -BeFalse
    }
    It 'does not interpret failed current collection as removal' {
        $parameters=New-HistoryFixture -Status 'Unavailable'
        (& $history @parameters | ConvertFrom-Json).Findings[0].State | Should -Be 'NotEvaluated'
    }
    It 'does not use stale evidence to infer residue' {
        $parameters=New-HistoryFixture -Stale
        (& $history @parameters | ConvertFrom-Json).Findings[0].State | Should -Be 'NotEvaluated'
    }
    It 'rejects tenant mismatch and altered snapshot content' {
        $parameters=New-HistoryFixture
        $parameters.TenantId='other'
        {& $history @parameters} | Should -Throw '*tenant*'
        $parameters.TenantId='tenant'
        $data=Get-Content $parameters.CurrentPath -Raw | ConvertFrom-Json -Depth 50
        $data.Data.CollectedAt=[DateTimeOffset]::UtcNow.ToString('o')
        $data|ConvertTo-Json -Depth 40|Set-Content $parameters.CurrentPath
        {& $history @parameters} | Should -Throw '*integrity*'
    }
}
