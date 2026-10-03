<#
.SYNOPSIS
Generates the IntuneAccess demonstration report from a fictional tenant.

.DESCRIPTION
Runs the real IntuneAccess collection, analysis and report code against synthetic
Microsoft Graph responses defined in tools/demo/IntuneAccessDemoTenant.ps1. No sign-in
occurs and no network request is made. Every name, identifier and result is fictional.

Two snapshots are produced a simulated day apart so the report also demonstrates
snapshot comparison, change correlation and finding verification.

.PARAMETER OutputDirectory
Folder that receives index.html. Defaults to ./demo-site under the repository root.

.EXAMPLE
./tools/New-IntuneAccessDemo.ps1 -OutputDirectory ./demo-site
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string] $OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'demo-site')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'demo/IntuneAccessDemoTenant.ps1')

$module = Import-Module (Join-Path $repositoryRoot 'IntuneAccess.psd1') -Force -PassThru
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).ProviderPath
$work = Join-Path ([IO.Path]::GetTempPath()) ("intuneaccess-demo-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work

$scopes = @(
    'User.Read', 'User.Read.All', 'GroupMember.Read.All', 'DeviceManagementRBAC.Read.All',
    'DeviceManagementConfiguration.Read.All', 'DeviceManagementApps.Read.All', 'DeviceManagementScripts.Read.All',
    'DeviceManagementManagedDevices.Read.All', 'Device.Read.All'
)

function Invoke-DemoCollection {
    param([object] $Tenant)
    & $module {
        param($Tenant, $Scopes, $ResponseFunction)
        $script:IntuneAccessDemoTenant = $Tenant
        $script:IntuneAccessDemoScopes = $Scopes
        $script:IntuneAccessDemoResponse = $ResponseFunction
        # Module-scoped overrides replace the Graph session and transport for this run only.
        function script:Assert-IntuneAccessConnection {
            param([string[]] $RequiredScope)
            $null = $RequiredScope
            [PSCustomObject] @{ Account = $script:IntuneAccessDemoTenant.SignedInUser.userPrincipalName; TenantId = $script:IntuneAccessDemoTenant.Organization.id; Scopes = $script:IntuneAccessDemoScopes; Environment = 'Global'; AuthType = 'Delegated' }
        }
        function script:Get-MgContext { Assert-IntuneAccessConnection }
        function script:Invoke-MgGraphRequest {
            param([string] $Method, [string] $Uri, [string] $OutputType)
            $null = $OutputType
            if ($Method -ne 'GET') { throw 'The demonstration back end accepts GET only.' }
            & $script:IntuneAccessDemoResponse -Tenant $script:IntuneAccessDemoTenant -Uri $Uri
        }
        Get-IntuneAccessTenantRbac `
            -InitialUserPrincipalName $Tenant.SignedInUser.userPrincipalName `
            -IncludeWorkloadAssignments -IncludeOperationalEvidence -IncludePolicyAnalysis `
            -IncludeDeviceIntelligence -IncludeAssignmentExplanations -IncludeApplicationEvidence `
            -IncludeUpdateCompliance -IncludeEstateIntelligence -IncludeAuditEvidence
    } $Tenant $scopes ${function:Get-IntuneAccessDemoResponse}
}

try {
    $now = [DateTimeOffset]::UtcNow

    # Baseline: the day before. The Edge password manager change and the VPN detection-rule
    # change have not happened yet, so the VPN install failures have not started.
    $baselineTenant = New-IntuneAccessDemoTenant -AsOf $now.AddDays(-1) -Anchor $now
    $baselineTenant.AuditEvents = @($baselineTenant.AuditEvents | Where-Object { [DateTimeOffset]::Parse($_.activityDateTime) -lt $now.AddDays(-1.2) })
    $edge = $baselineTenant.ConfigurationPolicies[1].id
    $baselineTenant.PolicySettings[$edge] = @($baselineTenant.PolicySettings[$edge] | ForEach-Object {
        $copy = $_ | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $copy.settingInstance.choiceSettingValue.value = $copy.settingInstance.choiceSettingValue.value -replace '_1$', '_0'
        $copy
    })
    $vpn = $baselineTenant.MobileApps[0].id
    $baselineTenant.Statuses[$vpn] = @($baselineTenant.Statuses[$vpn] | ForEach-Object {
        $copy = $_.PSObject.Copy(); if ($copy.installState -eq 'failed') { $copy.installState = 'installed'; $copy.installStateDetail = 'noAdditionalDetails'; $copy.errorCode = 0 }; $copy
    })

    $baseline = Invoke-DemoCollection -Tenant $baselineTenant
    $baselinePath = Join-Path $work 'baseline.snapshot.json'
    $null = $baseline | Export-IntuneAccessSnapshot -Path $baselinePath -Force

    $currentTenant = New-IntuneAccessDemoTenant -AsOf $now -Anchor $now
    $current = Invoke-DemoCollection -Tenant $currentTenant
    $currentPath = Join-Path $work 'current.snapshot.json'
    $null = $current | Export-IntuneAccessSnapshot -Path $currentPath -Force

    $comparison = Compare-IntuneAccessSnapshot -ReferencePath $baselinePath -DifferencePath $currentPath -AuditEvent @($current.AuditEvents)
    $current | Add-Member -NotePropertyName SnapshotComparison -NotePropertyValue $comparison -Force
    if ($null -ne $comparison.PSObject.Properties['ActionCentre'] -and $null -ne $comparison.ActionCentre) {
        $current | Add-Member -NotePropertyName ActionCentre -NotePropertyValue $comparison.ActionCentre -Force
    }
    if ($null -ne $comparison.PSObject.Properties['FindingVerification']) {
        $current | Add-Member -NotePropertyName FindingVerification -NotePropertyValue @($comparison.FindingVerification) -Force
    }
    $current | Add-Member -NotePropertyName EstateHistoricalTrend -NotePropertyValue ([PSCustomObject] @{
        State = 'Compared'; Changes = @($comparison.Changes); Explanation = 'Changes were calculated locally from two synthetic snapshots one simulated day apart.'
    }) -Force
    $current.Warnings = @('Demonstration report: every tenant, person, group, device, policy and result is fictional. No Microsoft tenant was accessed.') + @($current.Warnings)

    $reportPath = Join-Path $OutputDirectory 'index.html'
    $null = $current | Export-IntuneAccessReport -Path $reportPath -Force 3>$null

    # Real reports are marked noindex because they contain tenant data. The public
    # demonstration is fictional, so it is made discoverable with a descriptive title.
    $html = [IO.File]::ReadAllText($reportPath)
    $html = $html.Replace('<meta name="robots" content="noindex,nofollow">', '<meta name="robots" content="index,follow"><meta name="description" content="Live demonstration of IntuneAccess, a free, open source and read-only PowerShell tool that explains Microsoft Intune RBAC, policy and app assignments, device outcomes and changes in one offline report. All data is fictional.">')
    $html = [regex]::Replace($html, '<title>[^<]*</title>', '<title>IntuneAccess live demo: free read-only Microsoft Intune RBAC, assignment and device evidence explorer</title>', 1)
    [IO.File]::WriteAllText($reportPath, $html, [Text.UTF8Encoding]::new($false))

    [PSCustomObject] @{
        ReportPath          = $reportPath
        Administrators      = @($current.Administrators).Count
        RoleAssignments     = @($current.RoleAssignments).Count
        WorkloadObjects     = @($current.WorkloadObjects).Count
        ManagedDevices      = @($current.ManagedDevices).Count
        DeploymentOutcomes  = @($current.DeploymentOutcomes).Count
        PotentialConflicts  = @($current.PolicyConflictFindings | Where-Object FindingState -EQ 'PotentialConflict').Count
        AuditEvents         = @($current.AuditEvents).Count
        SnapshotChanges     = @($comparison.Changes).Count
        Warnings            = @($current.Warnings)
    }
}
finally {
    if (-not $env:INTUNEACCESS_DEMO_KEEP) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
