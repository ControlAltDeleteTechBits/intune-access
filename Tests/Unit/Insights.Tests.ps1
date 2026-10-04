$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'IntuneAccess 5.0 insights' {
    InModuleScope IntuneAccess {
        BeforeAll {
            $script:asOf = [DateTimeOffset]::Parse('2026-10-04T12:00:00Z')
            function New-TestPath([string] $State, [string] $TargetType = 'Included group', [string] $Intent = 'required', [string] $FilterState = 'NotApplicable') {
                [pscustomobject] @{ AssignmentId = 'a'; Intent = $Intent; TargetType = $TargetType; GroupId = 'g1'; GroupName = 'Pilot'; DeviceTargetState = $(if ($State -in @('Included', 'Excluded', 'FilteredOut')) { 'Matched' } else { 'NotMatched' }); UserTargetState = 'NotMatched'; FilterId = $(if ($FilterState -ne 'NotApplicable') { 'f1' } else { '' }); FilterMode = 'include'; FilterState = $FilterState; FilterRule = '(device.osVersion -startsWith "10.0.2")'; FilterObservedValue = '10.0.19045'; PathState = $State }
            }
            function New-TestExplanation([object[]] $Paths, [object[]] $Outcomes = @(), [string] $State = 'Included') {
                [pscustomobject] @{ DeviceId = 'd1'; DeviceName = 'PC-1'; WorkloadId = 'w1'; WorkloadName = 'VPN'; WorkloadType = 'Applications'; AssignmentState = $State; AssignmentPaths = $Paths; DeploymentOutcomes = $Outcomes }
            }
            $script:freshDevice = [pscustomobject] @{ Id = 'd1'; DeviceName = 'PC-1'; LastSyncDateTime = '2026-10-04T10:00:00Z'; UserPrincipalName = 'user@example.test' }
            $script:staleDevice = [pscustomobject] @{ Id = 'd1'; DeviceName = 'PC-1'; LastSyncDateTime = '2026-08-01T10:00:00Z' }
        }

        It 'explains only error codes that Microsoft publishes' {
            (Get-IntuneAccessErrorReference -ErrorCode -2016345060).Hex | Should -Be '0x87D1041C'
            (Get-IntuneAccessErrorReference -ErrorCode '0x87d1041c').State | Should -Be 'PublishedReference'
            (Get-IntuneAccessErrorReference -ErrorCode -2016345060).Source | Should -Match '^https://learn\.microsoft\.com/'
            $unknown = Get-IntuneAccessErrorReference -ErrorCode -2147023293
            $unknown.Hex | Should -Be '0x80070643'
            $unknown.State | Should -Be 'NotInReference'
            $unknown.Meaning | Should -BeNullOrEmpty
            Get-IntuneAccessErrorReference -ErrorCode 0 | Should -BeNullOrEmpty
        }

        It 'stops the delivery chain at the first broken link' {
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'Excluded' 'Excluded group') -State 'Excluded') -Device $freshDevice -AsOf $asOf).Verdict | Should -Be 'Excluded'
            $filtered = Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'FilteredOut' -FilterState 'FilteredOut') -State 'NotTargeted') -Device $freshDevice -AsOf $asOf
            $filtered.Verdict | Should -Be 'FilteredOut'
            ($filtered.Steps | Where-Object Name -EQ 'Assignment filter').Evidence | Should -Match '10\.0\.19045'
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'NotMatched') -State 'NotTargeted') -Device $freshDevice -AsOf $asOf).Verdict | Should -Be 'NotTargeted'
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @() -State 'NotAssigned') -Device $freshDevice -AsOf $asOf).Verdict | Should -Be 'NotAssigned'
        }

        It 'explains a reported failure with the published error meaning' {
            $outcome = [pscustomobject] @{ WorkloadId = 'w1'; DeviceId = 'd1'; Category = 'Error'; State = 'failed'; StateDetail = 'appNotDetectedAfterInstall'; ErrorCode = -2016345060; LastReportedDateTime = '2026-10-04T09:00:00Z' }
            $chain = Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'Included') @($outcome)) -Device $freshDevice -AsOf $asOf
            $chain.Verdict | Should -Be 'Failed'
            $chain.StoppedAt | Should -Be 'Reported outcome'
            $chain.Summary | Should -Match '0x87D1041C'
            $chain.NextCheck | Should -Match 'detection rule'
        }

        It 'separates waiting devices, uncollected results and available intent' {
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'Included')) -Device $staleDevice -AsOf $asOf).Verdict | Should -Be 'WaitingForDevice'
            $status = @([pscustomobject] @{ WorkloadId = 'w1'; State = 'NotSupported' })
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'Included')) -Device $freshDevice -OutcomeCollectionStatus $status -AsOf $asOf).Verdict | Should -Be 'ResultNotCollected'
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'Included' -Intent 'available')) -Device $freshDevice -AsOf $asOf).Verdict | Should -Be 'AvailableOrUninstallIntent'
            $success = [pscustomobject] @{ WorkloadId = 'w1'; DeviceId = 'd1'; Category = 'Success'; State = 'installed'; LastReportedDateTime = '2026-10-04T09:00:00Z' }
            (Get-IntuneAccessDeliveryChain -Explanation (New-TestExplanation @(New-TestPath 'Included') @($success)) -Device $freshDevice -AsOf $asOf).Verdict | Should -Be 'Applied'
        }

        It 'detects new failures and recoveries between collections' {
            $before = @(
                [pscustomobject] @{ WorkloadId = 'w1'; DeviceId = 'd1'; Category = 'Success'; State = 'installed' }
                [pscustomobject] @{ WorkloadId = 'w2'; DeviceId = 'd1'; Category = 'Error'; State = 'failed' }
                [pscustomobject] @{ WorkloadId = 'w3'; DeviceId = 'd1'; Category = 'Success'; State = 'installed' }
            )
            $after = @(
                [pscustomobject] @{ WorkloadId = 'w1'; DeviceId = 'd1'; Category = 'Error'; State = 'failed' }
                [pscustomobject] @{ WorkloadId = 'w2'; DeviceId = 'd1'; Category = 'Success'; State = 'installed' }
                [pscustomobject] @{ WorkloadId = 'w3'; DeviceId = 'd1'; Category = 'Success'; State = 'installed' }
            )
            $transitions = @(Compare-IntuneAccessOutcomeTransition -Before $before -After $after)
            $transitions.Count | Should -Be 2
            ($transitions | Where-Object WorkloadId -EQ 'w1').Transition | Should -Be 'NewFailure'
            ($transitions | Where-Object WorkloadId -EQ 'w2').Transition | Should -Be 'Recovered'
        }

        It 'marks a change as correlated only when a failure follows within the window' {
            $audit = @([pscustomobject] @{ Activity = 'Patch MobileApp'; ActivityDateTime = '2026-10-03T10:00:00Z'; ActorUserPrincipalName = 'admin@example.test'; ResourceIds = @('w1'); Resources = @([pscustomobject] @{ DisplayName = 'VPN'; ModifiedProperties = @() }) })
            $workload = @([pscustomobject] @{ Id = 'w1'; Name = 'VPN' }, [pscustomobject] @{ Id = 'w2'; Name = 'Other' })
            $soon = @([pscustomobject] @{ WorkloadId = 'w1'; WorkloadName = 'VPN'; DeviceName = 'PC-1'; Category = 'Error'; State = 'failed'; LastReportedDateTime = '2026-10-03T12:00:00Z' })
            $timeline = Get-IntuneAccessChangeTimeline -AuditEvent $audit -DeploymentOutcome $soon -Workload $workload -AsOf $asOf
            $timeline.CorrelatedChanges | Should -Be 1
            ($timeline.Entries | Where-Object Kind -EQ 'Configuration').Correlated | Should -Match 'not proof of cause'

            $late = @([pscustomobject] @{ WorkloadId = 'w1'; WorkloadName = 'VPN'; DeviceName = 'PC-1'; Category = 'Error'; State = 'failed'; LastReportedDateTime = '2026-10-08T12:00:00Z' })
            (Get-IntuneAccessChangeTimeline -AuditEvent $audit -DeploymentOutcome $late -Workload $workload -AsOf $asOf).CorrelatedChanges | Should -Be 0
            $before = @([pscustomobject] @{ WorkloadId = 'w2'; WorkloadName = 'Other'; DeviceName = 'PC-1'; Category = 'Error'; State = 'failed'; LastReportedDateTime = '2026-10-03T12:00:00Z' })
            (Get-IntuneAccessChangeTimeline -AuditEvent $audit -DeploymentOutcome $before -Workload $workload -AsOf $asOf).CorrelatedChanges | Should -Be 0
        }

        It 'flags unreadable groups, orphaned scope tags and dual-purpose groups' {
            $collection = [pscustomobject] @{
                WorkloadObjects = @([pscustomobject] @{ Id = 'w1'; Name = 'Script'; WorkloadType = 'Scripts'; ScopeTagIds = @('9') })
                WorkloadAssignments = @(
                    [pscustomobject] @{ WorkloadId = 'w1'; WorkloadName = 'Script'; WorkloadType = 'Scripts'; TargetType = 'Included group'; Intent = 'Assign'; GroupId = 'gone'; Group = [pscustomobject] @{ DisplayName = '[Unresolved group]'; ResolutionState = 'Unresolved' }; FilterId = ''; FilterMode = 'none' }
                    [pscustomobject] @{ WorkloadId = 'w1'; WorkloadName = 'Script'; WorkloadType = 'Scripts'; TargetType = 'Included group'; Intent = 'Assign'; GroupId = 'both'; Group = [pscustomobject] @{ DisplayName = 'Both'; ResolutionState = 'Resolved' }; FilterId = ''; FilterMode = 'none' }
                    [pscustomobject] @{ WorkloadId = 'w2'; WorkloadName = 'App'; WorkloadType = 'Applications'; TargetType = 'Excluded group'; Intent = 'Exclude'; GroupId = 'both'; Group = [pscustomobject] @{ DisplayName = 'Both'; ResolutionState = 'Resolved' }; FilterId = ''; FilterMode = 'none' }
                )
                RoleAssignments = @([pscustomobject] @{ Id = 'r1'; Name = 'Helpdesk'; RoleDefinition = [pscustomobject] @{ DisplayName = 'Help Desk Operator' }; AdminGroups = @([pscustomobject] @{ Id = 'both'; DisplayName = 'Both' }); ScopeGroups = @(); ScopeTags = @([pscustomobject] @{ Id = '1'; DisplayName = 'UK' }); RawIds = [pscustomobject] @{ ScopeTagIds = @('1') }; ScopeTagDataState = 'Available' })
                AllScopeTags = @([pscustomobject] @{ Id = '9'; DisplayName = 'Retail' })
                ScopeTags = @(); AssignmentFilters = @()
            }
            $index = @(Get-IntuneAccessDependencyIndex -Collection $collection)
            ($index | Where-Object Id -EQ 'gone').Flags | Should -Match 'could not be read'
            ($index | Where-Object Id -EQ '9').Name | Should -Be 'Retail'
            ($index | Where-Object Id -EQ '9').Flags | Should -Match 'no role assignment includes it'
            $both = $index | Where-Object Id -EQ 'both'
            $both.DependentCount | Should -Be 3
            @($both.Flags).Count | Should -Be 2
        }

        It 'never judges read permissions and only maps direct audit categories' {
            $collection = [pscustomobject] @{
                Administrators = @([pscustomobject] @{
                    User = [pscustomobject] @{ UserPrincipalName = 'admin@example.test'; DisplayName = 'Admin' }
                    EffectivePermissions = @(
                        [pscustomobject] @{ RawAction = 'Microsoft.Intune_DeviceConfigurations_Update'; Resource = 'Device Configurations'; Operation = 'Update'; State = 'Allowed' }
                        [pscustomobject] @{ RawAction = 'Microsoft.Intune_DeviceConfigurations_Read'; Resource = 'Device Configurations'; Operation = 'Read'; State = 'Allowed' }
                        [pscustomobject] @{ RawAction = 'Microsoft.Intune_MobileApps_Update'; Resource = 'Mobile Apps'; Operation = 'Update'; State = 'Allowed' }
                        [pscustomobject] @{ RawAction = 'Microsoft.Intune_Organization_Update'; Resource = 'Organization'; Operation = 'Update'; State = 'Allowed' }
                        [pscustomobject] @{ RawAction = 'Microsoft.Intune_Audit_Read'; Resource = 'Audit'; Operation = 'Read'; State = 'Allowed' }
                    )
                })
                AuditEvents = @([pscustomobject] @{ ActorUserPrincipalName = 'ADMIN@example.test'; Category = 'DeviceConfiguration'; Activity = 'Patch policy'; ActivityDateTime = '2026-10-01T10:00:00Z' })
                AuditCollectionStatus = [pscustomobject] @{ State = 'Available' }
            }
            $review = Get-IntuneAccessPrivilegeUsage -Collection $collection
            $review.Rows.Count | Should -Be 3
            ($review.Rows | Where-Object PermissionFamily -EQ 'Device Configurations').State | Should -Be 'ObservedActivity'
            ($review.Rows | Where-Object PermissionFamily -EQ 'Mobile Apps').State | Should -Be 'NoObservedActivity'
            ($review.Rows | Where-Object PermissionFamily -EQ 'Organization').State | Should -Be 'NotEvaluated'
            @($review.Rows | Where-Object PermissionFamily -EQ 'Audit').Count | Should -Be 0

            $collection.AuditCollectionStatus = [pscustomobject] @{ State = 'Unavailable' }
            @((Get-IntuneAccessPrivilegeUsage -Collection $collection).Rows | Where-Object State -NE 'NotEvaluated').Count | Should -Be 0
        }

        Context 'Scoped permissions readiness' {
            BeforeAll {
                function New-TestAssignment([string] $Id, [string] $Role, [string[]] $Actions, [string] $TagId, [string] $TagName) {
                    [pscustomobject] @{ Id = $Id; Name = $Id; RoleDefinition = [pscustomobject] @{ DisplayName = $Role }; Permissions = $Actions; ScopeTags = @([pscustomobject] @{ Id = $TagId; DisplayName = $TagName }); ScopeTagDataState = 'Available'; RawIds = [pscustomobject] @{ AdminGroupIds = @('g1'); ScopeTagIds = @($TagId) } }
                }
                $script:scopedCollection = [pscustomobject] @{
                    AdminGroups = @([pscustomobject] @{ Id = 'g1'; DisplayName = 'App Packagers' })
                    Memberships = @([pscustomobject] @{ GroupId = 'g1'; User = [pscustomobject] @{ Id = 'u1' } })
                    RoleAssignments = @(
                        New-TestAssignment -Id 'a1' -Role 'Application Manager' -Actions @('Microsoft.Intune_MobileApps_Read', 'Microsoft.Intune_MobileApps_Update') -TagId '1' -TagName 'UK'
                        New-TestAssignment -Id 'a2' -Role 'Read Only Operator' -Actions @('Microsoft.Intune_MobileApps_Read') -TagId '3' -TagName 'Finance'
                    )
                }
            }

            It 'predicts the permissions a group loses per scope tag' {
                $readiness = Get-IntuneAccessScopedReadiness -Collection $scopedCollection
                $readiness.AssessmentState | Should -Be 'NotImported'
                @($readiness.Rows).Count | Should -Be 1
                $row = $readiness.Rows[0]
                $row.Group | Should -Be 'App Packagers'
                $row.ScopeTag | Should -Be 'Finance'
                $row.LostPermissions | Should -Be @('Update')
                $row.NewPermissions | Should -Be @('Read')
            }

            It 'reconciles with an exported CSV report' {
                $csv = Join-Path $TestDrive 'assessment.csv'
                @(
                    'Group,Roles,Scope Tag,Resource,Old Permissions,New Permissions'
                    'App Packagers,"Application Manager, Read Only Operator",Finance,MobileApps,"Read, Update",Read'
                    'Helpdesk,Help Desk Operator,US,ManagedDevices,"Read, Wipe",Read'
                ) | Set-Content -LiteralPath $csv -Encoding utf8
                $assessment = Import-IntuneAccessPermissionAssessment -Path $csv
                $assessment.Rows.Count | Should -Be 2
                $readiness = Get-IntuneAccessScopedReadiness -Collection $scopedCollection -Assessment $assessment
                ($readiness.Rows | Where-Object Group -EQ 'App Packagers').ReconciliationState | Should -Be 'Agreed'
                ($readiness.Rows | Where-Object Group -EQ 'Helpdesk').ReconciliationState | Should -Be 'MicrosoftOnly'
                $readiness.Agreed | Should -Be 1
                $readiness.Disagreements | Should -Be 1
            }

            It 'reads an Excel export without extra modules' {
                Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
                $xlsx = Join-Path $TestDrive 'assessment.xlsx'
                $zip = [IO.Compression.ZipFile]::Open($xlsx, 'Create')
                try {
                    $write = { param($name, $content) $entry = $zip.CreateEntry($name); $writer = [IO.StreamWriter]::new($entry.Open()); $writer.Write($content); $writer.Dispose() }
                    & $write 'xl/sharedStrings.xml' '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Group</t></si><si><t>Roles</t></si><si><t>Scope Tag</t></si><si><t>Resource</t></si><si><t>Old Permissions</t></si><si><t>New Permissions</t></si><si><t>App Packagers</t></si><si><t>Finance</t></si><si><t>MobileApps</t></si><si><t>Read, Update</t></si><si><t>Read</t></si></sst>'
                    & $write 'xl/worksheets/sheet1.xml' '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c><c r="F1" t="s"><v>5</v></c></row><row r="2"><c r="A2" t="s"><v>6</v></c><c r="C2" t="s"><v>7</v></c><c r="D2" t="s"><v>8</v></c><c r="E2" t="s"><v>9</v></c><c r="F2" t="s"><v>10</v></c></row></sheetData></worksheet>'
                }
                finally { $zip.Dispose() }
                $assessment = Import-IntuneAccessPermissionAssessment -Path $xlsx
                $assessment.Rows.Count | Should -Be 1
                $assessment.Rows[0].Roles.Count | Should -Be 0
                $assessment.Rows[0].OldPermissions | Should -Be @('Read', 'Update')
                (Get-IntuneAccessScopedReadiness -Collection $scopedCollection -Assessment $assessment).Rows[0].ReconciliationState | Should -Be 'Agreed'
            }

            It 'rejects files that are not an assessment export' {
                $csv = Join-Path $TestDrive 'other.csv'
                'Name,Value', 'a,b' | Set-Content -LiteralPath $csv
                { Import-IntuneAccessPermissionAssessment -Path $csv } | Should -Throw '*Permissions Assessment Report*'
            }
        }

        Context 'Public 5.0 commands' {
            BeforeAll {
                $script:publicCollection = [pscustomobject] @{
                    GeneratedAt = '2026-10-04T12:00:00Z'
                    ManagedDevices = @([pscustomobject] @{ Id = 'd1'; DeviceName = 'PC-1'; LastSyncDateTime = '2026-10-04T10:00:00Z' })
                    DeviceAssignmentExplanations = @(
                        (New-TestExplanation @(New-TestPath 'Excluded' 'Excluded group') -State 'Excluded')
                        ((New-TestExplanation @(New-TestPath 'Included') @([pscustomobject] @{ WorkloadId = 'w2'; DeviceId = 'd1'; Category = 'Success'; State = 'installed'; LastReportedDateTime = '2026-10-04T09:00:00Z' })) | ForEach-Object { $_.WorkloadId = 'w2'; $_.WorkloadName = 'Browser'; $_ })
                    )
                    OutcomeCollectionStatus = @()
                    WorkloadObjects = @([pscustomobject] @{ Id = 'w1'; Name = 'VPN'; WorkloadType = 'Applications'; ScopeTagIds = @() })
                    WorkloadAssignments = @([pscustomobject] @{ WorkloadId = 'w1'; WorkloadName = 'VPN'; WorkloadType = 'Applications'; TargetType = 'Included group'; Intent = 'required'; GroupId = 'g1'; Group = [pscustomobject] @{ DisplayName = 'Pilot'; ResolutionState = 'Resolved' }; FilterId = ''; FilterMode = 'none' })
                    RoleAssignments = @(); AdminGroups = @(); Memberships = @(); ScopeTags = @(); AssignmentFilters = @(); Administrators = @()
                    AuditEvents = @(); DeploymentOutcomes = @()
                }
                Mock Get-IntuneAccessInsightCollection { $script:publicCollection }
            }

            It 'returns delivery chains for one device and can hide successes' {
                @(Get-IntuneDeliveryChain -DeviceName 'PC-1' -SnapshotPath 'unused.json').Count | Should -Be 2
                $problems = @(Get-IntuneDeliveryChain -DeviceName 'PC-1' -SnapshotPath 'unused.json' -ProblemsOnly)
                $problems.Count | Should -Be 1
                $problems[0].Verdict | Should -Be 'Excluded'
                @(Get-IntuneDeliveryChain -DeviceName 'PC-1' -SnapshotPath 'unused.json' -WorkloadName 'Brow*').Count | Should -Be 1
                { Get-IntuneDeliveryChain -DeviceName 'MISSING' -SnapshotPath 'unused.json' } | Should -Throw '*no assignment explanations*'
            }

            It 'filters the change preview by name and type' {
                @(Get-IntuneChangePreview -Name 'Pilot').Count | Should -Be 1
                @(Get-IntuneChangePreview -SubjectType ScopeTag).Count | Should -Be 0
                @(Get-IntuneChangePreview -FlaggedOnly).Count | Should -Be 0
            }

            It 'returns privilege, timeline and Scoped permissions results from the collection' {
                (Get-IntunePrivilegeUsage).PSObject.TypeNames | Should -Contain 'IntuneAccess.PrivilegeUsageReview'
                (Get-IntuneChangeTimeline).BaselineState | Should -Be 'NoBaseline'
                (Get-IntuneScopedPermissionReadiness).AssessmentState | Should -Be 'NotImported'
            }
        }

        It 'renders the five 5.0 views with encoded values and no remote resources' {
            $collection = [pscustomobject] @{
                PSTypeName = 'IntuneAccess.TenantRbac'
                Tenant = [pscustomobject] @{ Id = 't'; DisplayName = 'Example' }
                Administrators = @(); AdminGroups = @(); RoleAssignments = @(); RoleDefinitions = @(); ScopeGroups = @(); ScopeTags = @(); Permissions = @(); Memberships = @()
                Warnings = @(); InitialUserPrincipalName = ''; GraphPermissionsUsed = @(); GeneratedAt = $asOf; ToolVersion = 'test'
                DeliveryChains = @(Get-IntuneAccessDeliveryChain -Explanation ((New-TestExplanation @(New-TestPath 'Excluded' 'Excluded group') -State 'Excluded') | ForEach-Object { $_.WorkloadName = 'VPN <script>'; $_ }) -Device $freshDevice -AsOf $asOf)
            }
            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $collection
            foreach ($view in @('delivery-chains', 'change-timeline', 'change-preview', 'privilege-usage', 'scoped-readiness')) {
                $html | Should -Match ('data-view="{0}"' -f $view)
                $html | Should -Match ('data-view-panel="{0}"' -f $view)
            }
            $html | Should -Match 'VPN &lt;script&gt;'
            $html | Should -Not -Match 'VPN <script>'
            [bool] ($html -match '(?i)(?:src|href)\s*=\s*["'']https?://') | Should -BeFalse
        }
    }
}
