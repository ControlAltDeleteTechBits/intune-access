function Resolve-IntuneScopedPermissionImpact {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowEmptyCollection()] [object[]] $RoleAssignment,
        [ValidateSet('Unknown', 'LegacyMerged', 'Scoped')] [string] $TenantMode = 'Unknown'
    )

    $assignments = @($RoleAssignment)
    $permissionRecords = [System.Collections.Generic.List[object]]::new()
    $tagNames = @{
        '*' = 'All scope tags'
        '0' = 'Default'
        '?' = 'Unknown scope tag context'
    }

    foreach ($assignment in $assignments) {
        foreach ($tag in @(Get-IntuneAccessProperty $assignment 'ScopeTags' @())) {
            $tagId = [string] (Get-IntuneAccessProperty $tag 'Id')
            if (-not [string]::IsNullOrWhiteSpace($tagId)) {
                $tagNames[$tagId] = [string] (Get-IntuneAccessProperty $tag 'DisplayName' "Scope tag $tagId")
            }
        }

        foreach ($action in @(Get-IntuneAccessProperty $assignment 'Permissions' @())) {
            $metadata = ConvertFrom-IntuneAccessActionName -Action $action
            $scopeTagDataState = [string] (Get-IntuneAccessProperty $assignment 'ScopeTagDataState' 'Available')
            $scopeTagIds = if ($scopeTagDataState -eq 'Missing') {
                @('?')
            }
            else {
                $observedIds = @(Get-IntuneAccessProperty (Get-IntuneAccessProperty $assignment 'RawIds') 'ScopeTagIds' @())
                if ($observedIds.Count -eq 0) { @('*') } else { @($observedIds | ForEach-Object { [string] $_ }) }
            }

            $permissionRecords.Add([PSCustomObject] @{
                Assignment          = $assignment
                AssignmentId        = [string] (Get-IntuneAccessProperty $assignment 'Id')
                AssignmentName      = [string] (Get-IntuneAccessProperty $assignment 'Name')
                Applicability       = [string] (Get-IntuneAccessProperty $assignment 'Applicability' 'NotEvaluated')
                ScopeTagDataState   = $scopeTagDataState
                ScopeTagIds         = $scopeTagIds
                RawAction           = [string] $action
                Resource            = $metadata.Resource
                Operation           = $metadata.Operation
            })
        }
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($resourceGroup in @($permissionRecords | Group-Object Resource)) {
        $resourceRecords = @($resourceGroup.Group)
        $knownTagIds = @(
            $resourceRecords |
                Where-Object { $_.Applicability -eq 'Confirmed' -and $_.ScopeTagDataState -ne 'Missing' } |
                ForEach-Object ScopeTagIds |
                Where-Object { $_ -ne '*' } |
                Select-Object -Unique
        )
        $hasUnknownTagContext = @($resourceRecords | Where-Object ScopeTagDataState -EQ 'Missing').Count -gt 0
        $hasAllTagContext = @($resourceRecords | Where-Object {
            $_.Applicability -eq 'Confirmed' -and
            $_.ScopeTagDataState -ne 'Missing' -and
            '*' -in $_.ScopeTagIds
        }).Count -gt 0
        $contexts = if ($knownTagIds.Count -gt 0) {
            @($knownTagIds)
        }
        elseif ($hasAllTagContext -or -not $hasUnknownTagContext) {
            @('*')
        }
        else {
            @()
        }
        if ($hasUnknownTagContext) { $contexts += '?' }

        foreach ($tagId in @($contexts | Select-Object -Unique)) {
            foreach ($actionGroup in @($resourceRecords | Group-Object RawAction)) {
                $actionRecords = @($actionGroup.Group)
                $confirmedActionRecords = @($actionRecords | Where-Object Applicability -EQ 'Confirmed')
                $uncertainActionRecords = @($actionRecords | Where-Object Applicability -NE 'Confirmed')

                if ($tagId -eq '?') {
                    $legacySources = @()
                    $scopedSources = @()
                    $legacyState = 'NotEvaluated'
                    $scopedState = 'NotEvaluated'
                }
                else {
                    $legacySources = @($confirmedActionRecords)
                    $scopedSources = @($confirmedActionRecords | Where-Object {
                        $_.ScopeTagDataState -ne 'Missing' -and
                        ('*' -in $_.ScopeTagIds -or $tagId -in $_.ScopeTagIds)
                    })
                    $unknownScopedSource = @($confirmedActionRecords | Where-Object ScopeTagDataState -EQ 'Missing').Count -gt 0

                    $legacyState = if ($legacySources.Count -gt 0) {
                        'Allowed'
                    }
                    elseif ($uncertainActionRecords.Count -gt 0) {
                        'NotEvaluated'
                    }
                    else {
                        'NotGranted'
                    }

                    $scopedState = if ($scopedSources.Count -gt 0) {
                        'Allowed'
                    }
                    elseif ($unknownScopedSource -or $uncertainActionRecords.Count -gt 0) {
                        'NotEvaluated'
                    }
                    else {
                        'NotGranted'
                    }
                }

                $change = if ($legacyState -eq 'NotEvaluated' -or $scopedState -eq 'NotEvaluated') {
                    'NotEvaluated'
                }
                elseif ($legacyState -eq 'Allowed' -and $scopedState -eq 'NotGranted') {
                    'PermissionReduction'
                }
                else {
                    'NoChange'
                }

                $effectiveState = switch ($TenantMode) {
                    'LegacyMerged' { $legacyState }
                    'Scoped' { $scopedState }
                    default { 'NotEvaluated' }
                }

                $rows.Add([PSCustomObject] @{
                    PSTypeName       = 'IntuneAccess.ScopedPermissionImpactRow'
                    Resource         = $resourceGroup.Name
                    ScopeTagId        = $tagId
                    ScopeTagName      = if ($tagNames.ContainsKey($tagId)) { $tagNames[$tagId] } else { "[Unresolved scope tag: $tagId]" }
                    RawAction         = $actionGroup.Name
                    Operation         = $actionRecords[0].Operation
                    LegacyState       = $legacyState
                    ScopedState       = $scopedState
                    EffectiveState    = $effectiveState
                    Change            = $change
                    LegacyGrantedBy   = @($legacySources | ForEach-Object Assignment)
                    ScopedGrantedBy   = @($scopedSources | ForEach-Object Assignment)
                    UncertainSources  = @($uncertainActionRecords | ForEach-Object Assignment)
                })
            }
        }
    }

    return @($rows | Sort-Object Resource, ScopeTagName, Operation)
}
