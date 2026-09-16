function Get-IntuneAccessRemediationLibrary {
    [CmdletBinding()]
    param()
    foreach ($definition in @(
        @{ Id = 'ime-service'; Name = 'Stopped Intune Management Extension service'; MakesChanges = $true },
        @{ Id = 'system-disk-space'; Name = 'System disk space review'; MakesChanges = $false },
        @{ Id = 'application-detection'; Name = 'Application detection mismatch'; MakesChanges = $false; Investigation = $true },
        @{ Id = 'update-source-migration'; Name = 'Update source migration review'; MakesChanges = $false; Investigation = $true },
        @{ Id = 'policy-residue'; Name = 'Policy residue investigation'; MakesChanges = $false; Investigation = $true },
        @{ Id = 'device-evidence-comparison'; Name = 'Working and affected device comparison'; MakesChanges = $false; Investigation = $true }
    )) {
        $root = Join-Path $script:IntuneAccessModuleRoot "Assets/RemediationLibrary/$($definition.Id)"
        $files = @('Detect.ps1', 'README.md')
        if ($definition.Id -eq 'application-detection') { $files += @('Convert-ApplicationRules.ps1', 'New-DetectionProposal.ps1') }
        if ($definition.Id -eq 'update-source-migration') { $files += 'Review-UpdatePolicies.ps1' }
        if ($definition.Id -in @('update-source-migration','policy-residue')) { $files += @('ConvertFrom-IntuneAccessSnapshotJson.ps1','Get-IntuneAccessByteHash.ps1') }
        if ($definition.Id -eq 'policy-residue') { $files += @('Review-PolicyHistory.ps1', 'New-PolicyObservationConfiguration.ps1') }
        if ($definition.MakesChanges) { $files += 'Remediate.ps1' }
        if ($definition.ContainsKey('Investigation')) { $files += @('configuration.example.json', 'Collect-Evidence.ps1', 'Review-Evidence.ps1', 'Compare-Evidence.ps1', 'Get-AdditionalDeviceEvidence.ps1') }
        $stream = [IO.MemoryStream]::new()
        try {
            $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
            try {
                $hashLines = [Collections.Generic.List[string]]::new()
                foreach ($name in $files) {
                    $sourceRoot = if ($name -in @('Collect-Evidence.ps1', 'Review-Evidence.ps1', 'Compare-Evidence.ps1', 'Get-AdditionalDeviceEvidence.ps1')) { Join-Path $script:IntuneAccessModuleRoot 'Assets/RemediationLibrary/investigation-common' } else { $root }
                    if ($name -in @('ConvertFrom-IntuneAccessSnapshotJson.ps1','Get-IntuneAccessByteHash.ps1')) { $sourceRoot = Join-Path $script:IntuneAccessModuleRoot 'Private' }
                    $bytes = [IO.File]::ReadAllBytes((Join-Path $sourceRoot $name))
                    $hash = Get-IntuneAccessByteHash -Bytes $bytes
                    $hashLines.Add("$hash  $name")
                    $entry = $zip.CreateEntry($name)
                    $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-09-15T00:00:00Z')
                    $destination = $entry.Open()
                    try { $destination.Write($bytes, 0, $bytes.Length) } finally { $destination.Dispose() }
                }
                $hashEntry = $zip.CreateEntry('SHA256SUMS.txt')
                $hashEntry.LastWriteTime = [DateTimeOffset]::Parse('2026-09-15T00:00:00Z')
                $writer = [IO.StreamWriter]::new($hashEntry.Open(), [Text.UTF8Encoding]::new($false))
                try { $writer.Write(($hashLines -join "`n") + "`n") } finally { $writer.Dispose() }
            }
            finally { $zip.Dispose() }
            $archive = $stream.ToArray()
            [pscustomobject] @{
                Id = $definition.Id; Name = $definition.Name; Version = '1.0.0'; MakesChanges = $definition.MakesChanges
                ReviewNotes = [string](Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw)
                Files = $files; PackageBase64 = [Convert]::ToBase64String($archive)
                PackageSha256 = Get-IntuneAccessByteHash -Bytes $archive
                ReviewState = 'SourceAndMockTests'; ExecutionAllowed = $false
            }
        }
        finally { $stream.Dispose() }
    }
}
