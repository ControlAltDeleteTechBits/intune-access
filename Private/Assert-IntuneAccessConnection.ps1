function Assert-IntuneAccessConnection {
    [CmdletBinding()]
    param(
        [string[]] $RequiredScope
    )

    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }

    $context = Get-MgContext
    if ($null -eq $context -or [string]::IsNullOrWhiteSpace([string] $context.Account)) {
        throw 'No Microsoft Graph session is connected. Run Connect-IntuneAccess first.'
    }

    if ($context.TenantId -eq '9188040d-6c67-4c5b-b112-36a304b66dad') {
        throw 'Personal Microsoft accounts are not supported. Connect with a Microsoft Entra work or school account.'
    }

    $environment = [string] (Get-IntuneAccessProperty $context 'Environment')
    if (-not [string]::IsNullOrWhiteSpace($environment) -and $environment -ne 'Global') {
        throw "Microsoft Graph environment '$environment' is not supported in IntuneAccess 2.0.1. Use the Global commercial cloud."
    }

    if ($RequiredScope) {
        $missing = @($RequiredScope | Where-Object { $_ -notin @($context.Scopes) })
        if ($missing.Count -gt 0) {
            throw "The current Graph session is missing delegated scope(s): $($missing -join ', '). Reconnect with Connect-IntuneAccess and select the required feature."
        }
    }

    return $context
}
