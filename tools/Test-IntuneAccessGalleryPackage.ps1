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

$forbiddenPrefixes = @('Tests/', 'screenshots/', 'tools/', '.github/')
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
