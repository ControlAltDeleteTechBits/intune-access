$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Autopilot and enrolment evidence' {
    InModuleScope IntuneAccess {
        BeforeEach { Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('DeviceManagementManagedDevices.Read.All', 'DeviceManagementServiceConfig.Read.All') } } }

        It 'correlates registration, profile and stage duration evidence' {
            Mock Invoke-IntuneAccessGraphRequest {
                switch ($Uri) {
                    'deviceManagement/windowsAutopilotDeviceIdentities' { @([PSCustomObject] @{ id = 'auto-1'; managedDeviceId = 'device-1'; serialNumber = 'ABC1'; deploymentProfileDisplayName = 'Corporate profile'; deploymentProfileAssignmentStatus = 'assigned'; deploymentProfileAssignedDateTime = '2026-08-24T08:00:00Z'; enrollmentState = 'enrolled' }) }
                    'deviceManagement/autopilotEvents' { @([PSCustomObject] @{ windowsAutopilotDeviceIdentityId = 'auto-1'; managedDeviceId = 'device-1'; enrollmentStartDateTime = '2026-08-24T08:10:00Z'; enrollmentEndDateTime = '2026-08-24T08:30:00Z'; enrollmentState = 'success'; devicePreparationDuration = '00:02:00'; devicePreparationState = 'success'; deviceSetupDuration = '00:10:00'; deviceSetupState = 'success'; accountSetupDuration = '00:05:00'; accountSetupState = 'success'; deploymentState = 'success' }) }
                    'deviceManagement/windowsAutopilotDeploymentProfiles' { @([PSCustomObject] @{ id = 'profile-1'; displayName = 'Corporate profile' }) }
                    'deviceManagement/deviceEnrollmentConfigurations' { @([PSCustomObject] @{ id = 'esp-1'; displayName = 'Default ESP' }) }
                }
            }
            $device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; SerialNumber = 'ABC1'; EntraDeviceId = '' }
            $result = Get-IntuneAccessAutopilotEvidence -ManagedDevice @($device)
            $result.Timelines[0].CorrelationState | Should -Be 'Matched'
            $result.Timelines[0].DeploymentProfileName | Should -Be 'Corporate profile'
            ($result.Timelines[0].Timeline | Where-Object Stage -EQ 'Device setup').DurationSeconds | Should -Be 600
            $result.Timelines[0].EvidenceBoundary | Should -Match 'Graph beta'
        }

        It 'isolates an unavailable beta source' {
            Mock Invoke-IntuneAccessGraphRequest { if ($Uri -eq 'deviceManagement/autopilotEvents') { throw 'event API unavailable' }; @() }
            $result = Get-IntuneAccessAutopilotEvidence
            ($result.CollectionStatus | Where-Object Source -EQ 'Autopilot events').State | Should -Be 'Unavailable'
            $result.Warnings -join ' ' | Should -Match 'event API unavailable'
        }
    }
}

