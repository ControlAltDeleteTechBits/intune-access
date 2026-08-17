function Test-IntuneResourceAccess {
    <#
    .SYNOPSIS
    Explains a possible Intune RBAC access path to a managed device.
    .DESCRIPTION
    This command returns AccessPathFound only when permission, administrator-group,
    scope-group and scope-tag evidence can all be established. It never infers AccessDenied.
    .PARAMETER UserPrincipalName
    The administrator to examine.
    .PARAMETER UserId
    The administrator's Microsoft Entra object ID.
    .PARAMETER DeviceName
    Exact Intune managed-device display name.
    .PARAMETER RequiredAction
    Exact Graph action to test. Defaults to managed-device read.
    .EXAMPLE
    Test-IntuneResourceAccess -UserPrincipalName 'admin@contoso.com' -DeviceName 'PC-001'
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByUpn')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByUpn')] [ValidateNotNullOrEmpty()] [string] $UserPrincipalName,
        [Parameter(Mandatory, ParameterSetName = 'ById')] [guid] $UserId,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $DeviceName,
        [ValidateNotNullOrEmpty()] [string] $RequiredAction = 'Microsoft.Intune_ManagedDevices_Read'
    )

    $null = Assert-IntuneAccessConnection -RequiredScope @(
        'DeviceManagementManagedDevices.Read.All', 'Device.Read.All'
    )
    $escapedName = $DeviceName.Replace("'", "''")
    $filter = [uri]::EscapeDataString("deviceName eq '$escapedName'")
    $stableUri = "deviceManagement/managedDevices?`$filter=$filter&`$select=id,deviceName,azureADDeviceId,userId"
    $devices = @(Invoke-IntuneAccessGraphRequest -Uri $stableUri)
    if ($devices.Count -eq 0) {
        throw "No Intune managed device with the exact name '$DeviceName' was found."
    }
    if ($devices.Count -gt 1) {
        throw "Several Intune managed devices have the exact name '$DeviceName'. Use a unique name; no device was selected arbitrarily."
    }

    $device = $devices[0]
    $resourceWarnings = [System.Collections.Generic.List[string]]::new()
    $betaDevice = $null
    try {
        $betaUri = "deviceManagement/managedDevices?`$filter=$filter&`$select=id,roleScopeTagIds"
        $betaDevices = @(Invoke-IntuneAccessGraphRequest -Uri $betaUri -ApiVersion beta)
        $deviceId = [string] (Get-IntuneAccessProperty $device 'id')
        $betaDevice = $betaDevices | Where-Object {
            [string] (Get-IntuneAccessProperty $_ 'id') -eq $deviceId
        } | Select-Object -First 1
        if ($null -eq $betaDevice) {
            $resourceWarnings.Add("Beta scope-tag enrichment did not return managed device '$deviceId'. Device scope-tag matching is NotEvaluated.")
        }
    }
    catch {
        $resourceWarnings.Add("Beta scope-tag enrichment failed for managed device '$DeviceName'. Stable v1.0 device data is retained and scope-tag matching is NotEvaluated. $($_.Exception.Message)")
    }
    $azureDeviceId = [string] (Get-IntuneAccessProperty $device 'azureADDeviceId')
    $parsedDeviceId = [guid]::Empty
    $deviceMembership = if ([guid]::TryParse($azureDeviceId, [ref] $parsedDeviceId)) {
        Get-IntuneAccessDeviceMembership -EntraDeviceId $parsedDeviceId
    }
    else {
        [PSCustomObject] @{ State = 'NotEvaluated'; Device = $null; GroupIds = @(); Groups = @(); Explanation = 'The managed device did not return a usable Microsoft Entra device ID.' }
    }
    $managedUserId = [string] (Get-IntuneAccessProperty $device 'userId')
    $associatedUserMembership = Get-IntuneAccessManagedDeviceUserMembership -UserId $managedUserId

    $access = if ($PSCmdlet.ParameterSetName -eq 'ById') {
        Get-IntuneAdminAccess -UserId $UserId
    }
    else {
        Get-IntuneAdminAccess -UserPrincipalName $UserPrincipalName
    }
    $missingValue = [object]::new()
    $deviceTagValue = Get-IntuneAccessProperty $betaDevice 'roleScopeTagIds' $missingValue
    $deviceTagDataState = if ([object]::ReferenceEquals($deviceTagValue, $missingValue)) { 'Missing' } else { 'Available' }
    $deviceTagIds = @($(if ($deviceTagDataState -eq 'Missing') { @() } else { @($deviceTagValue) }))
    if ($deviceTagDataState -eq 'Available' -and $deviceTagIds.Count -eq 0) { $deviceTagIds = @('0') }

    $paths = [System.Collections.Generic.List[object]]::new()
    foreach ($assignment in $access.RoleAssignments) {
        $permissionMatch = $RequiredAction -in @($assignment.Permissions)
        $adminMatch = $assignment.Applicability -eq 'Confirmed'

        $scopeGroupState = 'NotEvaluated'
        $scopeMatchSource = 'None'
        $scopeMatchGroupIds = @()
        $scopeType = [string] $assignment.ScopeType
        if ((Get-IntuneAccessProperty $assignment 'ScopeTypeDataState' 'Available') -eq 'Missing') {
            $scopeGroupState = 'NotEvaluated'
        }
        elseif ($scopeType -in @('allDevices', 'allDevicesAndLicensedUsers')) {
            $scopeGroupState = 'Matched'
            $scopeMatchSource = 'VirtualAllDevices'
        }
        elseif ((Get-IntuneAccessProperty $assignment 'ScopeGroupDataState' 'Available') -eq 'Missing') {
            $scopeGroupState = 'NotEvaluated'
        }
        elseif ($scopeType -eq 'resourceScope') {
            $scopeGroupIds = @($assignment.RawIds.ScopeGroupIds)
            $deviceMatches = @($(if ($deviceMembership.State -eq 'Evaluated') {
                @($scopeGroupIds | Where-Object { $_ -in $deviceMembership.GroupIds })
            }
            else { @() }))
            $userMatches = @($(if ($associatedUserMembership.State -eq 'Evaluated') {
                @($scopeGroupIds | Where-Object { $_ -in $associatedUserMembership.GroupIds })
            }
            else { @() }))

            if ($deviceMatches.Count -gt 0) {
                $scopeGroupState = 'Matched'
                $scopeMatchSource = 'DeviceGroup'
                $scopeMatchGroupIds = $deviceMatches
            }
            elseif ($userMatches.Count -gt 0) {
                $scopeGroupState = 'Matched'
                $scopeMatchSource = 'AssociatedUserGroup'
                $scopeMatchGroupIds = $userMatches
            }
            elseif ($deviceMembership.State -eq 'Evaluated' -and
                $associatedUserMembership.State -in @('Evaluated', 'NotApplicable')) {
                $scopeGroupState = 'NotMatched'
            }
            else {
                $scopeGroupState = 'NotEvaluated'
            }
        }

        $assignmentTagIds = @($assignment.RawIds.ScopeTagIds)
        $scopeTagState = if ((Get-IntuneAccessProperty $assignment 'ScopeTagDataState' 'Available') -eq 'Missing') {
            'NotEvaluated'
        }
        elseif ($assignmentTagIds.Count -eq 0) {
            'MatchedAllTags'
        }
        elseif ($deviceTagDataState -eq 'Missing') {
            'NotEvaluated'
        }
        elseif (@($assignmentTagIds | Where-Object { $_ -in $deviceTagIds }).Count -gt 0) {
            'Matched'
        }
        else {
            'NotMatched'
        }

        $pathState = if ($permissionMatch -and $adminMatch -and $scopeGroupState -eq 'Matched' -and $scopeTagState -in @('Matched', 'MatchedAllTags')) {
            'AccessPathFound'
        }
        else {
            'NotEvaluated'
        }
        $paths.Add([PSCustomObject] @{
            State                = $pathState
            RoleDefinition       = $assignment.RoleDefinition.DisplayName
            RoleAssignment       = $assignment.Name
            AdminGroups          = @($assignment.AdminGroupEvidence)
            Permission           = $RequiredAction
            PermissionMatch      = $permissionMatch
            AdminMembershipState = $assignment.Applicability
            ScopeGroupState      = $scopeGroupState
            ScopeMatchSource     = $scopeMatchSource
            ScopeMatchGroupIds   = $scopeMatchGroupIds
            ScopeGroups          = @($assignment.ScopeGroups)
            ScopeTagState        = $scopeTagState
            ScopeTags            = @($assignment.ScopeTags)
        })
    }

    $found = @($paths | Where-Object State -EQ 'AccessPathFound')
    [PSCustomObject] @{
        PSTypeName      = 'IntuneAccess.ResourceAccessExplanation'
        Experimental    = $true
        Administrator   = $access.User
        Resource        = [PSCustomObject] @{
            Id          = [string] (Get-IntuneAccessProperty $device 'id')
            Name        = [string] (Get-IntuneAccessProperty $device 'deviceName')
            Type        = 'Managed device'
            EntraDeviceId = $azureDeviceId
            AssociatedUserId = if ([string]::IsNullOrWhiteSpace($managedUserId)) { $null } else { $managedUserId }
            ScopeTagIds = $deviceTagIds
            ScopeTagDataState = $deviceTagDataState
            PropertySource = [PSCustomObject] @{
                IdentityAndRelationships = 'v1.0'
                ScopeTags = if ($deviceTagDataState -eq 'Available') { 'beta' } else { 'Missing' }
            }
        }
        RequiredAction  = $RequiredAction
        Result          = if ($found.Count -gt 0) { 'AccessPathFound' } else { 'NotEvaluated' }
        Reason          = if ($found.Count -gt 0) {
            "$($found.Count) complete Intune RBAC access path(s) were observed."
        }
        else {
            'No complete path could be proved. This is not an access-denied decision; Microsoft Entra roles and unsupported scope cases are not evaluated.'
        }
        AccessPaths     = $paths.ToArray()
        Evidence        = @($found)
        ResourceScopeEvidence = [PSCustomObject] @{
            DeviceMembershipState = $deviceMembership.State
            DeviceGroupIds        = @($deviceMembership.GroupIds)
            AssociatedUserMembershipState = $associatedUserMembership.State
            AssociatedUserGroupIds = @($associatedUserMembership.GroupIds)
        }
        Warnings        = @($access.Warnings) + $resourceWarnings.ToArray()
        GeneratedAt     = [DateTimeOffset]::Now
        ToolVersion     = $script:IntuneAccessVersion
    }
}
