function Import-IntuneAccessPermissionAssessment {
    <#
    Reads the Permissions Assessment Report export from Tenant administration > Roles > Settings.
    Accepts .csv or .xlsx. The .xlsx reader uses System.IO.Compression only, so no extra module is needed.
    Expected columns: Group, Roles, Scope Tag, Resource, Old Permissions, New Permissions.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $extension = [IO.Path]::GetExtension($resolved).ToLowerInvariant()
    $table = [System.Collections.Generic.List[string[]]]::new()

    if ($extension -eq '.csv') {
        $records = @(Import-Csv -LiteralPath $resolved)
        if ($records.Count -gt 0) {
            $headers = @($records[0].PSObject.Properties.Name)
            $table.Add([string[]] $headers)
            foreach ($record in $records) { $table.Add([string[]] @($headers | ForEach-Object { [string] $record.$_ })) }
        }
    }
    elseif ($extension -eq '.xlsx') {
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($resolved)
        try {
            function Read-ZipXml([string] $Name) {
                $entry = $zip.GetEntry($Name)
                if ($null -eq $entry) { return $null }
                $reader = [IO.StreamReader]::new($entry.Open())
                try { [xml] $reader.ReadToEnd() } finally { $reader.Dispose() }
            }
            $shared = [System.Collections.Generic.List[string]]::new()
            $sharedXml = Read-ZipXml 'xl/sharedStrings.xml'
            if ($null -ne $sharedXml) {
                foreach ($item in $sharedXml.GetElementsByTagName('si')) { $shared.Add(($item.GetElementsByTagName('t') | ForEach-Object { $_.InnerText }) -join '') }
            }
            $sheetEntry = @($zip.Entries | Where-Object { $_.FullName -like 'xl/worksheets/sheet*.xml' } | Sort-Object FullName | Select-Object -First 1)
            if ($sheetEntry.Count -eq 0) { throw 'The workbook contains no worksheet.' }
            $sheet = Read-ZipXml $sheetEntry[0].FullName
            foreach ($row in $sheet.GetElementsByTagName('row')) {
                $cells = @{}
                $maxIndex = -1
                foreach ($cell in $row.GetElementsByTagName('c')) {
                    $letters = ([regex]::Match($cell.GetAttribute('r'), '^[A-Z]+')).Value
                    $index = 0
                    foreach ($char in $letters.ToCharArray()) { $index = ($index * 26) + ([int] $char - 64) }
                    $index--
                    $valueNode = @($cell.GetElementsByTagName('v'))
                    $value = if ($cell.GetAttribute('t') -eq 's' -and $valueNode.Count) { $shared[[int] $valueNode[0].InnerText] }
                        elseif ($cell.GetAttribute('t') -eq 'inlineStr') { ($cell.GetElementsByTagName('t') | ForEach-Object { $_.InnerText }) -join '' }
                        elseif ($valueNode.Count) { $valueNode[0].InnerText }
                        else { '' }
                    $cells[$index] = $value
                    if ($index -gt $maxIndex) { $maxIndex = $index }
                }
                if ($maxIndex -lt 0) { continue }
                $table.Add([string[]] @(0..$maxIndex | ForEach-Object { if ($cells.ContainsKey($_)) { [string] $cells[$_] } else { '' } }))
            }
        }
        finally { $zip.Dispose() }
    }
    else { throw 'The Permissions Assessment Report must be a .csv or .xlsx export.' }

    if ($table.Count -eq 0) {
        return [PSCustomObject] @{ PSTypeName = 'IntuneAccess.PermissionAssessment'; Path = $resolved; Rows = @(); State = 'Empty'; Warnings = @('The export contains no rows. Microsoft omits groups that are not affected by permission merging.') }
    }

    $wanted = [ordered] @{ Group = 'group'; Roles = 'roles'; ScopeTag = 'scopetag'; Resource = 'resource'; OldPermissions = 'oldpermissions'; NewPermissions = 'newpermissions' }
    $headerRow = -1
    for ($i = 0; $i -lt [Math]::Min(10, $table.Count); $i++) {
        $normalised = @($table[$i] | ForEach-Object { ($_ -replace '[^A-Za-z]', '').ToLowerInvariant() })
        if (@($wanted.Values | Where-Object { $_ -in $normalised }).Count -ge 4) { $headerRow = $i; break }
    }
    if ($headerRow -lt 0) { throw 'The file does not look like a Permissions Assessment Report export. Expected the columns Group, Roles, Scope Tag, Resource, Old Permissions and New Permissions.' }
    $headers = @($table[$headerRow] | ForEach-Object { ($_ -replace '[^A-Za-z]', '').ToLowerInvariant() })
    $columnIndex = @{}
    foreach ($key in $wanted.Keys) { $columnIndex[$key] = [array]::IndexOf($headers, $wanted[$key]) }
    $missing = @($wanted.Keys | Where-Object { $columnIndex[$_] -lt 0 })

    function Split-Permission([string] $Value) {
        @(($Value -split '[,;\r\n]+') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    for ($i = $headerRow + 1; $i -lt $table.Count; $i++) {
        $line = $table[$i]
        $get = { param($k) if ($columnIndex[$k] -ge 0 -and $columnIndex[$k] -lt $line.Count) { [string] $line[$columnIndex[$k]] } else { '' } }
        $group = (& $get 'Group').Trim()
        if (-not $group) { continue }
        $rows.Add([PSCustomObject] @{
            PSTypeName     = 'IntuneAccess.PermissionAssessmentRow'
            Group          = $group
            Roles          = @((& $get 'Roles') -split '[,;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            ScopeTag       = (& $get 'ScopeTag').Trim()
            Resource       = (& $get 'Resource').Trim()
            OldPermissions = Split-Permission (& $get 'OldPermissions')
            NewPermissions = Split-Permission (& $get 'NewPermissions')
        })
    }
    [PSCustomObject] @{
        PSTypeName = 'IntuneAccess.PermissionAssessment'
        Path       = $resolved
        Rows       = $rows.ToArray()
        State      = if ($rows.Count) { 'Imported' } else { 'Empty' }
        Warnings   = @($missing | ForEach-Object { "Column '$_' was not found; it is treated as empty." })
    }
}

function Get-IntuneAccessScopedReadiness {
    <#
    Models the Scoped permissions change for every Admin Group, mirroring the shape of Microsoft's
    Permissions Assessment Report (group, scope tag, resource, old and new permissions), and
    reconciles the model with an imported report when one is supplied.
    The tenant setting is never read or changed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Collection,
        [AllowNull()] [object] $Assessment
    )

    function ConvertTo-ResourceKey([string] $Value) { ($Value -replace '[^A-Za-z0-9]', '').ToLowerInvariant() }
    function ConvertTo-OperationKey([string] $Value) { ($Value -replace '[^A-Za-z0-9]', '').ToLowerInvariant() }

    $roleAssignments = @(Get-IntuneAccessProperty $Collection 'RoleAssignments' @())
    $memberships = @(Get-IntuneAccessProperty $Collection 'Memberships' @())
    $adminGroups = @(Get-IntuneAccessProperty $Collection 'AdminGroups' @())
    $modelRows = [System.Collections.Generic.List[object]]::new()

    foreach ($group in $adminGroups) {
        $groupId = [string] $group.Id
        $memberCount = @($memberships | Where-Object { [string] $_.GroupId -eq $groupId } | ForEach-Object { $_.User.Id } | Select-Object -Unique).Count
        $groupAssignments = @($roleAssignments | Where-Object { $groupId -in @($_.RawIds.AdminGroupIds | ForEach-Object { [string] $_ }) } | ForEach-Object {
            $view = $_ | Select-Object *
            $view | Add-Member -NotePropertyName Applicability -NotePropertyValue 'Confirmed' -Force
            $view
        })
        if ($groupAssignments.Count -lt 2) { continue }
        $impact = @(Resolve-IntuneScopedPermissionImpact -RoleAssignment $groupAssignments)
        foreach ($context in @($impact | Group-Object Resource, ScopeTagId)) {
            $contextRows = @($context.Group)
            $reductions = @($contextRows | Where-Object Change -EQ 'PermissionReduction')
            $unknown = @($contextRows | Where-Object Change -EQ 'NotEvaluated')
            if ($reductions.Count -eq 0 -and $unknown.Count -eq 0) { continue }
            $legacyRoleNames = @($contextRows | ForEach-Object { $_.LegacyGrantedBy } | ForEach-Object { [string] (Get-IntuneAccessProperty (Get-IntuneAccessProperty $_ 'RoleDefinition') 'DisplayName' '') } | Where-Object { $_ } | Sort-Object -Unique)
            $modelRows.Add([PSCustomObject] @{
                PSTypeName     = 'IntuneAccess.ScopedReadinessRow'
                GroupId        = $groupId
                Group          = [string] $group.DisplayName
                MemberCount    = $memberCount
                Roles          = $legacyRoleNames
                ScopeTagId     = [string] $contextRows[0].ScopeTagId
                ScopeTag       = [string] $contextRows[0].ScopeTagName
                Resource       = [string] $contextRows[0].Resource
                OldPermissions = @($contextRows | Where-Object LegacyState -EQ 'Allowed' | ForEach-Object Operation | Sort-Object -Unique)
                NewPermissions = @($contextRows | Where-Object ScopedState -EQ 'Allowed' | ForEach-Object Operation | Sort-Object -Unique)
                LostPermissions = @($reductions | ForEach-Object Operation | Sort-Object -Unique)
                ModelState     = if ($unknown.Count) { 'NotEvaluated' } else { 'PermissionReduction' }
            })
        }
    }

    $reconciled = [System.Collections.Generic.List[object]]::new()
    $assessmentRows = @(Get-IntuneAccessProperty $Assessment 'Rows' @())
    $matchedAssessment = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($row in $modelRows) {
        $state = 'ModelOnly'
        $microsoftRow = $null
        if ($null -ne $Assessment) {
            for ($i = 0; $i -lt $assessmentRows.Count; $i++) {
                $candidate = $assessmentRows[$i]
                if ($candidate.Group -ieq $row.Group -and $candidate.ScopeTag -ieq $row.ScopeTag -and (ConvertTo-ResourceKey $candidate.Resource) -eq (ConvertTo-ResourceKey $row.Resource)) {
                    $microsoftRow = $candidate; $null = $matchedAssessment.Add($i); break
                }
            }
            if ($null -ne $microsoftRow) {
                $modelNew = @($row.NewPermissions | ForEach-Object { ConvertTo-OperationKey $_ } | Sort-Object -Unique) -join ','
                $reportNew = @($microsoftRow.NewPermissions | ForEach-Object { ConvertTo-OperationKey $_ } | Sort-Object -Unique) -join ','
                $state = if ($modelNew -eq $reportNew) { 'Agreed' } else { 'DifferentPermissions' }
            }
            elseif ($row.MemberCount -eq 0) { $state = 'ModelOnlyEmptyGroup' }
        }
        $row | Add-Member -NotePropertyName ReconciliationState -NotePropertyValue $state -Force
        $row | Add-Member -NotePropertyName MicrosoftReportRow -NotePropertyValue $microsoftRow -Force
        $reconciled.Add($row)
    }
    if ($null -ne $Assessment) {
        for ($i = 0; $i -lt $assessmentRows.Count; $i++) {
            if ($matchedAssessment.Contains($i)) { continue }
            $candidate = $assessmentRows[$i]
            $reconciled.Add([PSCustomObject] @{
                PSTypeName = 'IntuneAccess.ScopedReadinessRow'; GroupId = ''; Group = $candidate.Group; MemberCount = $null; Roles = $candidate.Roles
                ScopeTagId = ''; ScopeTag = $candidate.ScopeTag; Resource = $candidate.Resource
                OldPermissions = $candidate.OldPermissions; NewPermissions = $candidate.NewPermissions
                LostPermissions = @($candidate.OldPermissions | Where-Object { $_ -notin $candidate.NewPermissions })
                ModelState = 'NotModelled'; ReconciliationState = 'MicrosoftOnly'; MicrosoftReportRow = $candidate
            })
        }
    }

    $explanations = @{
        Agreed               = 'IntuneAccess and Microsoft agree on the permissions this group keeps for this scope tag.'
        DifferentPermissions = 'Both expect a reduction, but the remaining permissions differ. Check the role definitions and scope tags on each assignment.'
        ModelOnly            = 'IntuneAccess predicts a reduction that the imported Microsoft report does not list.'
        ModelOnlyEmptyGroup  = 'IntuneAccess predicts a reduction, but the group has no members, and Microsoft excludes empty groups from its report.'
        MicrosoftOnly        = 'Microsoft lists a reduction that IntuneAccess did not model. Nested groups, hidden membership or assignments not collected can cause this.'
    }
    foreach ($row in $reconciled) {
        $key = [string] $row.ReconciliationState
        $text = if ($null -eq $Assessment) { 'Predicted by IntuneAccess. Import the Permissions Assessment Report export to reconcile with Microsoft.' } elseif ($explanations.ContainsKey($key)) { $explanations[$key] } else { '' }
        $row | Add-Member -NotePropertyName Explanation -NotePropertyValue $text -Force
    }

    [PSCustomObject] @{
        PSTypeName          = 'IntuneAccess.ScopedReadiness'
        Rows                = @($reconciled | Sort-Object Group, ScopeTag, Resource)
        AffectedGroups      = @($reconciled | ForEach-Object Group | Sort-Object -Unique).Count
        AssessmentState     = if ($null -eq $Assessment) { 'NotImported' } else { [string] $Assessment.State }
        AssessmentPath      = if ($null -eq $Assessment) { '' } else { [string] $Assessment.Path }
        Agreed              = @($reconciled | Where-Object ReconciliationState -EQ 'Agreed').Count
        Disagreements       = @($reconciled | Where-Object ReconciliationState -In @('DifferentPermissions', 'ModelOnly', 'MicrosoftOnly')).Count
        EvidenceBoundary    = 'Microsoft states that enabling Scoped permissions cannot be reversed. IntuneAccess models the change from collected role assignments and never reads or changes the tenant setting. Use the Permissions Assessment Report in Tenant administration > Roles > Settings as the authoritative preview.'
    }
}
