function Export-IntuneAccessSnapshot {
    <#
    .SYNOPSIS
    Saves a local, allow-listed IntuneAccess tenant snapshot.
    .DESCRIPTION
    Writes normalised tenant evidence without authentication context, credentials or
    access tokens. Identity redaction uses stable pseudonyms for comparisons and is not
    a claim of irreversible anonymisation.
    .PARAMETER InputObject
    An IntuneAccess tenant RBAC collection.
    .PARAMETER Path
    Destination JSON file.
    .PARAMETER RedactIdentity
    Pseudonymises tenant, user, group, device and object identifiers and names.
    .PARAMETER Force
    Replaces an existing snapshot.
    .EXAMPLE
    $tenantRbac | Export-IntuneAccessSnapshot -Path '.\current.snapshot.json'
    .EXAMPLE
    $tenantRbac | Export-IntuneAccessSnapshot -Path '.\shareable.snapshot.json' -RedactIdentity
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object] $InputObject,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
        [switch] $RedactIdentity,
        [switch] $Force
    )

    process {
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if ([IO.Path]::GetExtension($resolvedPath) -ne '.json') { throw 'Snapshot output requires a .json file extension.' }
        if ((Test-Path -LiteralPath $resolvedPath) -and -not $Force) {
            throw "The snapshot already exists: $resolvedPath. Use -Force to replace it."
        }
        $parent = Split-Path -Parent $resolvedPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }
        if ($PSCmdlet.ShouldProcess($resolvedPath, 'Write IntuneAccess snapshot')) {
            $snapshot = ConvertTo-IntuneAccessSnapshot -TenantRbac $InputObject -RedactIdentity:$RedactIdentity
            $snapshot | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedPath -Encoding utf8NoBOM
            Get-Item -LiteralPath $resolvedPath
        }
    }
}