Describe 'Application and software evidence' {
    InModuleScope IntuneAccess {
        BeforeEach { Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('DeviceManagementApps.Read.All', 'DeviceManagementManagedDevices.Read.All') } } }

        It 'joins intent, reported installation and exact-name detected software evidence' {
            Mock Invoke-IntuneAccessGraphRequest {
                switch -Wildcard ($Uri) {
                    'deviceManagement/detectedApps?*' { @([PSCustomObject] @{ id = 'detected-1'; displayName = 'Support App'; publisher = 'Contoso'; version = '2.0'; deviceCount = 1; platform = 'windows' }) }
                    'deviceManagement/detectedApps/detected-1/managedDevices*' { @([PSCustomObject] @{ id = 'device-1'; deviceName = 'PC-001' }) }
                    'deviceAppManagement/mobileApps' { @([PSCustomObject] @{ id = 'app-1'; displayName = 'Support App'; publisher = 'Contoso'; detectionRules = @([PSCustomObject] @{ ruleType = 'file' }); requirementRules = @([PSCustomObject] @{ ruleType = 'os' }) }) }
                    'deviceAppManagement/mobileApps/app-1/relationships' { @([PSCustomObject] @{ id = 'rel-1'; targetId = 'app-2'; '@odata.type' = '#microsoft.graph.mobileAppDependency' }) }
                    default { @() }
                }
            }
            $workload = [PSCustomObject] @{ Id = 'app-1'; Name = 'Support App'; WorkloadType = 'Applications' }
            $assignment = [PSCustomObject] @{ WorkloadId = 'app-1'; Intent = 'required' }
            $device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001' }
            $outcome = [PSCustomObject] @{ WorkloadId = 'app-1'; DeviceId = 'device-1'; Category = 'Success' }
            $result = Get-IntuneAccessApplicationEvidence -Workload @($workload) -Assignment @($assignment) -ManagedDevice @($device) -DeploymentOutcome @($outcome)
            $result.DeviceApplicationEvidence[0].ConfiguredIntents | Should -Contain 'required'
            $result.DeviceApplicationEvidence[0].DetectionState | Should -Be 'DetectedByName'
            $result.DeviceApplicationEvidence[0].DetectionRules.Count | Should -Be 1
            $result.DeviceApplicationEvidence[0].Relationships.Count | Should -Be 1
            $result.DeviceApplicationEvidence[0].EvidenceBoundary | Should -Match 'not proof'
        }

        It 'labels relationship collection limits instead of omitting the boundary' {
            Mock Invoke-IntuneAccessGraphRequest {
                if ($Uri -like 'deviceManagement/detectedApps?*') { return @([PSCustomObject] @{ id = 'd1'; displayName = 'One'; deviceCount = 1 }, [PSCustomObject] @{ id = 'd2'; displayName = 'Two'; deviceCount = 1 }) }
                @()
            }
            $result = Get-IntuneAccessApplicationEvidence -Workload @() -Assignment @() -ManagedDevice @() -MaximumRelationshipQueries 1
            $result.Warnings -join ' ' | Should -Match 'limited to 1'
            $result.DetectedApplications.RelationshipState | Should -Contain 'NotCollected'
        }
    }
}

Describe 'Update, compliance and estate intelligence' {
    InModuleScope IntuneAccess {
        It 'distinguishes stale reporting from a returned failure' {
            $device = [PSCustomObject] @{ Id = 'device-1'; DeviceName = 'PC-001'; UserPrincipalName = 'a@example.test'; OperatingSystem = 'Windows'; OsVersion = '10.0.22631'; ComplianceState = 'noncompliant'; LastSyncDateTime = '2026-06-01T00:00:00Z' }
            $updates = [PSCustomObject] @{ Id = 'update-1'; Name = 'Windows 11 24H2'; WorkloadType = 'Updates'; SourceCollection = 'Feature update policies'; TargetVersion = '24H2'; SourceApiVersion = 'beta' }
            $compliance = [PSCustomObject] @{ Id = 'compliance-1'; Name = 'Baseline'; WorkloadType = 'Compliance'; SourceCollection = 'Compliance policies' }
            $assignments = @([PSCustomObject] @{ WorkloadId = 'update-1' }, [PSCustomObject] @{ WorkloadId = 'compliance-1' })
            $outcome = [PSCustomObject] @{ WorkloadId = 'update-1'; DeviceId = 'device-1'; Category = 'Error' }
            $result = Get-IntuneAccessUpdateComplianceEvidence -Workload @($updates, $compliance) -Assignment $assignments -ManagedDevice @($device) -DeploymentOutcome @($outcome) -AsOf ([DateTimeOffset]::Parse('2026-08-24T00:00:00Z'))
            ($result.Investigations | Where-Object WorkloadId -EQ 'update-1').InvestigationState | Should -Be 'ReturnedFailure'
            ($result.Investigations | Where-Object WorkloadId -EQ 'compliance-1').InvestigationState | Should -Be 'StaleReporting'
            $result.CollectionStatus.ApiVersions | Should -Contain 'NotReturned'
        }

        It 'prioritises traceable findings and groups shared evidence without claiming cause' {
            $deviceIntelligence = [PSCustomObject] @{ Inventory = @([PSCustomObject] @{ Id = 'd1'; Model = 'Model A'; OsVersion = '10'; EnrollmentType = 'autopilot'; ManagementAgent = 'mdm' }, [PSCustomObject] @{ Id = 'd2'; Model = 'Model A'; OsVersion = '10'; EnrollmentType = 'autopilot'; ManagementAgent = 'mdm' }); Findings = @() }
            $outcomes = @(
                [PSCustomObject] @{ WorkloadId = 'app-1'; WorkloadName = 'Support App'; DeviceId = 'd1'; DeviceName = 'PC-1'; Category = 'Error'; StateDetail = 'failed' },
                [PSCustomObject] @{ WorkloadId = 'app-1'; WorkloadName = 'Support App'; DeviceId = 'd2'; DeviceName = 'PC-2'; Category = 'Error'; StateDetail = 'failed' }
            )
            $result = Get-IntuneAccessEstateInsight -DeviceIntelligence $deviceIntelligence -DeploymentOutcome $outcomes
            $result.PrioritisedFindings.Count | Should -Be 2
            $result.RecurringFailures.Count | Should -Be 1
            $result.RecurringFailures[0].CauseState | Should -Be 'NotAsserted'
            ($result.Cohorts | Where-Object Dimension -EQ 'Model').DeviceCount | Should -Be 2
            $result.ShareSafeBundle.Findings[0].DeviceName | Should -Match '^redacted-'
        }

        It 'retains a no-baseline state for local historical trends' {
            $result = Get-IntuneAccessEstateInsight -DeviceIntelligence ([PSCustomObject] @{ Inventory = @(); Findings = @() })
            $result.HistoricalTrend.State | Should -Be 'NoBaseline'
            $result.ReadOnly | Should -BeTrue
        }

        It 'requires both snapshots for a historical estate comparison' {
            { Get-IntuneDeviceEstateInsight -ReferenceSnapshotPath '.\before.json' } | Should -Throw '*must be supplied together*'
        }
    }
}

