# PowerShell Gallery release procedure

This procedure prepares and publishes the exact IntuneAccess package that passed local validation. Publication is manual and is performed by the maintainer.

Set the version once and use it throughout:

```powershell
$version = (Import-PowerShellDataFile .\IntuneAccess.psd1).ModuleVersion
```

## Release boundary

1. Publish only from the protected public repository and the final release commit.
2. Publish the already-tested `.nupkg`; do not rebuild during submission.
3. Create a short-lived PowerShell Gallery API key, scoped to push new versions of `IntuneAccess` only, immediately before publication.
4. Never paste the key into chat, an AI assistant, source, an issue, a pull request, a workflow file or command history. Enter it only through the hidden prompt below.
5. Delete the key straight after publication. If a key is ever exposed, revoke it immediately and create a new one.

## Build and test

```powershell
.\tools\Test-Release.ps1

$package = .\tools\New-IntuneAccessGalleryPackage.ps1 -Force

.\tools\Test-IntuneAccessGalleryPackage.ps1 `
    -PackagePath $package.Package

.\tools\Test-IntuneAccessLocalRepository.ps1 `
    -PackagePath $package.Package
```

Confirm that the package result reports the expected `$version`, 22 exported commands, no validation error and a successful local repository installation. Update the command count here if the public surface changes.

## Publication order

1. Merge the tested changes into the protected `main` branch.
2. Confirm the GitHub validation workflow passes on Windows and Linux.
3. Build the source archive and Gallery package from the final commit.
4. Run both local release gates again.
5. Create the GitHub release as a draft.
6. Upload the source ZIP and SHA-256 file while the release remains a draft.
7. Publish the GitHub release only after its files and links are correct.
8. Confirm the manifest project, licence, icon and release-note links resolve publicly.
9. Record the final package name, version, size and SHA-256 hash.
10. Obtain explicit approval for the public upload.
11. Create the scoped API key and enter it through the hidden local prompt.
12. Run the publication command once.

Do not use `Publish-PSResource -WhatIf` as a publication safeguard. During the 1.0.0 release with Microsoft.PowerShell.PSResourceGet 1.2.0, the command uploaded the package despite `WhatIf`. Complete package validation without calling `Publish-PSResource`, then obtain approval before invoking the publication command.

## Controlled publication command

```powershell
$packagePath = ".\release\gallery\IntuneAccess.$version.nupkg"

Get-Item -LiteralPath $packagePath |
    Select-Object Name, Length

Get-FileHash `
    -LiteralPath $packagePath `
    -Algorithm SHA256

# Stop here and obtain final approval.
$galleryKeySecure = Read-Host `
    'PowerShell Gallery API key' `
    -AsSecureString

try {
    $galleryKey = [System.Net.NetworkCredential]::new(
        '',
        $galleryKeySecure
    ).Password

    Publish-PSResource `
        -NupkgPath $packagePath `
        -Repository PSGallery `
        -ApiKey $galleryKey
}
finally {
    $galleryKey = $null
    $galleryKeySecure.Dispose()
}
```

The hash and package review must be completed before the API key is entered. The `Publish-PSResource` call is the public submission and must run only after final approval.

## Post-publication validation

Use an isolated PowerShell 7 environment that does not already contain IntuneAccess:

```powershell
Find-PSResource IntuneAccess `
    -Version $version `
    -Repository PSGallery

Install-PSResource IntuneAccess `
    -Version $version `
    -Repository PSGallery `
    -Scope CurrentUser `
    -TrustRepository

Import-Module IntuneAccess -Force
Get-Command -Module IntuneAccess
```

Confirm:

1. The Gallery page names Mark Oldham as author and Control Alt Delete Tech Bits as company.
2. The project, licence, icon and release-note links work.
3. Microsoft.Graph.Authentication appears as a dependency.
4. All 22 public commands are exported, including `Start-IntuneAccess`.
5. A Core analysis works in the authorised development tenant.
6. The downloaded package hash is recorded and compared with the locally tested package.
7. The project log records the publication time, URL and validation evidence.
8. The API key has been deleted.
