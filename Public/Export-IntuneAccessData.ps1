function Export-IntuneAccessData {
    <#
    .SYNOPSIS
    Exports IntuneAccess evidence as JSON or a set of CSV files.
    .PARAMETER InputObject
    An IntuneAccess administrator result, comparison or Scoped permissions result.
    .PARAMETER Path
    A JSON file path or a CSV destination directory.
    .PARAMETER Format
    JSON writes the complete evidence object. CSV writes flattened administrator datasets.
    .PARAMETER Force
    Replaces existing output files.
    .EXAMPLE
    $access | Export-IntuneAccessData -Path './access-snapshot.json' -Format Json
    .EXAMPLE
    $access | Export-IntuneAccessData -Path './access-csv' -Format Csv
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object] $InputObject,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
        [Parameter(Mandatory)] [ValidateSet('Json', 'Csv')] [string] $Format,
        [switch] $Force
    )

    process {
        $supportedTypes = @(
            'IntuneAccess.AdminAccess',
            'IntuneAccess.AdminAccessComparison',
            'IntuneAccess.ScopedPermissionImpact'
        )
        if (@($InputObject.PSObject.TypeNames | Where-Object { $_ -in $supportedTypes }).Count -eq 0) {
            throw 'InputObject must be an IntuneAccess administrator, comparison or Scoped permissions result.'
        }

        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        if ($Format -eq 'Json') {
            if ([IO.Path]::GetExtension($resolvedPath) -ne '.json') {
                throw 'JSON output requires a .json file extension.'
            }
            if ((Test-Path -LiteralPath $resolvedPath) -and -not $Force) {
                throw "The export already exists: $resolvedPath. Use -Force to replace it."
            }
            $parent = Split-Path -Parent $resolvedPath
            if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
                $null = New-Item -ItemType Directory -Path $parent -Force
            }
            if ($PSCmdlet.ShouldProcess($resolvedPath, 'Write IntuneAccess JSON evidence')) {
                $envelope = [ordered] @{
                    Schema        = 'https://controlaltdeletetechbits.github.io/intune-access/schemas/evidence-1.0.json'
                    SchemaVersion = '1.0'
                    DataType      = @($InputObject.PSObject.TypeNames | Where-Object { $_ -like 'IntuneAccess.*' })[0]
                    ToolVersion   = $script:IntuneAccessVersion
                    ExportedAt    = [DateTimeOffset]::Now
                    Data          = $InputObject
                }
                $envelope | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedPath -Encoding utf8NoBOM
                return Get-Item -LiteralPath $resolvedPath
            }
            return
        }

        if ('IntuneAccess.AdminAccess' -notin $InputObject.PSObject.TypeNames) {
            throw 'CSV export currently accepts only a result returned by Get-IntuneAdminAccess.'
        }
        if ((Test-Path -LiteralPath $resolvedPath) -and
            @(Get-ChildItem -LiteralPath $resolvedPath -File -ErrorAction SilentlyContinue).Count -gt 0 -and
            -not $Force) {
            throw "The CSV destination contains files: $resolvedPath. Use -Force to replace the IntuneAccess datasets."
        }
        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            $null = New-Item -ItemType Directory -Path $resolvedPath -Force
        }
        if (-not $PSCmdlet.ShouldProcess($resolvedPath, 'Write IntuneAccess CSV evidence datasets')) { return }

        $datasets = [ordered] @{}
        $datasets['summary.csv'] = @([PSCustomObject] @{
            UserId              = $InputObject.User.Id
            UserPrincipalName   = $InputObject.User.UserPrincipalName
            TenantId            = $InputObject.Tenant.Id
            TenantName          = $InputObject.Tenant.DisplayName
            RoleAssignmentCount = @($InputObject.RoleAssignments).Count
            PermissionCount     = @($InputObject.EffectivePermissions).Count
            WarningCount        = @($InputObject.Warnings).Count
            GeneratedAt         = $InputObject.GeneratedAt
            ToolVersion         = $InputObject.ToolVersion
        })
        $datasets['role-assignments.csv'] = @($InputObject.RoleAssignments | ForEach-Object {
            [PSCustomObject] @{
                Id                 = $_.Id
                Name               = $_.Name
                Applicability      = $_.Applicability
                RoleDefinitionId   = $_.RoleDefinition.Id
                RoleDefinitionName = $_.RoleDefinition.DisplayName
                IsBuiltIn          = $_.RoleDefinition.IsBuiltIn
                AdminGroupIds      = @($_.RawIds.AdminGroupIds) -join ';'
                ScopeGroupIds      = @($_.RawIds.ScopeGroupIds) -join ';'
                ScopeTagIds        = @($_.RawIds.ScopeTagIds) -join ';'
                Permissions        = @($_.Permissions) -join ';'
            }
        })
        $datasets['effective-permissions.csv'] = @($InputObject.EffectivePermissions | ForEach-Object {
            [PSCustomObject] @{
                RawAction              = $_.RawAction
                Resource               = $_.Resource
                Operation              = $_.Operation
                State                  = $_.State
                SourceCount            = $_.SourceCount
                IsDuplicate            = $_.IsDuplicate
                GrantingAssignmentIds  = @($_.GrantedBy.RoleAssignmentId) -join ';'
                GrantingAssignmentNames = @($_.GrantedBy.RoleAssignmentName) -join ';'
            }
        })
        foreach ($groupSet in @(
            [PSCustomObject] @{ File = 'admin-groups.csv'; Values = @($InputObject.AdminGroups) }
            [PSCustomObject] @{ File = 'scope-groups.csv'; Values = @($InputObject.ScopeGroups) }
            [PSCustomObject] @{ File = 'scope-tags.csv'; Values = @($InputObject.ScopeTags) }
        )) {
            $datasets[$groupSet.File] = @($groupSet.Values | ForEach-Object {
                [PSCustomObject] @{ Id = $_.Id; DisplayName = $_.DisplayName; ResolutionState = (Get-IntuneAccessProperty $_ 'ResolutionState' 'Resolved') }
            })
        }
        $datasets['warnings.csv'] = @($InputObject.Warnings | ForEach-Object { [PSCustomObject] @{ Warning = $_ } })
        $datasets['evidence.csv'] = @($InputObject.Evidence | ForEach-Object {
            [PSCustomObject] @{
                UserId             = $_.UserId
                UserPrincipalName  = $_.UserPrincipalName
                AdminGroupId       = $_.AdminGroupId
                AdminGroupName     = $_.AdminGroupName
                MembershipType     = $_.MembershipType
                RoleAssignmentId   = $_.RoleAssignmentId
                RoleAssignmentName = $_.RoleAssignmentName
                RoleDefinitionId   = $_.RoleDefinitionId
                RoleDefinitionName = $_.RoleDefinitionName
                Applicability      = $_.Applicability
            }
        })

        $datasetHeaders = @{
            'summary.csv' = @('UserId', 'UserPrincipalName', 'TenantId', 'TenantName', 'RoleAssignmentCount', 'PermissionCount', 'WarningCount', 'GeneratedAt', 'ToolVersion')
            'role-assignments.csv' = @('Id', 'Name', 'Applicability', 'RoleDefinitionId', 'RoleDefinitionName', 'IsBuiltIn', 'AdminGroupIds', 'ScopeGroupIds', 'ScopeTagIds', 'Permissions')
            'effective-permissions.csv' = @('RawAction', 'Resource', 'Operation', 'State', 'SourceCount', 'IsDuplicate', 'GrantingAssignmentIds', 'GrantingAssignmentNames')
            'admin-groups.csv' = @('Id', 'DisplayName', 'ResolutionState')
            'scope-groups.csv' = @('Id', 'DisplayName', 'ResolutionState')
            'scope-tags.csv' = @('Id', 'DisplayName', 'ResolutionState')
            'warnings.csv' = @('Warning')
            'evidence.csv' = @('UserId', 'UserPrincipalName', 'AdminGroupId', 'AdminGroupName', 'MembershipType', 'RoleAssignmentId', 'RoleAssignmentName', 'RoleDefinitionId', 'RoleDefinitionName', 'Applicability')
        }

        $written = [System.Collections.Generic.List[IO.FileInfo]]::new()
        foreach ($dataset in $datasets.GetEnumerator()) {
            $filePath = Join-Path $resolvedPath $dataset.Key
            $rows = @($dataset.Value)
            if ($rows.Count -gt 0) {
                $rows | Export-Csv -LiteralPath $filePath -NoTypeInformation -Encoding utf8 -Force
            }
            else {
                $emptyRow = [ordered] @{}
                foreach ($header in $datasetHeaders[$dataset.Key]) { $emptyRow[$header] = $null }
                $headerLine = @([PSCustomObject] $emptyRow | ConvertTo-Csv -NoTypeInformation)[0]
                Set-Content -LiteralPath $filePath -Value $headerLine -Encoding utf8NoBOM
            }
            $written.Add((Get-Item -LiteralPath $filePath))
        }
        return $written.ToArray()
    }
}
