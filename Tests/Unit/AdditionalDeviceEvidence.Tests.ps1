BeforeAll {
    # Pester needs a command definition to mock on non-Windows runners.
    if (-not (Get-Command Get-WinEvent -ErrorAction SilentlyContinue)) {
        function Get-WinEvent {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Test-only mock target, defined only where the Windows cmdlet is absent.')]
            [CmdletBinding()]
            param([hashtable]$FilterHashtable, [int]$MaxEvents)
            throw "Unmocked Windows event query: $($FilterHashtable.Count), $MaxEvents"
        }
    }
    . (Join-Path $PSScriptRoot '../../Assets/RemediationLibrary/investigation-common/Get-AdditionalDeviceEvidence.ps1')
}
Describe 'Bounded optional endpoint metadata' {
    It 'does not collect anything without explicit selection' {
        Mock Get-ChildItem {throw 'Unexpected read'}
        Mock Get-WinEvent {throw 'Unexpected read'}
        @(Get-AdditionalDeviceEvidence).Count | Should -Be 0
        Should -Invoke Get-ChildItem -Times 0
        Should -Invoke Get-WinEvent -Times 0
    }
    It 'exports certificate metadata without subject or private key material' {
        Mock Get-ChildItem {[pscustomobject]@{Thumbprint='fixture';Issuer='issuer';Subject='PRIVATE_SUBJECT';PrivateKey='SECRET_KEY';NotBefore=(Get-Date).AddDays(-1);NotAfter=(Get-Date).AddDays(1);HasPrivateKey=$true;EnhancedKeyUsageList=@(@{ObjectId='1.3.6.1.5.5.7.3.2'})}}
        $result=@(Get-AdditionalDeviceEvidence -Certificates)
        $result.Count | Should -Be 2
        $result[0].State | Should -Be 'Observed'
        $result[0].Value[0].HasPrivateKey | Should -BeTrue
        ($result|ConvertTo-Json -Depth 15) | Should -Not -Match 'SECRET_KEY|PRIVATE_SUBJECT'
    }
    It 'retains a bounded event window and excludes event bodies' {
        Mock Get-WinEvent {1..101|ForEach-Object {[pscustomobject]@{Id=404;RecordId=$_;TimeCreated=Get-Date;Level=2;ProviderName='fixture';Message='PRIVATE_EVENT'}}}
        $result=@(Get-AdditionalDeviceEvidence -Events)
        $result[0].Value.LimitReached | Should -BeTrue
        @($result[0].Value.Events).Count | Should -Be 100
        ($result|ConvertTo-Json -Depth 15) | Should -Not -Match 'PRIVATE_EVENT'
        Should -Invoke Get-WinEvent -Times 2 -ParameterFilter {$MaxEvents -eq 101 -and $FilterHashtable.Level.Count -eq 2}
    }
    It 'does not turn access failures into empty healthy results' {
        Mock Get-WinEvent {throw 'Access denied'}
        $result=@(Get-AdditionalDeviceEvidence -Events)
        $result[0].State | Should -Be 'Unavailable'
        $result[0].Value | Should -BeNullOrEmpty
    }
}