Describe '3.0 snapshot and Signal Atlas integration' {
    InModuleScope IntuneAccess {
        It 'includes device evidence in snapshot schema 2.0' {
            $model = [PSCustomObject] @{ PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [PSCustomObject] @{ Id = 'tenant-1'; DisplayName = 'Example' }; DeviceInventory = @([PSCustomObject] @{ Id = 'd1'; DeviceName = 'PC-1' }); DeviceFindings = @([PSCustomObject] @{ FindingId = 'f1' }); EstateFindings = @([PSCustomObject] @{ FindingId = 'e1' }) }
            $snapshot = ConvertTo-IntuneAccessSnapshot -TenantRbac $model
            $snapshot.SchemaVersion | Should -Be '2.0'
            $snapshot.Data.DeviceInventory.Count | Should -Be 1
            $snapshot.Data.EstateFindings.Count | Should -Be 1
        }

        It 'renders every device intelligence section with encoded evidence' {
            $model = [PSCustomObject] @{
                PSTypeName = 'IntuneAccess.TenantRbac'; Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }; GeneratedAt = [DateTimeOffset]::Now; ToolVersion = '3.0.0'; GraphPermissionsUsed = @(); Warnings = @()
                ManagedDevices = @([PSCustomObject] @{ Id = 'd1'; DeviceName = 'PC <1>'; OperatingSystem = 'Windows'; OsVersion = '10'; ComplianceState = 'compliant'; UserPrincipalName = ''; LastSyncDateTime = $null; Manufacturer = 'Contoso'; Model = 'Virtual'; Ownership = 'company'; ManagementState = 'managed'; EntraDeviceId = 'entra-1'; SerialNumber = 'ABC' })
                DeviceFindings = @([PSCustomObject] @{ FindingId = 'f1'; Title = 'Stale <device>'; DeviceId = 'd1'; DeviceName = 'PC <1>'; RuleId = 'DEV-1'; Severity = 'High'; Category = 'Hygiene'; Explanation = 'Old & stale'; ReviewRecommendation = 'Review'; EvidenceTimestamp = [DateTimeOffset]::Now })
                DeviceAssignmentExplanations = @([PSCustomObject] @{ DeviceId = 'd1'; DeviceName = 'PC <1>'; WorkloadId = 'w1'; WorkloadName = 'Policy'; WorkloadType = 'Configuration'; AssignmentState = 'Included'; ReportedOutcomeState = 'NoReportedEvidence'; AssignmentPaths = @(); EvidenceBoundary = 'Boundary' })
                AutopilotTimelines = @([PSCustomObject] @{ AutopilotIdentityId = 'a1'; DeviceName = 'PC <1>'; SerialNumber = 'ABC'; DeploymentProfileName = 'Profile'; EnrollmentState = 'enrolled'; ProfileAssignmentState = 'assigned'; Timeline = @(); FailureDetails = @(); EventCount = 0; EvidenceBoundary = 'Beta boundary' })
                DetectedApplications = @([PSCustomObject] @{ Id = 'app1'; DisplayName = 'App & Tool'; Publisher = 'Contoso'; Version = '1'; ReportedDeviceCount = 1; RelationshipState = 'Available'; ManagedDevices = @(); Platform = 'Windows' })
                DeviceApplicationEvidence = @([PSCustomObject] @{ ApplicationName = 'App'; DeviceName = 'PC <1>'; ConfiguredIntents = @('required'); DetectionState = 'DetectedByName'; InstallResults = @(); Requirements = @(); Relationships = @(); EvidenceBoundary = 'Boundary' })
                UpdateComplianceInvestigations = @([PSCustomObject] @{ WorkloadName = 'Update'; DeviceName = 'PC <1>'; OsVersion = '10'; InvestigationState = 'StaleReporting'; Explanation = 'Old'; ReportedState = 'NoReportedEvidence'; EvidenceBoundary = 'Boundary' })
                EstateFindings = @([PSCustomObject] @{ FindingId = 'e1'; Title = 'Priority'; DeviceName = 'PC <1>'; SourceType = 'DeviceHygiene'; SourceId = 'DEV-1'; PriorityScore = 75; Severity = 'High'; Explanation = 'Review'; CauseState = 'NotAsserted'; ReviewRecommendation = 'Review' })
                RecurringFailures = @([PSCustomObject] @{ Title = 'Repeated error'; SourceType = 'DeploymentOutcome'; SourceId = 'app1'; DeviceCount = 2; DeviceIds = @('d1','d2'); FindingIds = @('e1','e2'); CauseState = 'NotAsserted'; Explanation = 'Pattern only' })
                DeviceCohorts = @([PSCustomObject] @{ Dimension = 'Model'; Value = 'Virtual'; DeviceCount = 2; DeviceIds = @('d1','d2'); FindingCount = 1 })
                CrossDeviceInvestigations = @([PSCustomObject] @{ SourceType = 'DeploymentOutcome'; SourceId = 'app1'; DeviceCount = 2; DeviceIds = @('d1','d2'); FindingIds = @('e1','e2'); HighestPriority = 75 })
                EstateHistoricalTrend = [PSCustomObject] @{ State = 'NoBaseline' }
            }
            $html = ConvertTo-IntuneAccessExplorerHtml -TenantRbac $model
            foreach ($view in @('estate-findings','recurring-failures','device-cohorts','cross-device','device-findings','assignment-explanations','autopilot','application-evidence','detected-applications','update-compliance')) { $html | Should -Match ([regex]::Escape(('data-view="{0}"' -f $view))) }
            $html | Should -Match 'Stale &lt;device&gt;'
            $html | Should -Match 'App &amp; Tool'
        }
    }
}

