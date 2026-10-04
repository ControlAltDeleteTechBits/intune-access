# Synthetic Microsoft Graph responses for the IntuneAccess demonstration report.
# Every tenant, person, group, device, policy and result in this file is fictional.
# Nothing here contacts Microsoft Graph or any other network service.

Set-StrictMode -Version Latest

function New-IntuneAccessDemoTenant {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = 'Compact local fixture builders keep the synthetic tenant readable.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Anchor', Justification = 'Used by the nested Fixed helper.')]
    [CmdletBinding()]
    param(
        [DateTimeOffset] $AsOf = [DateTimeOffset]::UtcNow,
        # Anchor for timestamps that do not move between collections, such as enrolment dates.
        [DateTimeOffset] $Anchor = $AsOf
    )

    # Iso: evidence that refreshes with each collection. Fixed: configuration history.
    function Iso([double] $daysAgo) { $AsOf.AddDays(-$daysAgo).ToString('yyyy-MM-ddTHH:mm:ssZ') }
    function Fixed([double] $daysAgo) { $Anchor.AddDays(-$daysAgo).ToString('yyyy-MM-ddTHH:mm:ssZ') }
    function Id([string] $prefix, [int] $n) { '{0}-0000-4000-8000-{1:D12}' -f $prefix, $n }

    $domain = 'contoso.example'

    # People
    $users = @(
        [pscustomobject]@{ id = Id 'aa000001' 1; displayName = 'Priya Shah';      userPrincipalName = "priya.shah@$domain";      accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 2; displayName = 'Tom Hughes';      userPrincipalName = "tom.hughes@$domain";      accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 3; displayName = 'Grace Okafor';    userPrincipalName = "grace.okafor@$domain";    accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 4; displayName = 'Daniel Murphy';   userPrincipalName = "daniel.murphy@$domain";   accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 5; displayName = 'Sofia Rossi';     userPrincipalName = "sofia.rossi@$domain";     accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 6; displayName = 'Liam Patel';      userPrincipalName = "liam.patel@$domain";      accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 7; displayName = 'Emma Clarke';     userPrincipalName = "emma.clarke@$domain";     accountEnabled = $true; userType = 'Member' }
        [pscustomobject]@{ id = Id 'aa000001' 8; displayName = 'Noah Williams';   userPrincipalName = "noah.williams@$domain";   accountEnabled = $true; userType = 'Member' }
    )
    $u = @{}; foreach ($x in $users) { $u[$x.displayName.Split(' ')[0]] = $x }

    # Groups
    $groups = @(
        [pscustomobject]@{ id = Id 'bb000002' 1; displayName = 'Intune Helpdesk UK';         description = 'First-line support, UK';            securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 2; displayName = 'Intune Endpoint Engineers';  description = 'Policy and configuration owners';   securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 3; displayName = 'Intune App Packagers';       description = 'Application packaging team';        securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 4; displayName = 'Intune Helpdesk US';         description = 'First-line support, US';            securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 5; displayName = 'Contractors - Service Desk'; description = 'Nested inside Intune Helpdesk US';  securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 10; displayName = 'UK Corporate Devices';      description = 'Scope group for UK devices';        securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 11; displayName = 'US Corporate Devices';      description = 'Scope group for US devices';        securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 12; displayName = 'Windows Pilot Ring';        description = 'Early adopters for policy changes'; securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 13; displayName = 'All Corporate Laptops';     description = 'Dynamic device group';              securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 14; displayName = 'Finance Users';             description = 'Finance department';                securityEnabled = $true }
        [pscustomobject]@{ id = Id 'bb000002' 15; displayName = 'Kiosk Devices';             description = 'Excluded from user-focused policy'; securityEnabled = $true }
    )
    $g = @{}; foreach ($x in $groups) { $g[$x.displayName] = $x }

    # Direct user membership of groups. Daniel is only a nested member through Contractors.
    $groupMembers = @{
        $g['Intune Helpdesk UK'].id         = @($u['Priya'], $u['Tom'])
        $g['Intune Endpoint Engineers'].id  = @($u['Grace'])
        $g['Intune App Packagers'].id       = @($u['Sofia'], $u['Grace'])
        $g['Intune Helpdesk US'].id         = @($u['Liam'])
        $g['Contractors - Service Desk'].id = @($u['Daniel'])
        $g['Finance Users'].id              = @($u['Emma'], $u['Noah'])
    }
    $nestedGroups = @{ $g['Intune Helpdesk US'].id = @($g['Contractors - Service Desk'].id) }

    # Scope tags
    $tags = @(
        [pscustomobject]@{ id = '0'; displayName = 'Default'; description = 'Built-in default scope tag'; isBuiltIn = $true }
        [pscustomobject]@{ id = '1'; displayName = 'UK';      description = 'United Kingdom objects';     isBuiltIn = $false }
        [pscustomobject]@{ id = '2'; displayName = 'US';      description = 'United States objects';      isBuiltIn = $false }
        [pscustomobject]@{ id = '3'; displayName = 'Finance'; description = 'Finance department objects'; isBuiltIn = $false }
        [pscustomobject]@{ id = '4'; displayName = 'Retail'; description = 'Retail stores (no role assignment uses this tag)'; isBuiltIn = $false }
    )

    # Role definitions
    function RoleDef($n, $name, [bool] $builtIn, [string[]] $actions, $desc) {
        [pscustomobject]@{ id = Id 'cc000003' $n; displayName = $name; description = $desc; isBuiltIn = $builtIn
            rolePermissions = @([pscustomobject]@{ resourceActions = @([pscustomobject]@{ allowedResourceActions = $actions; notAllowedResourceActions = @() }) }) }
    }
    $roles = @(
        RoleDef 1 'Help Desk Operator' $true @('Microsoft.Intune_ManagedDevices_Read','Microsoft.Intune_ManagedDevices_RemoteLock','Microsoft.Intune_ManagedDevices_SyncDevice','Microsoft.Intune_ManagedDevices_RebootNow','Microsoft.Intune_MobileApps_Read','Microsoft.Intune_DeviceConfigurations_Read') 'Built-in helpdesk role'
        RoleDef 2 'Application Manager' $true @('Microsoft.Intune_MobileApps_Read','Microsoft.Intune_MobileApps_Create','Microsoft.Intune_MobileApps_Update','Microsoft.Intune_MobileApps_Assign','Microsoft.Intune_ManagedDevices_Read') 'Built-in application role'
        RoleDef 3 'Endpoint Policy Engineer' $false @('Microsoft.Intune_DeviceConfigurations_Read','Microsoft.Intune_DeviceConfigurations_Create','Microsoft.Intune_DeviceConfigurations_Update','Microsoft.Intune_DeviceConfigurations_Assign','Microsoft.Intune_DeviceCompliancePolices_Read','Microsoft.Intune_DeviceCompliancePolices_Update','Microsoft.Intune_ManagedDevices_Read','Microsoft.Intune_ManagedDevices_Wipe') 'Custom role for policy owners'
        RoleDef 4 'Read Only Operator' $true @('Microsoft.Intune_ManagedDevices_Read','Microsoft.Intune_MobileApps_Read','Microsoft.Intune_DeviceConfigurations_Read','Microsoft.Intune_DeviceCompliancePolices_Read') 'Built-in read-only role'
    )
    $r = @{}; foreach ($x in $roles) { $r[$x.displayName] = $x }

    function RoleAssign($n, $name, $role, [string[]] $members, [string[]] $scopes, [string[]] $tagIds, $scopeType = 'resourceScope') {
        [pscustomobject]@{ id = Id 'dd000004' $n; displayName = $name; description = "$name assignment"; members = $members; resourceScopes = $scopes; scopeMembers = $scopes; roleScopeTagIds = $tagIds; scopeType = $scopeType; RoleId = $role.id }
    }
    $roleAssignments = @(
        RoleAssign 1 'UK Helpdesk' $r['Help Desk Operator'] @($g['Intune Helpdesk UK'].id) @($g['UK Corporate Devices'].id) @('1')
        RoleAssign 2 'US Helpdesk' $r['Help Desk Operator'] @($g['Intune Helpdesk US'].id) @($g['US Corporate Devices'].id) @('2')
        RoleAssign 3 'Global Policy Engineering' $r['Endpoint Policy Engineer'] @($g['Intune Endpoint Engineers'].id) @() @() 'allDevicesAndLicensedUsers'
        RoleAssign 4 'App Packaging UK' $r['Application Manager'] @($g['Intune App Packagers'].id) @($g['UK Corporate Devices'].id) @('1')
        RoleAssign 5 'Finance Read Only' $r['Read Only Operator'] @($g['Intune App Packagers'].id) @($g['UK Corporate Devices'].id) @('3')
    )

    # Assignment filters
    $filters = @(
        [pscustomobject]@{ id = Id 'ee000005' 1; displayName = 'Corporate Windows only'; platform = 'windows10AndLater'; rule = '(device.deviceOwnership -eq "Corporate")'; description = 'Excludes personal devices' }
        [pscustomobject]@{ id = Id 'ee000005' 2; displayName = 'Windows 11 only';        platform = 'windows10AndLater'; rule = '(device.osVersion -startsWith "10.0.2")'; description = 'Windows 11 builds' }
    )

    # Devices
    function Dev($n, $name, $user, $os, $osv, $comp, [double] $syncDays, $serial, $model, $owner = 'company', $enrol = 'windowsAzureADJoin') {
        [pscustomobject]@{ id = Id 'ff000006' $n; deviceName = $name; userId = $(if ($user) { $user.id } else { '' }); userPrincipalName = $(if ($user) { $user.userPrincipalName } else { '' }); userDisplayName = $(if ($user) { $user.displayName } else { '' })
            azureADDeviceId = Id 'ab000007' $n; operatingSystem = $os; osVersion = $osv; complianceState = $comp; managementAgent = 'mdm'; deviceEnrollmentType = $enrol
            lastSyncDateTime = (Iso $syncDays); model = $model; manufacturer = 'Contoso Hardware'; serialNumber = $serial; managedDeviceOwnerType = $owner; deviceRegistrationState = 'registered'
            enrolledDateTime = (Fixed 210); isEncrypted = $true; jailBroken = 'Unknown'; deviceCategoryDisplayName = 'Laptop'; totalStorageSpaceInBytes = 256GB; freeStorageSpaceInBytes = 48GB
            imei = ''; meid = ''; wiFiMacAddress = ''; ethernetMacAddress = ''; phoneNumber = ''; subscriberCarrier = ''; roleScopeTagIds = @('1') }
    }
    $devices = @(
        Dev 1 'UK-LT-0101' $u['Emma']  'Windows' '10.0.26100.2033' 'compliant'    0.2 'CTS-0101' 'ProBook 14'
        Dev 2 'UK-LT-0102' $u['Noah']  'Windows' '10.0.26100.2033' 'noncompliant' 0.5 'CTS-0102' 'ProBook 14'
        Dev 3 'UK-LT-0103' $u['Priya'] 'Windows' '10.0.22631.4317' 'compliant'    1.0 'CTS-0103' 'EliteBook 840'
        Dev 4 'UK-LT-0104' $u['Tom']   'Windows' '10.0.26100.1742' 'compliant'    2.0 'CTS-0104' 'EliteBook 840'
        Dev 5 'UK-LT-0105' $null       'Windows' '10.0.26100.2033' 'unknown'      41  'CTS-0105' 'ProBook 14'
        Dev 6 'US-LT-0201' $u['Liam']  'Windows' '10.0.26100.2033' 'compliant'    0.3 'CTS-0201' 'Latitude 7450'
        Dev 7 'US-LT-0202' $u['Daniel'] 'Windows' '10.0.22631.4317' 'noncompliant' 3.0 'CTS-0202' 'Latitude 7450'
        Dev 8 'UK-KIOSK-01' $null      'Windows' '10.0.26100.2033' 'compliant'    0.8 'CTS-0201' 'Kiosk Mini'
    )
    foreach ($d in $devices) { if ($d.deviceName -like 'US-*') { $d.roleScopeTagIds = @('2') } }
    $dv = @{}; foreach ($x in $devices) { $dv[$x.deviceName] = $x }

    $entraDevices = @($devices | ForEach-Object {
        [pscustomobject]@{ id = ($_.azureADDeviceId -replace '^ab000007', 'ac000008'); deviceId = $_.azureADDeviceId; displayName = $_.deviceName; accountEnabled = $true; operatingSystem = 'Windows'; operatingSystemVersion = $_.osVersion; trustType = 'AzureAd'; approximateLastSignInDateTime = $_.lastSyncDateTime; registrationDateTime = (Fixed 210) }
    })
    # Device group membership
    $deviceGroups = @{}
    foreach ($d in $devices) {
        $list = [System.Collections.Generic.List[object]]::new()
        if ($d.deviceName -like 'UK-*') { $list.Add($g['UK Corporate Devices']) }
        if ($d.deviceName -like 'US-*') { $list.Add($g['US Corporate Devices']) }
        if ($d.deviceName -like '*-LT-*') { $list.Add($g['All Corporate Laptops']) }
        if ($d.deviceName -in @('UK-LT-0102', 'UK-LT-0103')) { $list.Add($g['Windows Pilot Ring']) }
        if ($d.deviceName -like '*KIOSK*') { $list.Add($g['Kiosk Devices']) }
        $deviceGroups[$d.azureADDeviceId] = $list.ToArray()
    }

    # Workloads and their assignments
    function Target($type, $groupId = '', $filterId = '', $filterType = 'none') {
        $t = [ordered]@{ '@odata.type' = "#microsoft.graph.$type" }
        if ($groupId) { $t.groupId = $groupId }
        if ($filterId) { $t.deviceAndAppManagementAssignmentFilterId = $filterId; $t.deviceAndAppManagementAssignmentFilterType = $filterType }
        [pscustomobject]$t
    }
    function Assign($n, $target, $intent = '') { $a = [ordered]@{ id = Id 'ba000009' $n; target = $target }; if ($intent) { $a.intent = $intent }; [pscustomobject]$a }

    $deviceConfigurations = @(
        [pscustomobject]@{ id = Id 'ca000010' 1; displayName = 'Windows - Legacy Wi-Fi profile'; '@odata.type' = '#microsoft.graph.windows81WifiImportConfiguration'; roleScopeTagIds = @('0'); supportsScopeTags = $true; lastModifiedDateTime = (Fixed 3) }
    )
    $configurationPolicies = @(
        [pscustomobject]@{ id = Id 'ca000011' 1; name = 'Windows - Edge security baseline'; description = 'Production Edge settings'; platforms = 'windows10'; technologies = 'mdm'; roleScopeTagIds = @('0'); templateReference = $null; lastModifiedDateTime = (Fixed 2) }
        [pscustomobject]@{ id = Id 'ca000011' 2; name = 'Windows - Edge user experience';  description = 'Edge usability settings'; platforms = 'windows10'; technologies = 'mdm'; roleScopeTagIds = @('1'); templateReference = $null; lastModifiedDateTime = (Fixed 1) }
        [pscustomobject]@{ id = Id 'ca000011' 3; name = 'Windows - BitLocker';              description = 'Disk encryption';        platforms = 'windows10'; technologies = 'mdm'; roleScopeTagIds = @('0'); templateReference = $null; lastModifiedDateTime = (Fixed 30) }
        [pscustomobject]@{ id = Id 'ca000011' 4; name = 'Finance - USB restrictions';       description = 'Not assigned yet';       platforms = 'windows10'; technologies = 'mdm'; roleScopeTagIds = @('3'); templateReference = $null; lastModifiedDateTime = (Fixed 12) }
    )
    $compliancePolicies = @(
        [pscustomobject]@{ id = Id 'ca000012' 1; displayName = 'Windows - Corporate compliance'; '@odata.type' = '#microsoft.graph.windows10CompliancePolicy'; roleScopeTagIds = @('0'); lastModifiedDateTime = (Fixed 20) }
    )
    $mobileApps = @(
        [pscustomobject]@{ id = Id 'ca000013' 1; displayName = 'Contoso VPN Client'; publisher = 'Contoso'; '@odata.type' = '#microsoft.graph.win32LobApp'; roleScopeTagIds = @('0'); displayVersion = '5.2.1'; isAssigned = $true
            installExperience = [pscustomobject]@{ runAsAccount = 'system' }
            rules = @([pscustomobject]@{ '@odata.type' = '#microsoft.graph.win32LobAppRegistryRule'; ruleType = 'detection'; keyPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Contoso\VPN'; valueName = 'Version'; operationType = 'version'; operator = 'greaterThanOrEqual'; comparisonValue = '5.2.1'; check32BitOn64System = $false }) }
        [pscustomobject]@{ id = Id 'ca000013' 2; displayName = 'Finance Reporting Add-in'; publisher = 'Contoso'; '@odata.type' = '#microsoft.graph.win32LobApp'; roleScopeTagIds = @('3'); displayVersion = '2.0.0'; isAssigned = $true
            installExperience = [pscustomobject]@{ runAsAccount = 'user' }
            rules = @([pscustomobject]@{ '@odata.type' = '#microsoft.graph.win32LobAppFileSystemRule'; ruleType = 'detection'; path = '%LOCALAPPDATA%\Contoso\Finance'; fileOrFolderName = 'addin.dll'; operationType = 'exists'; operator = 'notConfigured'; comparisonValue = $null; check32BitOn64System = $false }) }
        [pscustomobject]@{ id = Id 'ca000013' 3; displayName = 'Company Portal'; publisher = 'Microsoft Corporation'; '@odata.type' = '#microsoft.graph.winGetApp'; roleScopeTagIds = @('0'); isAssigned = $true }
    )
    $scripts = @(
        [pscustomobject]@{ id = Id 'ca000014' 1; displayName = 'Set regional time zone'; description = 'Runs once at enrolment'; runAsAccount = 'system'; roleScopeTagIds = @('4') }
    )
    $healthScripts = @(
        [pscustomobject]@{ id = Id 'ca000015' 1; displayName = 'Detect low system disk space'; description = 'Detection only'; publisher = 'Contoso'; deviceHealthScriptType = 'deviceHealthScript'; roleScopeTagIds = @('0') }
    )
    $featureUpdates = @(
        [pscustomobject]@{ id = Id 'ca000016' 1; displayName = 'Windows 11 24H2 - Pilot ring'; featureUpdateVersion = 'Windows 11, version 24H2'; roleScopeTagIds = @('0') }
    )

    $assignments = @{
        $deviceConfigurations[0].id  = @( Assign 1 (Target 'groupAssignmentTarget' $g['All Corporate Laptops'].id) )
        $configurationPolicies[0].id = @( Assign 2 (Target 'groupAssignmentTarget' $g['All Corporate Laptops'].id); Assign 3 (Target 'exclusionGroupAssignmentTarget' $g['Kiosk Devices'].id) )
        $configurationPolicies[1].id = @( Assign 4 (Target 'groupAssignmentTarget' $g['All Corporate Laptops'].id) )
        $configurationPolicies[2].id = @( Assign 5 (Target 'allDevicesAssignmentTarget' '' $filters[1].id 'include') )
        $configurationPolicies[3].id = @()
        $compliancePolicies[0].id    = @( Assign 6 (Target 'allDevicesAssignmentTarget' '' $filters[0].id 'include'); Assign 7 (Target 'exclusionGroupAssignmentTarget' $g['Kiosk Devices'].id) )
        $mobileApps[0].id            = @( Assign 8 (Target 'groupAssignmentTarget' $g['All Corporate Laptops'].id) 'required' )
        $mobileApps[1].id            = @( Assign 9 (Target 'groupAssignmentTarget' $g['Finance Users'].id) 'required' )
        $mobileApps[2].id            = @( Assign 10 (Target 'allLicensedUsersAssignmentTarget') 'available' )
        $scripts[0].id               = @( Assign 11 (Target 'groupAssignmentTarget' $g['All Corporate Laptops'].id); Assign 14 (Target 'groupAssignmentTarget' (Id 'bb000002' 99)) )
        $healthScripts[0].id         = @( Assign 12 (Target 'allDevicesAssignmentTarget') )
        $featureUpdates[0].id        = @( Assign 13 (Target 'groupAssignmentTarget' $g['Windows Pilot Ring'].id) )
    }

    # Settings Catalog values. Two Edge policies on the same group disagree on one definition.
    function Choice($def, $value) { [pscustomobject]@{ id = "$def-instance"; settingInstance = [pscustomobject]@{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance'; settingDefinitionId = $def; choiceSettingValue = [pscustomobject]@{ value = "${def}_$value"; children = @() } } } }
    $policySettings = @{
        $configurationPolicies[0].id = @( Choice 'device_vendor_msft_policy_config_microsoft_edgev80diff~policy~microsoft_edge_smartscreenenabled' '1'; Choice 'device_vendor_msft_policy_config_microsoft_edge~policy~microsoft_edge_passwordmanagerenabled' '0' )
        $configurationPolicies[1].id = @( Choice 'device_vendor_msft_policy_config_microsoft_edge~policy~microsoft_edge_passwordmanagerenabled' '1' )
        $configurationPolicies[2].id = @( Choice 'device_vendor_msft_bitlocker_requiredeviceencryption' '1' )
        $configurationPolicies[3].id = @( Choice 'device_vendor_msft_policy_config_storage_removablediskdenywriteaccess' '1' )
    }

    # Reported outcomes
    $statuses = @{
        $deviceConfigurations[0].id = @(
            [pscustomobject]@{ id = 's1'; deviceId = $dv['UK-LT-0101'].id; deviceDisplayName = 'UK-LT-0101'; userPrincipalName = $u['Emma'].userPrincipalName; status = 'succeeded'; lastReportedDateTime = (Iso 0.2) }
            [pscustomobject]@{ id = 's2'; deviceId = $dv['UK-LT-0102'].id; deviceDisplayName = 'UK-LT-0102'; userPrincipalName = $u['Noah'].userPrincipalName; status = 'error'; lastReportedDateTime = (Iso 0.5) }
            [pscustomobject]@{ id = 's3'; deviceId = $dv['UK-LT-0103'].id; deviceDisplayName = 'UK-LT-0103'; userPrincipalName = $u['Priya'].userPrincipalName; status = 'conflict'; lastReportedDateTime = (Iso 1) }
        )
        $compliancePolicies[0].id = @(
            [pscustomobject]@{ id = 'c1'; deviceId = $dv['UK-LT-0101'].id; deviceDisplayName = 'UK-LT-0101'; userPrincipalName = $u['Emma'].userPrincipalName; status = 'compliant'; lastReportedDateTime = (Iso 0.2) }
            [pscustomobject]@{ id = 'c2'; deviceId = $dv['UK-LT-0102'].id; deviceDisplayName = 'UK-LT-0102'; userPrincipalName = $u['Noah'].userPrincipalName; status = 'nonCompliant'; lastReportedDateTime = (Iso 0.5) }
            [pscustomobject]@{ id = 'c3'; deviceId = $dv['US-LT-0202'].id; deviceDisplayName = 'US-LT-0202'; userPrincipalName = $u['Daniel'].userPrincipalName; status = 'nonCompliant'; lastReportedDateTime = (Iso 3) }
        )
        $mobileApps[0].id = @(
            [pscustomobject]@{ id = 'a1'; deviceId = $dv['UK-LT-0101'].id; deviceName = 'UK-LT-0101'; userPrincipalName = $u['Emma'].userPrincipalName; installState = 'installed'; installStateDetail = 'noAdditionalDetails'; errorCode = 0; lastSyncDateTime = (Iso 0.2) }
            [pscustomobject]@{ id = 'a2'; deviceId = $dv['UK-LT-0102'].id; deviceName = 'UK-LT-0102'; userPrincipalName = $u['Noah'].userPrincipalName; installState = 'failed'; installStateDetail = 'appNotDetectedAfterInstall'; errorCode = -2016345060; lastSyncDateTime = (Iso 0.5) }
            [pscustomobject]@{ id = 'a3'; deviceId = $dv['US-LT-0201'].id; deviceName = 'US-LT-0201'; userPrincipalName = $u['Liam'].userPrincipalName; installState = 'failed'; installStateDetail = 'appNotDetectedAfterInstall'; errorCode = -2016345060; lastSyncDateTime = (Iso 0.3) }
            [pscustomobject]@{ id = 'a4'; deviceId = $dv['UK-LT-0104'].id; deviceName = 'UK-LT-0104'; userPrincipalName = $u['Tom'].userPrincipalName; installState = 'installed'; installStateDetail = 'noAdditionalDetails'; errorCode = 0; lastSyncDateTime = (Iso 2) }
        )
        $mobileApps[1].id = @(
            [pscustomobject]@{ id = 'a5'; deviceId = $dv['UK-LT-0101'].id; deviceName = 'UK-LT-0101'; userPrincipalName = $u['Emma'].userPrincipalName; installState = 'failed'; installStateDetail = 'installingDependencies'; errorCode = -2147023293; lastSyncDateTime = (Iso 0.2) }
        )
    }
    $runStates = @{
        $scripts[0].id = @(
            [pscustomobject]@{ id = 'r1'; runState = 'success'; resultMessage = 'Time zone set'; errorCode = 0; lastStateUpdateDateTime = (Iso 30); managedDevice = [pscustomobject]@{ id = $dv['UK-LT-0101'].id; deviceName = 'UK-LT-0101'; userPrincipalName = $u['Emma'].userPrincipalName } }
            [pscustomobject]@{ id = 'r2'; runState = 'fail'; resultMessage = 'Location services disabled'; errorCode = 1; lastStateUpdateDateTime = (Iso 9); managedDevice = [pscustomobject]@{ id = $dv['US-LT-0202'].id; deviceName = 'US-LT-0202'; userPrincipalName = $u['Daniel'].userPrincipalName } }
        )
        $healthScripts[0].id = @(
            [pscustomobject]@{ id = 'h1'; detectionState = 'fail'; remediationState = 'skipped'; preRemediationDetectionScriptError = ''; remediationScriptError = ''; lastStateUpdateDateTime = (Iso 0.5); managedDevice = [pscustomobject]@{ id = $dv['UK-LT-0102'].id; deviceName = 'UK-LT-0102'; userPrincipalName = $u['Noah'].userPrincipalName } }
            [pscustomobject]@{ id = 'h2'; detectionState = 'success'; remediationState = 'notRun'; lastStateUpdateDateTime = (Iso 0.2); managedDevice = [pscustomobject]@{ id = $dv['UK-LT-0101'].id; deviceName = 'UK-LT-0101'; userPrincipalName = $u['Emma'].userPrincipalName } }
        )
    }

    # Detected software
    $detectedApps = @(
        [pscustomobject]@{ id = 'da1'; displayName = 'Contoso VPN Client'; version = '5.2.1'; publisher = 'Contoso'; platform = 'windows'; sizeInByte = 52428800; deviceCount = 3 }
        [pscustomobject]@{ id = 'da2'; displayName = 'Contoso VPN Client'; version = '5.1.0'; publisher = 'Contoso'; platform = 'windows'; sizeInByte = 50331648; deviceCount = 2 }
        [pscustomobject]@{ id = 'da3'; displayName = 'Microsoft Edge'; version = '129.0.2792.79'; publisher = 'Microsoft Corporation'; platform = 'windows'; sizeInByte = 734003200; deviceCount = 8 }
    )
    $detectedLinks = @{
        da1 = @($dv['UK-LT-0101'], $dv['UK-LT-0104'], $dv['US-LT-0202'])
        da2 = @($dv['UK-LT-0102'], $dv['US-LT-0201'])
        da3 = $devices
    }

    # Recent Intune audit events
    function Audit($n, [double] $daysAgo, $actor, $activity, $type, $resourceId, $resourceName, $resourceType, $prop, $old, $new) {
        [pscustomobject]@{ id = Id 'ad000017' $n; displayName = $activity; componentName = $(if ($resourceType -eq 'MobileApp') { 'Application' } else { 'DeviceConfiguration' }); activity = $activity; activityDateTime = (Fixed $daysAgo); activityType = $type; activityOperationType = 'Patch'; activityResult = 'Success'; correlationId = [guid]::Empty.Guid; category = $(if ($resourceType -eq 'MobileApp') { 'Application' } else { 'DeviceConfiguration' })
            actor = [pscustomobject]@{ type = 'ItPro'; userPrincipalName = $actor.userPrincipalName; userId = $actor.id; applicationDisplayName = 'Microsoft Intune portal extension'; ipAddress = '' }
            resources = @([pscustomobject]@{ resourceId = $resourceId; displayName = $resourceName; type = $resourceType; auditResourceType = $resourceType; modifiedProperties = @([pscustomobject]@{ displayName = $prop; oldValue = $old; newValue = $new }) }) }
    }
    $auditEvents = @(
        Audit 1 1.1 $u['Grace'] 'Patch DeviceManagementConfigurationPolicy' 'Patch DeviceManagementConfigurationPolicy' $configurationPolicies[1].id 'Windows - Edge user experience' 'DeviceManagementConfigurationPolicy' 'PasswordManagerEnabled' '0' '1'
        Audit 2 2.2 $u['Grace'] 'Patch DeviceManagementConfigurationPolicy' 'Patch DeviceManagementConfigurationPolicy' $configurationPolicies[0].id 'Windows - Edge security baseline' 'DeviceManagementConfigurationPolicy' 'Assignments' 'All Corporate Laptops' 'All Corporate Laptops; exclude Kiosk Devices'
        Audit 3 0.9 $u['Sofia'] 'Patch MobileApp' 'Patch MobileApp' $mobileApps[0].id 'Contoso VPN Client' 'MobileApp' 'DetectionRules' 'Version >= 5.1.0' 'Version >= 5.2.1'
        Audit 4 6.0 $u['Grace'] 'Create DeviceManagementConfigurationPolicy' 'Create DeviceManagementConfigurationPolicy' $configurationPolicies[3].id 'Finance - USB restrictions' 'DeviceManagementConfigurationPolicy' 'Name' '' 'Finance - USB restrictions'
    )

    [pscustomobject]@{
        AsOf = $AsOf; Domain = $domain
        Organization = [pscustomobject]@{ id = '00000000-0000-4000-8000-0000000c0de0'; displayName = 'Contoso Demo (synthetic)'; verifiedDomains = @([pscustomobject]@{ name = $domain; isDefault = $true }) }
        SignedInUser = $u['Grace']
        Users = $users; Groups = $groups; GroupMembers = $groupMembers; NestedGroups = $nestedGroups; ScopeTags = $tags
        RoleDefinitions = $roles; RoleAssignments = $roleAssignments; AssignmentFilters = $filters
        ManagedDevices = $devices; EntraDevices = $entraDevices; DeviceGroups = $deviceGroups
        DeviceConfigurations = $deviceConfigurations; ConfigurationPolicies = $configurationPolicies; CompliancePolicies = $compliancePolicies
        MobileApps = $mobileApps; Scripts = $scripts; HealthScripts = $healthScripts; FeatureUpdates = $featureUpdates
        Assignments = $assignments; PolicySettings = $policySettings; Statuses = $statuses; RunStates = $runStates
        DetectedApps = $detectedApps; DetectedLinks = $detectedLinks; AuditEvents = $auditEvents
    }
}

function Get-IntuneAccessDemoResponse {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object] $Tenant, [Parameter(Mandatory)] [string] $Uri)

    $path = $Uri -replace '^https://graph\.microsoft\.com/(v1\.0|beta)/', ''
    $query = ''
    if ($path.Contains('?')) { $query = [uri]::UnescapeDataString($path.Substring($path.IndexOf('?') + 1)); $path = $path.Substring(0, $path.IndexOf('?')) }
    $path = [uri]::UnescapeDataString($path).TrimEnd('/')
    function List($items) { [pscustomobject]@{ value = @($items) } }
    function NotFound { throw [System.Exception]::new("Synthetic Graph: resource not found for $path (HTTP 404)") }
    function Strip($o) { $o | Select-Object -Property * -ExcludeProperty RoleId }

    $workloadSets = @{
        'deviceManagement/deviceConfigurations'          = $Tenant.DeviceConfigurations
        'deviceManagement/configurationPolicies'         = $Tenant.ConfigurationPolicies
        'deviceManagement/deviceCompliancePolicies'      = $Tenant.CompliancePolicies
        'deviceAppManagement/mobileApps'                 = $Tenant.MobileApps
        'deviceManagement/deviceManagementScripts'       = $Tenant.Scripts
        'deviceManagement/deviceHealthScripts'           = $Tenant.HealthScripts
        'deviceManagement/windowsFeatureUpdateProfiles'  = $Tenant.FeatureUpdates
    }

    switch -Regex ($path) {
        '^organization$' { return List $Tenant.Organization }
        '^deviceManagement/roleScopeTags$' { return List $Tenant.ScopeTags }
        '^deviceManagement/roleDefinitions$' { return List $Tenant.RoleDefinitions }
        '^deviceManagement/roleDefinitions/([^/]+)/roleAssignments$' {
            $roleId = $Matches[1]; return List ($Tenant.RoleAssignments | Where-Object RoleId -EQ $roleId | ForEach-Object { Strip $_ })
        }
        '^deviceManagement/roleDefinitions/[^/]+/roleAssignments/([^/]+)$' {
            $a = $Tenant.RoleAssignments | Where-Object id -EQ $Matches[1]; if (-not $a) { NotFound }; return (Strip $a)
        }
        '^deviceManagement/assignmentFilters$' { return List $Tenant.AssignmentFilters }
        '^deviceManagement/managedDevices$' {
            if ($query -match "id eq '([^']+)'") { return List ($Tenant.ManagedDevices | Where-Object id -EQ $Matches[1]) }
            if ($query -match "deviceName eq '([^']+)'") { return List ($Tenant.ManagedDevices | Where-Object deviceName -EQ $Matches[1]) }
            return List $Tenant.ManagedDevices
        }
        '^devices$' {
            if ($query -match "deviceId eq '([^']+)'") { return List ($Tenant.EntraDevices | Where-Object deviceId -EQ $Matches[1]) }
            return List $Tenant.EntraDevices
        }
        '^devices/([^/]+)/transitiveMemberOf/microsoft\.graph\.group$' {
            $entra = $Tenant.EntraDevices | Where-Object id -EQ $Matches[1]; if (-not $entra) { NotFound }
            if (-not $Tenant.DeviceGroups.ContainsKey($entra.deviceId)) { return List @() }
            return List @($Tenant.DeviceGroups[$entra.deviceId] | Select-Object id, displayName)
        }
        '^users/([^/]+)$' {
            $key = $Matches[1]; $user = $Tenant.Users | Where-Object { $_.id -eq $key -or $_.userPrincipalName -eq $key }; if (-not $user) { NotFound }; return $user
        }
        '^users/([^/]+)/(memberOf|transitiveMemberOf)/microsoft\.graph\.group$' {
            $userId = $Matches[1]; $transitive = $Matches[2] -eq 'transitiveMemberOf'
            $direct = @($Tenant.GroupMembers.Keys | Where-Object { @($Tenant.GroupMembers[$_]).id -contains $userId })
            $all = [System.Collections.Generic.List[string]]::new(); foreach ($d in $direct) { $all.Add($d) }
            if ($transitive) { foreach ($parent in $Tenant.NestedGroups.Keys) { if (@($Tenant.NestedGroups[$parent] | Where-Object { $_ -in $direct }).Count -gt 0) { $all.Add($parent) } } }
            return List @($Tenant.Groups | Where-Object { $_.id -in $all })
        }
        '^groups/([^/]+)$' { $grp = $Tenant.Groups | Where-Object id -EQ $Matches[1]; if (-not $grp) { NotFound }; return $grp }
        '^groups/([^/]+)/(members|transitiveMembers)/microsoft\.graph\.user$' {
            $groupId = $Matches[1]; $members = [System.Collections.Generic.List[object]]::new()
            $transitiveRequest = $Matches[2] -eq 'transitiveMembers'
            if ($Tenant.GroupMembers.ContainsKey($groupId)) { foreach ($m in @($Tenant.GroupMembers[$groupId])) { $members.Add($m) } }
            if ($transitiveRequest -and $Tenant.NestedGroups.ContainsKey($groupId)) {
                foreach ($child in @($Tenant.NestedGroups[$groupId])) { if ($Tenant.GroupMembers.ContainsKey($child)) { foreach ($m in @($Tenant.GroupMembers[$child])) { $members.Add($m) } } }
            }
            return List $members
        }
        '^deviceManagement/detectedApps$' { return List $Tenant.DetectedApps }
        '^deviceManagement/detectedApps/([^/]+)/managedDevices$' {
            $key = $Matches[1]; if (-not $Tenant.DetectedLinks.ContainsKey($key)) { return List @() }
            return List @($Tenant.DetectedLinks[$key] | Select-Object id, deviceName, lastSyncDateTime, operatingSystem, osVersion)
        }
        '^deviceManagement/auditEvents$' { return List $Tenant.AuditEvents }
        '^deviceAppManagement/mobileApps/([^/]+)/relationships$' { return List @() }
        '^(deviceManagement|deviceAppManagement)/[A-Za-z]+/([^/]+)/assignments$' {
            $key = $Matches[2]; if (-not $Tenant.Assignments.ContainsKey($key)) { return List @() }; return List @($Tenant.Assignments[$key])
        }
        '^(deviceManagement|deviceAppManagement)/[A-Za-z]+/([^/]+)/(deviceStatuses)$' {
            $key = $Matches[2]; if (-not $Tenant.Statuses.ContainsKey($key)) { return List @() }; return List @($Tenant.Statuses[$key])
        }
        '^(deviceManagement|deviceAppManagement)/[A-Za-z]+/([^/]+)/deviceRunStates$' {
            $key = $Matches[2]; if (-not $Tenant.RunStates.ContainsKey($key)) { return List @() }; return List @($Tenant.RunStates[$key])
        }
        '^deviceManagement/configurationPolicies/([^/]+)/settings$' { $key = $Matches[1]; if (-not $Tenant.PolicySettings.ContainsKey($key)) { return List @() }; return List @($Tenant.PolicySettings[$key]) }
        '^((deviceManagement|deviceAppManagement)/[A-Za-z]+)/([^/]+)$' {
            $set = $workloadSets[$Matches[1]]
            if ($null -ne $set) { $item = @($set | Where-Object id -EQ $Matches[3]); if ($item.Count -eq 1) { return $item[0] } }
        }
    }

    if ($workloadSets.ContainsKey($path)) { return List $workloadSets[$path] }

    # Every other collection is presented as available but empty in the synthetic tenant.
    return List @()
}
