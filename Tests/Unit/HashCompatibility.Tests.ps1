BeforeAll {
    $script:hashScript=Join-Path $PSScriptRoot '../../Private/Get-IntuneAccessByteHash.ps1'
    . $script:hashScript
}
Describe 'Compatible SHA256 hashing' {
    It 'matches the standard empty and abc test vectors' {
        Get-IntuneAccessByteHash -Bytes ([byte[]]@()) | Should -Be 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        Get-IntuneAccessByteHash -Bytes ([Text.Encoding]::UTF8.GetBytes('abc')) | Should -Be 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    }
    It 'matches current runtime hashing for binary data' {
        $bytes=[byte[]](0..255)
        $stream=[IO.MemoryStream]::new($bytes,$false)
        try {$expected=(Get-FileHash -InputStream $stream -Algorithm SHA256).Hash.ToLowerInvariant()}finally{$stream.Dispose()}
        Get-IntuneAccessByteHash -Bytes $bytes | Should -Be $expected
    }
    It 'keeps newer static hash APIs out of runtime source' {
        $root=Join-Path $PSScriptRoot '../..'
        foreach($folder in @('Private','Public','Assets')){
            Get-ChildItem (Join-Path $root $folder) -Recurse -Filter '*.ps1' | ForEach-Object {
                Get-Content $_.FullName -Raw | Should -Not -Match '::(HashData|ToHexString)\('
            }
        }
    }
}
