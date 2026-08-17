# Contributing

Contributions should keep IntuneAccess focused on explaining Intune administrative access.

## Before submitting a change

1. Use PowerShell 7 compatible syntax.
2. Use approved PowerShell verbs where practical.
3. Return objects instead of formatted text.
4. Keep Graph calls read only and use the least privileged documented permission.
5. Isolate beta endpoints and state why v1.0 is insufficient.
6. Preserve Graph IDs in evidence.
7. Return `NotEvaluated` instead of guessing.
8. Add or update Pester tests.
9. Use UK English in documentation.

Run the checks:

```powershell
.\tools\Test-Release.ps1
```

The release check validates the manifest and syntax, imports the module in the current process and a separate no-profile PowerShell process, runs the unit tests with a 70% coverage gate, runs Script Analyzer, then creates a ZIP archive and SHA-256 checksum outside the repository folder.

Build and test the separate allow-listed Gallery package with:

```powershell
$package = .\tools\New-IntuneAccessGalleryPackage.ps1 -Force
.\tools\Test-IntuneAccessGalleryPackage.ps1 -PackagePath $package.Package
```

The Gallery package deliberately excludes tests, screenshots, development tools and workflow files.

## Sample tenant data

Do not commit live tenant exports. Replace tenant IDs, user principal names, group names, device names and policy names. Check nested properties and error payloads as they can also identify a tenant.

## Claims about behaviour

Label behaviour as documented, observed or inferred. Link to current Microsoft Learn documentation. A lab result from one tenant must not be presented as a guarantee for every tenant.
