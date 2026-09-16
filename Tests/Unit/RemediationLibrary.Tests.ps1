[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Test-only command stubs ensure device operations cannot reach real services and support non-Windows runners.')]
param()
Import-Module (Join-Path $PSScriptRoot '../../IntuneAccess.psd1') -Force
Describe 'Export-only remediation library' {
    InModuleScope IntuneAccess {
        It 'serialises review notes as plain text without filesystem provider metadata' {
            foreach($item in @(Get-IntuneAccessRemediationLibrary)){
                $json=@{Notes=$item.ReviewNotes}|ConvertTo-Json -Depth 3 -Compress
                $json | Should -Not -Match 'PSProvider|PSParentPath|PSChildName'
                $json.Length | Should -BeLessThan ($item.ReviewNotes.Length * 2)
            }
        }
        It 'creates six deterministic packages without executing scripts' {
            $first = @(Get-IntuneAccessRemediationLibrary)
            $second = @(Get-IntuneAccessRemediationLibrary)
            $first.Count | Should -Be 6
            $first.Id | Should -Not -Contain 'user-app-migration'
            $first[0].PackageSha256 | Should -Be $second[0].PackageSha256
            $first[0].ExecutionAllowed | Should -BeFalse
            foreach ($item in $first) {
                $bytes = [Convert]::FromBase64String($item.PackageBase64)
                $stream = [IO.MemoryStream]::new($bytes, $false)
                $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read)
                try {
                    @($zip.Entries.FullName) | Should -Contain 'Detect.ps1'
                    @($zip.Entries.FullName) | Should -Contain 'README.md'
                    @($zip.Entries.FullName) | Should -Contain 'SHA256SUMS.txt'
                    if ($item.MakesChanges) { @($zip.Entries.FullName) | Should -Contain 'Remediate.ps1' }
                    else { @($zip.Entries.FullName) | Should -Not -Contain 'Remediate.ps1' }
                    $reader = [IO.StreamReader]::new($zip.GetEntry('SHA256SUMS.txt').Open())
                    try { $hashes = $reader.ReadToEnd() } finally { $reader.Dispose() }
                    foreach ($name in $item.Files) {
                        $source = $zip.GetEntry($name).Open(); $memory = [IO.MemoryStream]::new()
                        try { $source.CopyTo($memory); $memory.Position=0; $hash = (Get-FileHash -InputStream $memory -Algorithm SHA256).Hash.ToLowerInvariant() }
                        finally { $source.Dispose(); $memory.Dispose() }
                        $hashes | Should -Match ([regex]::Escape("$hash  $name"))
                    }
                } finally { $zip.Dispose(); $stream.Dispose() }
            }
        }
    }
}
Describe 'External script control flow with mocked device operations' {
    BeforeAll {
        $script:libraryRoot = Join-Path $PSScriptRoot '../../Assets/RemediationLibrary'
        # Stubs make these control-flow tests runnable on non-Windows hosts too.
        function Get-Service { param($Name, $ErrorAction) throw "Unmocked test service read: $Name ($ErrorAction)" }
        function Start-Service { param($Name, $ErrorAction) throw "Unmocked test service write: $Name ($ErrorAction)" }
        function Get-CimInstance { param($ClassName, $Filter, $ErrorAction) throw "Unmocked test CIM read: $ClassName $Filter ($ErrorAction)" }
    }
    BeforeEach {
        Mock Get-Service { [pscustomobject] @{ Status = 'Running'; StartType = 'Automatic' } }
        Mock Start-Service { throw 'Unexpected service mutation' }
    }
    It 'detects running and stopped services without writes' {
        & "$libraryRoot/ime-service/Detect.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 0
        Mock Get-Service { [pscustomobject] @{ Status = 'Stopped'; StartType = 'Automatic' } }
        & "$libraryRoot/ime-service/Detect.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 1
        Should -Invoke Start-Service -Times 0
    }
    It 'refuses disabled services and unknown detection' {
        Mock Get-Service { [pscustomobject] @{ Status = 'Stopped'; StartType = 'Disabled' } }
        & "$libraryRoot/ime-service/Detect.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 2
        & "$libraryRoot/ime-service/Remediate.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 2
        Should -Invoke Start-Service -Times 0
    }
    It 'does not change an already running service or a WhatIf target' {
        & "$libraryRoot/ime-service/Remediate.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 0
        Mock Get-Service { [pscustomobject] @{ Status = 'Stopped'; StartType = 'Automatic' } }
        & "$libraryRoot/ime-service/Remediate.ps1" -WhatIf | Out-Null
        $LASTEXITCODE | Should -Be 2
        Should -Invoke Start-Service -Times 0
    }
    It 'starts only the named stopped service and verifies state' {
        Mock Get-Service {
            $service = [pscustomobject] @{ Status = 'Stopped'; StartType = 'Automatic' }
            $service | Add-Member -MemberType ScriptMethod -Name WaitForStatus -Value { param($State, $Timeout) if ([string] $State -ne 'Running' -or $Timeout.TotalSeconds -ne 30) { throw 'Unexpected verification target' } }
            $service
        }
        Mock Start-Service {}
        & "$libraryRoot/ime-service/Remediate.ps1" -Confirm:$false | Out-Null
        $LASTEXITCODE | Should -Be 0
        Should -Invoke Start-Service -Times 1 -ParameterFilter { $Name -eq 'IntuneManagementExtension' }
    }
    It 'does not claim recovery when a start fails' {
        Mock Get-Service { [pscustomobject] @{ Status = 'Stopped'; StartType = 'Automatic' } }
        & "$libraryRoot/ime-service/Remediate.ps1" -Confirm:$false | Out-Null
        $LASTEXITCODE | Should -Be 2
    }
    It 'uses the disk threshold and distinguishes unknown capacity' {
        Mock Get-CimInstance { [pscustomobject] @{ FreeSpace = 20GB; Size = 100GB } }
        & "$libraryRoot/system-disk-space/Detect.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 0
        Mock Get-CimInstance { [pscustomobject] @{ FreeSpace = 9GB; Size = 100GB } }
        & "$libraryRoot/system-disk-space/Detect.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 1
        Mock Get-CimInstance { throw 'Unavailable' }
        & "$libraryRoot/system-disk-space/Detect.ps1" | Out-Null
        $LASTEXITCODE | Should -Be 2
    }
}
