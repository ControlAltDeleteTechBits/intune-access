[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $PackagePath,
    [string] $Version = '3.0.0'
)

$ErrorActionPreference = 'Stop'
$resolvedPackage = (Resolve-Path -LiteralPath $PackagePath).Path
if ([IO.Path]::GetExtension($resolvedPackage) -ne '.nupkg') {
    throw 'PackagePath must identify a .nupkg file.'
}

Import-Module Microsoft.PowerShell.PSResourceGet -MinimumVersion 1.1.0 -ErrorAction Stop
$repositoryName = "IntuneAccessLocal-$([guid]::NewGuid().ToString('N'))"
$testRoot = Join-Path ([IO.Path]::GetTempPath()) $repositoryName
$repositoryRoot = Join-Path $testRoot 'repository'
$installedByTest = $false

try {
    $null = New-Item -ItemType Directory -Path $repositoryRoot -Force
    $null = Register-PSResourceRepository `
        -Name $repositoryName `
        -Uri $repositoryRoot `
        -ApiVersion Local `
        -Trusted `
        -PassThru

    Publish-PSResource `
        -NupkgPath $resolvedPackage `
        -Repository $repositoryName `
        -SkipDependenciesCheck

    $resource = Find-PSResource `
        -Name IntuneAccess `
        -Version $Version `
        -Repository $repositoryName
    if ($resource.Version -ne [version] $Version) {
        throw "The local repository returned unexpected version '$($resource.Version)'."
    }

    $existing = @(Get-InstalledPSResource -Name IntuneAccess -Version $Version -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) {
        throw "IntuneAccess $Version is already installed for this user, so an isolated installation cannot be proved safely."
    }
    $graphAuthentication = Get-Module Microsoft.Graph.Authentication -ListAvailable |
        Where-Object Version -GE ([version] '2.0.0') |
        Select-Object -First 1
    if ($null -eq $graphAuthentication) {
        throw 'Microsoft.Graph.Authentication 2.0.0 or later must be installed before testing the local-only repository.'
    }

    $installed = Install-PSResource `
        -Name IntuneAccess `
        -Version $Version `
        -Repository $repositoryName `
        -Scope CurrentUser `
        -TrustRepository `
        -SkipDependencyCheck `
        -PassThru
    $installedByTest = $true

    Remove-Module IntuneAccess -Force -ErrorAction SilentlyContinue
    Import-Module IntuneAccess -RequiredVersion $Version -Force -ErrorAction Stop
    $commands = @(Get-Command -Module IntuneAccess | Sort-Object Name)
    $manifest = Test-ModuleManifest -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'IntuneAccess.psd1')
    $expectedCommandCount = @($manifest.ExportedFunctions.Keys).Count
    if ($commands.Count -ne $expectedCommandCount) {
        throw "Expected $expectedCommandCount exported commands after local repository installation, found $($commands.Count)."
    }

    [PSCustomObject] @{
        Package            = $resolvedPackage
        RepositoryType     = 'Local'
        RepositoryVersion  = [string] $resource.Version
        InstalledVersion   = [string] $installed.Version
        ExportedCommands   = $commands.Count
        InstallationPassed = $true
    }
}
finally {
    Remove-Module IntuneAccess -Force -ErrorAction SilentlyContinue
    if ($installedByTest) {
        Uninstall-PSResource -Name IntuneAccess -Version $Version -ErrorAction SilentlyContinue
    }
    Unregister-PSResourceRepository -Name $repositoryName -ErrorAction SilentlyContinue
    $resource = $null
    $installed = $null
    Remove-Module Microsoft.PowerShell.PSResourceGet -Force -ErrorAction SilentlyContinue
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $resolvedTemp = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
        if ($resolvedTestRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedTestRoot) -eq $repositoryName) {
            Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
        }
    }
}
