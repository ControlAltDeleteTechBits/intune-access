function Connect-IntuneAccess {
    <#
    .SYNOPSIS
    Connects IntuneAccess to Microsoft Graph with delegated, read-only scopes.
    .DESCRIPTION
    Requests the scopes needed by the selected feature. No write permission is requested.
    .PARAMETER Feature
    Selects Core analysis and optional read-only evidence features. Core is always included.
    .EXAMPLE
    Connect-IntuneAccess
    .EXAMPLE
    Connect-IntuneAccess -Feature Core, ScopeTagAudit
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Core', 'AssignmentExplorer', 'OperationalEvidence', 'PolicyAnalysis', 'AuditEvidence', 'ScopeTagAudit', 'ExtendedScopeTagAudit', 'ManagedDeviceAccess', 'DeviceIntelligence', 'Autopilot', 'ApplicationEvidence', 'UpdateCompliance', 'EstateIntelligence')]
        [string[]] $Feature = @('Core')
    )

    $authenticationModule = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
    if ($null -eq $authenticationModule) {
        throw 'Microsoft.Graph.Authentication is not installed. Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }

    Import-Module Microsoft.Graph.Authentication -MinimumVersion 2.0.0 -ErrorAction Stop

    $scopes = [System.Collections.Generic.List[string]]::new()
    foreach ($scope in @('User.Read', 'User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All')) {
        $scopes.Add($scope)
    }

    if ('ScopeTagAudit' -in $Feature -or 'ExtendedScopeTagAudit' -in $Feature) {
        foreach ($scope in @('DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All')) {
            if ($scope -notin $scopes) { $scopes.Add($scope) }
        }
    }
    if ('AssignmentExplorer' -in $Feature) {
        foreach ($scope in @('DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All', 'DeviceManagementScripts.Read.All')) {
            if ($scope -notin $scopes) { $scopes.Add($scope) }
        }
    }
    if ('OperationalEvidence' -in $Feature) {
        foreach ($scope in @('DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All', 'DeviceManagementScripts.Read.All', 'DeviceManagementManagedDevices.Read.All')) {
            if ($scope -notin $scopes) { $scopes.Add($scope) }
        }
    }
    if ('PolicyAnalysis' -in $Feature -and 'DeviceManagementConfiguration.Read.All' -notin $scopes) {
        $scopes.Add('DeviceManagementConfiguration.Read.All')
    }
    if ('AuditEvidence' -in $Feature -and 'DeviceManagementApps.Read.All' -notin $scopes) {
        $scopes.Add('DeviceManagementApps.Read.All')
    }
    if ('ExtendedScopeTagAudit' -in $Feature -and 'DeviceManagementScripts.Read.All' -notin $scopes) {
        $scopes.Add('DeviceManagementScripts.Read.All')
    }
    if ('ManagedDeviceAccess' -in $Feature) {
        foreach ($scope in @('DeviceManagementManagedDevices.Read.All', 'Device.Read.All')) {
            if ($scope -notin $scopes) { $scopes.Add($scope) }
        }
    }
    if (@('DeviceIntelligence', 'ApplicationEvidence', 'UpdateCompliance', 'EstateIntelligence') | Where-Object { $_ -in $Feature }) {
        foreach ($scope in @('DeviceManagementManagedDevices.Read.All', 'Device.Read.All')) {
            if ($scope -notin $scopes) { $scopes.Add($scope) }
        }
    }
    if (@('ApplicationEvidence', 'EstateIntelligence') | Where-Object { $_ -in $Feature }) {
        if ('DeviceManagementApps.Read.All' -notin $scopes) { $scopes.Add('DeviceManagementApps.Read.All') }
    }
    if (@('UpdateCompliance', 'EstateIntelligence') | Where-Object { $_ -in $Feature }) {
        if ('DeviceManagementConfiguration.Read.All' -notin $scopes) { $scopes.Add('DeviceManagementConfiguration.Read.All') }
    }
    if ('Autopilot' -in $Feature) {
        foreach ($scope in @('DeviceManagementManagedDevices.Read.All', 'DeviceManagementServiceConfig.Read.All')) {
            if ($scope -notin $scopes) { $scopes.Add($scope) }
        }
    }

    Write-Verbose "Requesting delegated read scopes: $($scopes -join ', ')"
    $null = Connect-MgGraph -Scopes $scopes.ToArray() -NoWelcome -ContextScope Process
    $context = Assert-IntuneAccessConnection -RequiredScope $scopes.ToArray()
    $tenant = Get-IntuneAccessTenant

    [PSCustomObject] @{
        PSTypeName    = 'IntuneAccess.Connection'
        Connected     = $true
        Account       = [string] $context.Account
        TenantId      = [string] $context.TenantId
        TenantName    = [string] $tenant.DisplayName
        Environment   = [string] $context.Environment
        AuthType      = [string] $context.AuthType
        Scopes        = @($context.Scopes)
        SelectedFeatures = @($Feature | Select-Object -Unique)
        ReadOnly      = $true
        ToolVersion   = $script:IntuneAccessVersion
    }
}
