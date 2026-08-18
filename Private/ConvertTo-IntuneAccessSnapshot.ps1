function Get-IntuneAccessSnapshotHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Value
    )

    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    ([Convert]::ToHexString($hash)).ToLowerInvariant()
}

function Copy-IntuneAccessSnapshotValue {
    [CmdletBinding()]
    [OutputType([object], [string], [object[]])]
    param(
        [AllowNull()] [object] $Value,
        [string] $PropertyName = '',
        [string] $RedactionKey = ''
    )

    if ($null -eq $Value) { return $null }

    if ($Value -is [string]) {
        if (-not [string]::IsNullOrWhiteSpace($RedactionKey) -and
            $PropertyName -match '(?i)(^id$|ids$|name$|displayname$|userprincipalname$|mail$|account$|serialnumber$|ipaddress$|oldvalue$|newvalue$|description$|tenant)') {
            $digest = Get-IntuneAccessSnapshotHash -Value "$RedactionKey`n$Value"
            return "redacted-$($digest.Substring(0, 16))"
        }
        return $Value
    }

    if ($Value -is [ValueType]) { return $Value }
    if ($Value -is [Collections.IDictionary]) {
        $copy = [ordered] @{}
        foreach ($key in $Value.Keys) {
            $copy[[string] $key] = Copy-IntuneAccessSnapshotValue -Value $Value[$key] -PropertyName ([string] $key) -RedactionKey $RedactionKey
        }
        return [PSCustomObject] $copy
    }
    if ($Value -is [Collections.IEnumerable]) {
        return @($Value | ForEach-Object { Copy-IntuneAccessSnapshotValue -Value $_ -PropertyName $PropertyName -RedactionKey $RedactionKey })
    }

    $copy = [ordered] @{}
    foreach ($property in $Value.PSObject.Properties | Where-Object MemberType -In @('NoteProperty', 'Property', 'AliasProperty', 'ScriptProperty')) {
        $copy[$property.Name] = Copy-IntuneAccessSnapshotValue -Value $property.Value -PropertyName $property.Name -RedactionKey $RedactionKey
    }
    [PSCustomObject] $copy
}

function ConvertTo-IntuneAccessSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $TenantRbac,
        [switch] $RedactIdentity
    )

    if ('IntuneAccess.TenantRbac' -notin $TenantRbac.PSObject.TypeNames) {
        throw 'InputObject must be an IntuneAccess tenant RBAC collection.'
    }

    $tenant = Get-IntuneAccessProperty $TenantRbac 'Tenant'
    $tenantId = [string] (Get-IntuneAccessProperty $tenant 'Id' (Get-IntuneAccessProperty $tenant 'DisplayName' 'IntuneAccess'))
    $redactionKey = if ($RedactIdentity) { Get-IntuneAccessSnapshotHash -Value "IntuneAccess`n$tenantId" } else { '' }
    $data = [ordered] @{}
    foreach ($collectionName in @(
        'Administrators', 'AdminGroups', 'RoleAssignments', 'RoleDefinitions', 'ScopeGroups', 'ScopeTags',
        'Permissions', 'Memberships', 'WorkloadObjects', 'WorkloadAssignments', 'WorkloadGroups',
        'AssignmentFilters', 'ManagedDevices', 'ManagedUsers', 'DeploymentOutcomes', 'PolicySettings', 'PolicyConflictFindings', 'AuditEvents'
    )) {
        $data[$collectionName] = @(Get-IntuneAccessProperty $TenantRbac $collectionName @())
    }
    $data['WorkloadCollectionStatus'] = @(Get-IntuneAccessProperty $TenantRbac 'WorkloadCollectionStatus' @())
    $data['OutcomeCollectionStatus'] = @(Get-IntuneAccessProperty $TenantRbac 'OutcomeCollectionStatus' @())

    $snapshotTenant = [PSCustomObject] [ordered] @{
        Id          = [string] (Get-IntuneAccessProperty $tenant 'Id' '')
        DisplayName = [string] (Get-IntuneAccessProperty $tenant 'DisplayName' '')
    }
    $snapshotData = [PSCustomObject] $data
    if ($RedactIdentity) {
        $snapshotTenant = Copy-IntuneAccessSnapshotValue -Value $snapshotTenant -RedactionKey $redactionKey
        $snapshotData = Copy-IntuneAccessSnapshotValue -Value $snapshotData -RedactionKey $redactionKey
    }

    $dataJson = $snapshotData | ConvertTo-Json -Depth 40 -Compress
    [PSCustomObject] [ordered] @{
        PSTypeName      = 'IntuneAccess.Snapshot'
        Schema          = 'https://controlaltdeletetechbits.github.io/intune-access/schemas/snapshot-1.0.json'
        SchemaVersion   = '1.0'
        ToolVersion     = $script:IntuneAccessVersion
        ExportedAt      = [DateTimeOffset]::Now
        Tenant          = $snapshotTenant
        IdentityMode    = if ($RedactIdentity) { 'Pseudonymised' } else { 'Full' }
        IntegritySha256 = Get-IntuneAccessSnapshotHash -Value $dataJson
        Data            = $snapshotData
    }
}
