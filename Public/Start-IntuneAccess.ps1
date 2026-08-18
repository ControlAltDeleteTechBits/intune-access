function Start-IntuneAccess {
    <#
    .SYNOPSIS
    Signs in, collects tenant Intune RBAC data, creates a local HTML explorer and opens it.
    .DESCRIPTION
    Provides the guided IntuneAccess workflow for an interactive end user. It collects
    administrators and objects connected to Intune RBAC role assignments, plus supported
    Intune policy, application, script and update assignments. The optional user principal
    name selects the initial administrator in the explorer.
    .PARAMETER UserPrincipalName
    The administrator to select initially in the explorer. Tenant-wide RBAC data is still collected.
    .PARAMETER Feature
    Selects the read-only feature scopes used for the connection. Core, AssignmentExplorer, OperationalEvidence, PolicyAnalysis and AuditEvidence are the defaults.
    .PARAMETER Path
    Destination HTML file. A timestamped file in Documents is used by default.
    .PARAMETER SnapshotPath
    Optional destination for the current local JSON snapshot.
    .PARAMETER BaselineSnapshotPath
    Optional earlier snapshot to compare with the current collection. When supplied,
    a current snapshot is saved even when SnapshotPath is omitted.
    .PARAMETER RedactSnapshotIdentity
    Pseudonymises tenant and identity values in the saved snapshot.
    .PARAMETER NoOpen
    Creates the report without opening it in the default browser.
    .PARAMETER Force
    Replaces an existing report when an explicit Path is used.
    .EXAMPLE
    Start-IntuneAccess
    .EXAMPLE
    Start-IntuneAccess -UserPrincipalName 'helpdesk.user@contoso.com'
    #>
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName,

        [ValidateSet('Core', 'AssignmentExplorer', 'OperationalEvidence', 'PolicyAnalysis', 'AuditEvidence', 'ScopeTagAudit', 'ExtendedScopeTagAudit', 'ManagedDeviceAccess')]
        [string[]] $Feature = @('Core', 'AssignmentExplorer', 'OperationalEvidence', 'PolicyAnalysis', 'AuditEvidence'),

        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateNotNullOrEmpty()]
        [string] $SnapshotPath,

        [ValidateNotNullOrEmpty()]
        [string] $BaselineSnapshotPath,

        [switch] $NoOpen,
        [switch] $RedactSnapshotIdentity,
        [switch] $Force
    )

    $activity = 'IntuneAccess tenant RBAC explorer'
    try {
        Write-Progress -Activity $activity -Status 'Opening delegated Microsoft Graph sign-in' -PercentComplete 5
        $connection = Connect-IntuneAccess -Feature $Feature
        $initialUser = if ([string]::IsNullOrWhiteSpace($UserPrincipalName)) { [string] $connection.Account } else { $UserPrincipalName.Trim() }

        Write-Progress -Activity $activity -Status 'Collecting Intune role assignments and connected objects' -PercentComplete 30
        $tenantRbac = Get-IntuneAccessTenantRbac `
            -InitialUserPrincipalName $initialUser `
            -IncludeWorkloadAssignments:('AssignmentExplorer' -in $Feature) `
            -IncludeOperationalEvidence:('OperationalEvidence' -in $Feature) `
            -IncludePolicyAnalysis:('PolicyAnalysis' -in $Feature) `
            -IncludeAuditEvidence:('AuditEvidence' -in $Feature)

        if ([string]::IsNullOrWhiteSpace($Path)) {
            $documentsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
            if ([string]::IsNullOrWhiteSpace($documentsPath)) {
                $documentsPath = (Get-Location).ProviderPath
            }

            $tenantName = [string] (Get-IntuneAccessProperty $tenantRbac.Tenant 'DisplayName' 'tenant')
            $safeTenantName = ($tenantName -replace '[^A-Za-z0-9._-]', '-').Trim('-')
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $Path = Join-Path $documentsPath "IntuneAccess-$safeTenantName-$timestamp.html"
        }

        $snapshot = $null
        $snapshotComparison = $null
        if (-not [string]::IsNullOrWhiteSpace($SnapshotPath) -or -not [string]::IsNullOrWhiteSpace($BaselineSnapshotPath)) {
            if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
                $SnapshotPath = [IO.Path]::ChangeExtension($Path, '.snapshot.json')
            }
            Write-Progress -Activity $activity -Status 'Saving the local evidence snapshot' -PercentComplete 70
            $snapshot = $tenantRbac | Export-IntuneAccessSnapshot -Path $SnapshotPath -RedactIdentity:$RedactSnapshotIdentity -Force:$Force
            if (-not [string]::IsNullOrWhiteSpace($BaselineSnapshotPath)) {
                $snapshotComparison = Compare-IntuneAccessSnapshot -ReferencePath $BaselineSnapshotPath -DifferencePath $snapshot.FullName -AuditEvent @(Get-IntuneAccessProperty $tenantRbac 'AuditEvents' @())
                $tenantRbac | Add-Member -NotePropertyName SnapshotComparison -NotePropertyValue $snapshotComparison -Force
            }
        }

        Write-Progress -Activity $activity -Status 'Generating the self-contained Signal Atlas explorer' -PercentComplete 80
        $report = $tenantRbac | Export-IntuneAccessReport -Path $Path -Force:$Force

        if (-not $NoOpen) {
            Write-Progress -Activity $activity -Status 'Opening the explorer in the default browser' -PercentComplete 95
            Invoke-Item -LiteralPath $report.FullName
        }

        [PSCustomObject] @{
            PSTypeName       = 'IntuneAccess.RunResult'
            ConnectedAccount = [string] $connection.Account
            Tenant           = [string] $tenantRbac.Tenant.DisplayName
            Administrators   = @($tenantRbac.Administrators).Count
            RoleAssignments  = @($tenantRbac.RoleAssignments).Count
            WorkloadObjects  = @(Get-IntuneAccessProperty $tenantRbac 'WorkloadObjects' @()).Count
            WorkloadAssignments = @(Get-IntuneAccessProperty $tenantRbac 'WorkloadAssignments' @()).Count
            ManagedDevices    = @(Get-IntuneAccessProperty $tenantRbac 'ManagedDevices' @()).Count
            DeploymentOutcomes = @(Get-IntuneAccessProperty $tenantRbac 'DeploymentOutcomes' @()).Count
            SnapshotPath      = if ($null -eq $snapshot) { '' } else { [string] $snapshot.FullName }
            SnapshotChanges   = if ($null -eq $snapshotComparison) { 0 } else { @($snapshotComparison.Changes).Count }
            PolicySettings    = @(Get-IntuneAccessProperty $tenantRbac 'PolicySettings' @()).Count
            PotentialPolicyConflicts = @(Get-IntuneAccessProperty $tenantRbac 'PolicyConflictFindings' @() | Where-Object FindingState -EQ 'PotentialConflict').Count
            AuditEvents        = @(Get-IntuneAccessProperty $tenantRbac 'AuditEvents' @()).Count
            ReportPath       = [string] $report.FullName
            Opened           = -not $NoOpen.IsPresent
            ReadOnly         = $true
            ToolVersion      = $script:IntuneAccessVersion
        }
    }
    finally {
        Write-Progress -Activity $activity -Completed
    }
}
