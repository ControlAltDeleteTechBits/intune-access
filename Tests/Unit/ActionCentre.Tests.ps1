Import-Module (Join-Path $PSScriptRoot '../../IntuneAccess.psd1') -Force
Describe 'Actionable findings' {
    InModuleScope IntuneAccess {
        It 'exports selected application rule metadata without executable bodies' {
            $collection=[pscustomobject]@{Tenant=@{Id='tenant'};ApplicationDefinitions=@([pscustomobject]@{
                Id='app';DisplayName='</script><script>unsafe-name</script>';ODataType='#microsoft.graph.win32LobApp';SourceApiVersion='beta';InstallExperience=@{runAsAccount='system'}
                Rules=@(@{'@odata.type'='#microsoft.graph.win32LobAppRegistryRule';ruleType='detection';keyPath='HKLM\SOFTWARE\Fixture';valueName='Version';operator='equal';operationType='string';comparisonValue='1';check32BitOn64System=$false;scriptContent='SECRET_SCRIPT_BODY'})
            })}
            $html=ConvertTo-IntuneAccessActionCentreHtml -Collection $collection
            $html | Should -Match 'Export application rules'
            $html | Should -Match 'investigation-application'
            $html | Should -Match 'comparisonValue'
            $html | Should -Not -Match 'SECRET_SCRIPT_BODY'
            $html | Should -Not -Match '<script>unsafe-name</script>'
            $html | Should -Match 'No exportable detection rules'
        }
        It 'provides a complete non-executing guide for every existing hygiene rule' {
            foreach ($rule in @('DEV-CHECKIN-MISSING', 'DEV-CHECKIN-STALE', 'DEV-ENROLMENT-NO-HEALTHY-CHECKIN', 'DEV-PRIMARY-USER-MISSING', 'DEV-ENTRA-CORRELATION', 'DEV-DUPLICATE-SERIAL', 'DEV-DUPLICATE-ENTRA-ID', 'DEV-COMPLIANCE-UNKNOWN', 'DEV-OS-VERSION-MISMATCH')) {
                $guide = Get-IntuneAccessResolutionGuide -Finding ([pscustomobject] @{ SourceType = 'DeviceHygiene'; SourceId = $rule })
                $guide.ExecutionAllowed | Should -BeFalse
                foreach ($field in @('PotentialImpact', 'RecommendedChecks', 'SuggestedFix', 'Prerequisites', 'PilotRecommendation', 'Risks', 'Verification', 'Recovery', 'Reference')) {
                    $guide.$field | Should -Not -BeNullOrEmpty
                }
            }
        }
        It 'only identifies missing required outcomes for an included required path' {
            $assignment = [pscustomobject] @{ DeviceId = 'd'; DeviceName = 'PC'; WorkloadId = 'app'; WorkloadName = 'Application'; WorkloadType = 'Applications'; AssignmentState = 'Included'; ReportedOutcomeState = 'NoReportedEvidence'; AssignmentPaths = @([pscustomobject] @{ Intent = 'required'; PathState = 'Included' }) }
            $collection = [pscustomobject] @{ DeviceAssignmentExplanations = @($assignment) }
            $result = Get-IntuneAccessActionCentre -Collection $collection
            $result.Findings.Count | Should -Be 1
            $result.Findings[0].Explanation | Should -Match 'not a proven installation failure'
            $assignment.AssignmentState = 'Excluded'
            @( (Get-IntuneAccessActionCentre -Collection $collection).Findings ).Count | Should -Be 0
        }
        It 'retains both policy values and identities for a consolidation proposal' {
            $conflict = [pscustomobject] @{ Id = 'conflict'; SettingDefinitionId = 'setting'; FirstPolicyId = 'p1'; FirstPolicyName = 'Policy 1'; FirstValueJson = 'true'; SecondPolicyId = 'p2'; SecondPolicyName = 'Policy 2'; SecondValueJson = 'false'; FindingState = 'PotentialConflict'; Reason = 'Exact target overlap' }
            $result = Get-IntuneAccessActionCentre -Collection ([pscustomobject] @{ PolicyConflictFindings = @($conflict) })
            $result.Findings[0].AffectedObjects.Count | Should -Be 2
            $result.Findings[0].Evidence.SecondValueJson | Should -Be 'false'
            $result.Findings[0].ResolutionGuide.SuggestedFix | Should -Match 'consolidation'
        }
        It 'escapes closing script tags in tenant evidence and includes offline controls' {
            $finding = [pscustomobject] @{ FindingId = 'f'; Title = '</script><script>alert(1)</script>'; DeviceName = 'PC'; SourceType = 'DeviceHygiene'; SourceId = 'DEV-CHECKIN-STALE'; PriorityScore = 75; Severity = 'High'; Explanation = 'Old'; ReviewRecommendation = 'Review' }
            $html = ConvertTo-IntuneAccessActionCentreHtml -Collection ([pscustomobject] @{ Tenant = @{ Id = 'tenant' }; EstateFindings = @($finding) })
            $html | Should -Not -Match '<script>alert\(1\)</script>'
            $html | Should -Match '\\u003c/script\\u003e'
            $html | Should -Match 'Export selected change plan'
            $html | Should -Match 'Mark expected locally'
            $html | Should -Match 'Export local decisions'
        }
    }
}
