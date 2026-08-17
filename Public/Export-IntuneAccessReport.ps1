function Export-IntuneAccessReport {
    <#
    .SYNOPSIS
    Exports an IntuneAccess result as a self-contained HTML report.
    .PARAMETER InputObject
    An object returned by Get-IntuneAdminAccess.
    .PARAMETER UserPrincipalName
    Runs the analysis for this user before exporting.
    .PARAMETER UserId
    Runs the analysis for this object ID before exporting.
    .PARAMETER Path
    Destination HTML file.
    .PARAMETER Force
    Replaces an existing report.
    .EXAMPLE
    Get-IntuneAdminAccess -UserPrincipalName 'admin@contoso.com' | Export-IntuneAccessReport -Path './IntuneAccess.html'
    .EXAMPLE
    Export-IntuneAccessReport -UserPrincipalName 'admin@contoso.com' -Path './IntuneAccess.html'
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Input')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'Input')] [object] $InputObject,
        [Parameter(Mandatory, ParameterSetName = 'ByUpn')] [ValidateNotNullOrEmpty()] [string] $UserPrincipalName,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [guid] $UserId,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
        [switch] $Force
    )

    process {
        $access = switch ($PSCmdlet.ParameterSetName) {
            'ByUpn' { Get-IntuneAdminAccess -UserPrincipalName $UserPrincipalName }
            'ById'  { Get-IntuneAdminAccess -UserId $UserId }
            default { $InputObject }
        }
        if ('IntuneAccess.AdminAccess' -notin $access.PSObject.TypeNames) {
            throw 'InputObject must be a result returned by Get-IntuneAdminAccess.'
        }

        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if ([IO.Path]::GetExtension($resolvedPath) -notin @('.html', '.htm')) {
            throw 'The report path must use an .html or .htm extension.'
        }
        if ((Test-Path -LiteralPath $resolvedPath) -and -not $Force) {
            throw "The report already exists: $resolvedPath. Use -Force to replace it."
        }

        $parent = Split-Path -Parent $resolvedPath
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
            $null = New-Item -ItemType Directory -Path $parent -Force
        }

        if ($PSCmdlet.ShouldProcess($resolvedPath, 'Write self-contained Intune access report')) {
            $html = ConvertTo-IntuneAccessHtml -Access $access
            Set-Content -LiteralPath $resolvedPath -Value $html -Encoding utf8NoBOM
            Write-Warning 'The report may contain usernames, group names, device names and administrative configuration. Store and share it accordingly.'
            Get-Item -LiteralPath $resolvedPath
        }
    }
}
