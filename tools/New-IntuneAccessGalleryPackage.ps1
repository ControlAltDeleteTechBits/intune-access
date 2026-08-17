[CmdletBinding()]
param(
    [string] $OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'release\gallery'),
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $moduleRoot 'IntuneAccess.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath
$prerelease = [string] $manifest.PrivateData.PSData.Prerelease
$packageVersion = if ([string]::IsNullOrWhiteSpace($prerelease)) {
    [string] $manifest.Version
}
else {
    "$($manifest.Version)-$prerelease"
}

$compressCommand = Get-Command Compress-PSResource -ErrorAction SilentlyContinue
if ($null -eq $compressCommand) {
    throw 'Compress-PSResource is required. Install Microsoft.PowerShell.PSResourceGet and retry.'
}

$stageRoot = Join-Path ([IO.Path]::GetTempPath()) "IntuneAccess-Gallery-$([guid]::NewGuid().Guid)"
$stageModule = Join-Path $stageRoot 'IntuneAccess'
$packagePath = Join-Path $OutputDirectory "IntuneAccess.$packageVersion.nupkg"

try {
    $null = New-Item -ItemType Directory -Path $stageModule -Force
    $null = New-Item -ItemType Directory -Path $OutputDirectory -Force

    $rootFiles = @(
        'IntuneAccess.psd1',
        'IntuneAccess.psm1',
        'IntuneAccess.Format.ps1xml',
        'LICENSE',
        'README.md',
        'RELEASE_NOTES.md',
        'SECURITY.md',
        'THIRD-PARTY-NOTICES.md'
    )
    foreach ($file in $rootFiles) {
        Copy-Item -LiteralPath (Join-Path $moduleRoot $file) -Destination $stageModule
    }

    foreach ($directory in @('Public', 'Private', 'Assets', 'examples')) {
        Copy-Item -LiteralPath (Join-Path $moduleRoot $directory) -Destination $stageModule -Recurse
    }

    $stageDocs = Join-Path $stageModule 'docs'
    $null = New-Item -ItemType Directory -Path $stageDocs -Force
    foreach ($document in @('architecture.md', 'effective-access-model.md', 'limitations.md', 'permissions.md', 'troubleshooting.md')) {
        Copy-Item -LiteralPath (Join-Path $moduleRoot "docs\$document") -Destination $stageDocs
    }

    $stageManifest = Test-ModuleManifest -Path (Join-Path $stageModule 'IntuneAccess.psd1')
    if (@($stageManifest.ExportedFunctions.Keys).Count -ne 9) {
        throw 'The staged module does not export the expected nine commands.'
    }
    if (@($stageManifest.RequiredModules | Where-Object Name -EQ 'Microsoft.Graph.Authentication').Count -ne 1) {
        throw 'The staged module does not declare Microsoft.Graph.Authentication as a dependency.'
    }

    if (Test-Path -LiteralPath $packagePath) {
        if (-not $Force) {
            throw "The Gallery package already exists: $packagePath. Use -Force to replace it."
        }
        Remove-Item -LiteralPath $packagePath -Force
    }

    $package = Compress-PSResource -Path $stageModule -DestinationPath $OutputDirectory -PassThru
    $hash = Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256
    $checksumPath = "$($package.FullName).sha256"
    "$($hash.Hash.ToLowerInvariant())  $($package.Name)" | Set-Content -LiteralPath $checksumPath -Encoding utf8NoBOM

    [PSCustomObject] @{
        Package      = $package.FullName
        Checksum     = $checksumPath
        Version      = $packageVersion
        SizeBytes    = $package.Length
        Sha256       = $hash.Hash.ToLowerInvariant()
        SourceFiles  = @(Get-ChildItem -LiteralPath $stageModule -Recurse -File).Count
    }
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $resolvedStage = (Resolve-Path -LiteralPath $stageRoot).Path
        $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
        if ($resolvedStage.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedStage) -like 'IntuneAccess-Gallery-*') {
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
}