Describe 'Device feature scopes' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Get-Module { [PSCustomObject] @{ Version = [version] '2.0.0' } } -ParameterFilter { $ListAvailable }
            Mock Import-Module {}
            Mock Connect-MgGraph {}
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'a@example.test'; TenantId = 'tenant'; Environment = 'Global'; AuthType = 'Delegated'; Scopes = @($RequiredScope) } }
            Mock Get-IntuneAccessTenant { [PSCustomObject] @{ DisplayName = 'Example' } }
        }

        It 'requests only read scopes for estate intelligence' {
            $result = Connect-IntuneAccess -Feature EstateIntelligence
            $result.Scopes | Should -Contain 'DeviceManagementManagedDevices.Read.All'
            $result.Scopes | Should -Contain 'Device.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementApps.Read.All'
            $result.Scopes | Should -Contain 'DeviceManagementConfiguration.Read.All'
            $result.Scopes -join ',' | Should -Not -Match 'ReadWrite'
        }

        It 'requests the service configuration scope only for Autopilot' {
            (Connect-IntuneAccess -Feature DeviceIntelligence).Scopes | Should -Not -Contain 'DeviceManagementServiceConfig.Read.All'
            (Connect-IntuneAccess -Feature Autopilot).Scopes | Should -Contain 'DeviceManagementServiceConfig.Read.All'
        }
    }
}
