[CmdletBinding()]
param(
    [string] $Version = '4.0.0',
    [string] $OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'release')
)

$ErrorActionPreference = 'Stop'
$moduleRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $moduleRoot 'IntuneAccess.psd1'
$settingsPath = Join-Path $moduleRoot 'PSScriptAnalyzerSettings.psd1'
$unitTestPath = Join-Path $moduleRoot 'Tests\Unit'

Write-Verbose 'Validating the module manifest.'
$manifest = Test-ModuleManifest -Path $manifestPath
if ([string] $manifest.Version -ne $Version) { throw 'Requested release version does not match the manifest.' }

Write-Verbose 'Checking PowerShell syntax.'
$parseErrors = [System.Collections.Generic.List[object]]::new()
Get-ChildItem -LiteralPath $moduleRoot -Recurse -File |
    Where-Object Extension -in @('.ps1', '.psm1', '.psd1') |
    ForEach-Object {
        $tokens = $null
        $errors = $null
        [void] [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref] $tokens, [ref] $errors)
        foreach ($parseError in @($errors)) { $parseErrors.Add($parseError) }
    }
if ($parseErrors.Count -gt 0) {
    $parseErrors | Format-List | Out-String | Write-Error
}

Write-Verbose 'Importing the module.'
Remove-Module IntuneAccess -Force -ErrorAction SilentlyContinue
Import-Module $manifestPath -Force
$exportedCommands = @(Get-Command -Module IntuneAccess)
$expectedCommandCount = @($manifest.ExportedFunctions.Keys).Count
if ($exportedCommands.Count -ne $expectedCommandCount) {
    throw "Expected $expectedCommandCount exported commands, found $($exportedCommands.Count)."
}

Write-Verbose 'Importing the module in a separate no-profile PowerShell process.'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$cleanImportCommand = "Import-Module '$($manifestPath -replace "'", "''")' -Force -ErrorAction Stop; @(Get-Command -Module IntuneAccess).Count"
$cleanImportCount = & $pwsh -NoLogo -NoProfile -NonInteractive -Command $cleanImportCommand
if ($LASTEXITCODE -ne 0 -or [int] $cleanImportCount -ne $expectedCommandCount) {
    throw 'The separate no-profile PowerShell import did not return the expected commands.'
}

Write-Verbose 'Running the unit test suite.'
$pesterConfiguration = New-PesterConfiguration
$pesterConfiguration.Run.Path = $unitTestPath
$pesterConfiguration.Run.PassThru = $true
$pesterConfiguration.Output.Verbosity = 'Normal'
$pesterConfiguration.CodeCoverage.Enabled = $true
$pesterConfiguration.CodeCoverage.Path = @(
    (Join-Path $moduleRoot 'Public\*.ps1'),
    (Join-Path $moduleRoot 'Private\*.ps1'),
    (Join-Path $moduleRoot 'IntuneAccess.psm1')
)
$pesterResult = Invoke-Pester -Configuration $pesterConfiguration
if ($pesterResult.FailedCount -gt 0) {
    throw "$($pesterResult.FailedCount) Pester test or tests failed."
}
if ($pesterResult.CodeCoverage.CoveragePercent -lt 70) {
    throw "Code coverage is $([math]::Round($pesterResult.CodeCoverage.CoveragePercent, 2))%. The release gate requires at least 70%."
}

Write-Verbose 'Running PowerShell Script Analyzer.'
$analysis = @(Invoke-ScriptAnalyzer -Path $moduleRoot -Recurse -Settings $settingsPath)
if ($analysis.Count -gt 0) {
    $analysis | Format-Table -AutoSize | Out-String | Write-Error
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$archivePath = Join-Path $OutputDirectory "IntuneAccess-$Version.zip"
$archiveInputs = @('Public', 'Private', 'Assets', 'Tests', 'docs', 'examples', 'tools', 'IntuneAccess.psd1', 'IntuneAccess.psm1', 'IntuneAccess.Format.ps1xml', 'LICENSE', 'README.md', 'RELEASE_NOTES.md', 'CHANGELOG.md', 'SECURITY.md', 'THIRD-PARTY-NOTICES.md', 'PSScriptAnalyzerSettings.psd1') | ForEach-Object { Join-Path $moduleRoot $_ }
# Do not archive the whole working tree: local reports and git metadata are not release assets.
Compress-Archive -LiteralPath $archiveInputs -DestinationPath $archivePath -Force

$hash = Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
$checksumPath = "$archivePath.sha256"
"$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($archivePath))" |
    Set-Content -LiteralPath $checksumPath -Encoding utf8NoBOM

[PSCustomObject] @{
    Version          = $Version
    ManifestVersion  = [string] $manifest.Version
    ExportedCommands = $exportedCommands.Count
    CleanImport      = $true
    UnitTestsPassed  = $pesterResult.PassedCount
    CodeCoverage     = [math]::Round($pesterResult.CodeCoverage.CoveragePercent, 2)
    AnalyzerFindings = $analysis.Count
    Archive          = $archivePath
    Checksum         = $checksumPath
    Sha256           = $hash.Hash.ToLowerInvariant()
}
