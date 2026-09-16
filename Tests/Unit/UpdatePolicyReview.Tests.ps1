BeforeAll {
    $script:reviewer=Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/update-source-migration/Review-UpdatePolicies.ps1'
    function New-UpdateFixture {
        param($Assignment='Included',$Collection='Available',[switch]$Stale,[switch]$NoMapping,[switch]$DuplicateAssignment)
        $now=[DateTimeOffset]::UtcNow
        $time=if($Stale){$now.AddDays(-2)}else{$now.AddMinutes(-2)}
        $assignmentRow=@{WorkloadId='policy-1';DeviceId='device-1';AssignmentState=$Assignment}
        $assignments=@($assignmentRow)
        if($DuplicateAssignment){$assignments+=@($assignmentRow)}
        $data=[pscustomobject]@{
            CollectedAt=$time.ToString('o')
            PolicySettings=@(@{WorkloadId='policy-1';WorkloadName='Quality source';SettingDefinitionId='exact-quality-id';ValueJson='"1"';SourceEndpoint='deviceManagement/configurationPolicies';SourceApiVersion='beta'})
            PolicyConflictCollectionStatus=@(@{WorkloadId='policy-1';State=$Collection})
            DeviceAssignmentExplanations=$assignments
        }
        $stream=[IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes(($data|ConvertTo-Json -Depth 40 -Compress)),$false)
        try {$hash=(Get-FileHash -InputStream $stream -Algorithm SHA256).Hash.ToLowerInvariant()}finally{$stream.Dispose()}
        $snapshot=Join-Path $TestDrive 'snapshot.json'
        @{SchemaVersion='2.0';Schema='https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-2.0.json';IdentityMode='Full';Tenant=@{Id='tenant'};Data=$data;IntegritySha256=$hash}|ConvertTo-Json -Depth 40|Set-Content $snapshot
        $mappings=if($NoMapping){@()}else{@(@{Category='Quality';SettingDefinitionId='exact-quality-id'})}
        $endpoint=Join-Path $TestDrive 'endpoint.json'
        @{SchemaVersion='1.0';Kind='IntuneAccess.EndpointEvidence';Investigation='UpdateSources';ComputerName='fixture';CollectedAt=$now.ToString('o');Configuration=@{ExpectedSources=@{Quality='WindowsUpdate'};PolicyMappings=@($mappings)};Facts=@(@{Key='update/SetPolicyDrivenUpdateSourceForQualityUpdates';State='Observed';Value=1})}|ConvertTo-Json -Depth 20|Set-Content $endpoint
        @{EvidencePath=$endpoint;SnapshotPath=$snapshot;TenantId='tenant';DeviceId='device-1'}
    }
}
Describe 'Update policy correlation' {
    It 'runs from its exported archive without relying on the source tree' {
        Import-Module (Join-Path $PSScriptRoot '../../IntuneAccess.psd1') -Force
        $package=& (Get-Module IntuneAccess) {Get-IntuneAccessRemediationLibrary | Where-Object Id -EQ 'update-source-migration'}
        $archivePath=Join-Path $TestDrive 'update.zip'
        [IO.File]::WriteAllBytes($archivePath,[Convert]::FromBase64String($package.PackageBase64))
        $target=Join-Path $TestDrive 'exported-update'
        [IO.Compression.ZipFile]::ExtractToDirectory($archivePath,$target)
        Test-Path (Join-Path $target 'ConvertFrom-IntuneAccessSnapshotJson.ps1') | Should -BeTrue
        $parameters=New-UpdateFixture
        $result=& (Join-Path $target 'Review-UpdatePolicies.ps1') @parameters | ConvertFrom-Json -Depth 40
        $result.Findings[0].Proposal.TenantPolicyCandidates[0].PolicyId | Should -Be 'policy-1'
    }
    It 'identifies an exact targeted policy without asserting ownership or applying changes' {
        $parameters=New-UpdateFixture
        $result=& $reviewer @parameters|ConvertFrom-Json -Depth 40
        $finding=$result.Findings|Where-Object Id -EQ 'Quality'
        $finding.State|Should -Be 'MigrationMismatch'
        $finding.Proposal.TenantPolicyCandidates[0].PolicyId|Should -Be 'policy-1'
        $finding.Proposal.TenantPolicyCandidates[0].State|Should -Be 'TargetedPolicyCandidate'
        $finding.Proposal.OwnershipState|Should -Be 'NotEstablished'
        $finding.Proposal.ProposedValue|Should -Be 0
        $finding.Proposal.CleanupAllowed|Should -BeFalse
        $result.IdentityVerified|Should -BeFalse
        $result.DeviceConfigurationChanged|Should -BeFalse
    }
    It 'keeps excluded policies distinct from correction candidates' {
        $parameters=New-UpdateFixture -Assignment Excluded
        $result=& $reviewer @parameters|ConvertFrom-Json -Depth 40
        $result.Findings[0].Proposal.TenantPolicyCandidates[0].State|Should -Be 'ExcludedInSnapshot'
    }
    It 'does not infer targeting from weak evidence' -TestCases @(
        @{Options=@{Stale=$true}},@{Options=@{DuplicateAssignment=$true}},
        @{Options=@{Collection='Unavailable'}},@{Options=@{Assignment='NotEvaluated'}}
    ) {
        param($Options)
        $parameters=New-UpdateFixture @Options
        $result=& $reviewer @parameters|ConvertFrom-Json -Depth 40
        $result.Findings[0].Proposal.TenantPolicyCandidates[0].State|Should -Be 'NotEvaluated'
    }
    It 'does not infer mappings from display names' {
        $parameters=New-UpdateFixture -NoMapping
        $result=& $reviewer @parameters|ConvertFrom-Json -Depth 40
        @($result.Findings[0].Proposal.TenantPolicyCandidates).Count|Should -Be 0
        $result.Findings[0].Proposal.TenantCorrelation|Should -Match 'no exact mapping'
    }
    It 'rejects a different tenant and altered snapshot' {
        $parameters=New-UpdateFixture
        $parameters.TenantId='wrong'
        {& $reviewer @parameters}|Should -Throw '*tenant*'
        $parameters.TenantId='tenant'
        $json=Get-Content $parameters.SnapshotPath -Raw
        $json.Replace('Quality source','Changed source')|Set-Content $parameters.SnapshotPath
        {& $reviewer @parameters}|Should -Throw '*integrity*'
    }
}
