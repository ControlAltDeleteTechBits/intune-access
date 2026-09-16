[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $PackagePath
)

$ErrorActionPreference = 'Stop'
$resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
if ([IO.Path]::GetExtension($resolvedPackage) -ne '.nupkg') {
    throw 'PackagePath must identify a .nupkg file.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedPackage)
try {
    $entryNames = @($archive.Entries.FullName)
}
finally {
    $archive.Dispose()
}

$forbiddenPrefixes = @('Tests/', 'screenshots/', 'tools/', '.github/', 'Assets/RemediationLibrary/user-app-migration/')
foreach ($required in @(
    'docs/v4-release-audit-current.md',
    'Assets/RemediationLibrary/application-detection/Convert-ApplicationRules.ps1',
    'Assets/RemediationLibrary/application-detection/New-DetectionProposal.ps1',
    'Assets/RemediationLibrary/policy-residue/Review-PolicyHistory.ps1',
    'Assets/RemediationLibrary/update-source-migration/Review-UpdatePolicies.ps1',
    'Private/ConvertFrom-IntuneAccessSnapshotJson.ps1',
    'Private/Get-IntuneAccessByteHash.ps1',
    'Assets/RemediationLibrary/investigation-common/Collect-Evidence.ps1',
    'Assets/RemediationLibrary/investigation-common/Review-Evidence.ps1',
    'Assets/RemediationLibrary/investigation-common/Compare-Evidence.ps1'
    'Assets/RemediationLibrary/investigation-common/Get-AdditionalDeviceEvidence.ps1'
)) {
    if ($required -notin $entryNames) { throw "The investigation runtime asset is missing: $required" }
}
foreach ($required in @('Assets/action-centre.html', 'Assets/RemediationLibrary/ime-service/Detect.ps1', 'Assets/RemediationLibrary/ime-service/Remediate.ps1', 'Assets/RemediationLibrary/ime-service/README.md', 'Assets/RemediationLibrary/system-disk-space/Detect.ps1', 'Assets/RemediationLibrary/system-disk-space/README.md', 'docs/v4-local-testing.md', 'Private/Compare-IntuneAccessFindingEvidence.ps1')) {
    if ($required -notin $entryNames) { throw "The V4 package is missing a required runtime asset: $required" }
}
foreach ($prefix in $forbiddenPrefixes) {
    if (@($entryNames | Where-Object { $_.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
        throw "The Gallery package contains development content under '$prefix'."
    }
}

$stageRoot = Join-Path ([IO.Path]::GetTempPath()) "IntuneAccess-PackageTest-$([guid]::NewGuid().Guid)"
try {
    $null = New-Item -ItemType Directory -Path $stageRoot -Force
    [IO.Compression.ZipFile]::ExtractToDirectory($resolvedPackage, $stageRoot)
    $manifestPath = Join-Path $stageRoot 'IntuneAccess.psd1'
    $manifest = Test-ModuleManifest -Path $manifestPath
    $expectedCommands = @($manifest.ExportedFunctions.Keys | Sort-Object)

    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $command = @'
$ErrorActionPreference = 'Stop'
Import-Module '__MANIFEST__' -Force
$commands = @(Get-Command -Module IntuneAccess | Sort-Object Name)
$library = @(& (Get-Module IntuneAccess) { Get-IntuneAccessRemediationLibrary })
if ($library.Count -ne 6 -or 'user-app-migration' -in $library.Id -or @($library | Where-Object ExecutionAllowed -NE $false).Count -gt 0) {
    throw 'The isolated package does not supply the six expected export-only library entries.'
}
foreach ($item in $library) {
    if ([Convert]::FromBase64String($item.PackageBase64).Length -eq 0) { throw 'An exported library archive is empty.' }
}
[PSCustomObject] @{
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    CommandCount = $commands.Count
    Commands = @($commands.Name)
} | ConvertTo-Json -Compress
'@.Replace('__MANIFEST__', ($manifestPath -replace "'", "''"))
    $processOutput = & $pwsh -NoLogo -NoProfile -NonInteractive -Command $command
    if ($LASTEXITCODE -ne 0) {
        throw "The isolated package import failed with exit code $LASTEXITCODE."
    }
    $importResult = $processOutput | ConvertFrom-Json
    if ($importResult.CommandCount -ne $expectedCommands.Count) {
        throw "Expected $($expectedCommands.Count) exported commands, found $($importResult.CommandCount)."
    }
    if (@(Compare-Object $expectedCommands @($importResult.Commands)).Count -gt 0) {
        throw 'The isolated package exports do not match the module manifest.'
    }

    $hash = Get-FileHash -LiteralPath $resolvedPackage -Algorithm SHA256
    $prerelease = [string] $manifest.PrivateData.PSData.Prerelease
    $packageVersion = if ([string]::IsNullOrWhiteSpace($prerelease)) {
        [string] $manifest.Version
    }
    else {
        "$($manifest.Version)-$prerelease"
    }

    [PSCustomObject] @{
        Package           = $resolvedPackage
        Version           = $packageVersion
        Entries           = $entryNames.Count
        ExportedCommands  = $expectedCommands.Count
        PowerShellVersion = $importResult.PowerShellVersion
        Sha256            = $hash.Hash.ToLowerInvariant()
    }
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = (Resolve-Path -LiteralPath $stageRoot).Path
        $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
        if ($resolvedStage.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedStage) -like 'IntuneAccess-PackageTest-*') {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
}
