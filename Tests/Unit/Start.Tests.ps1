$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Guided IntuneAccess workflow' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Connect-IntuneAccess {
                [PSCustomObject] @{
                    Account = 'signed.in@example.test'
                    ReadOnly = $true
                }
            }
            Mock Get-IntuneAccessTenantRbac {
                [PSCustomObject] @{
                    Tenant = [PSCustomObject] @{ DisplayName = 'Example tenant' }
                    Administrators = @(1, 2)
                    RoleAssignments = @(1, 2, 3)
                    WorkloadObjects = @(1, 2, 3, 4)
                    WorkloadAssignments = @(1, 2, 3, 4, 5)
                }
            }
            Mock Export-IntuneAccessReport {
                [PSCustomObject] @{ FullName = $Path }
            }
            Mock Export-IntuneAccessSnapshot {
                [PSCustomObject] @{ FullName = $Path }
            }
            Mock Compare-IntuneAccessSnapshot {
                [PSCustomObject] @{ PSTypeName = 'IntuneAccess.SnapshotComparison'; Changes = @(1, 2) }
            }
            Mock Invoke-Item {}
        }

        It 'connects, collects tenant RBAC data, exports the explorer and opens it' {
            $path = Join-Path $TestDrive 'explicit-user.html'

            $result = Start-IntuneAccess `
                -UserPrincipalName 'helpdesk@example.test' `
                -Path $path `
                -Force

            Should -Invoke Connect-IntuneAccess -Times 1 -Exactly -ParameterFilter { $Feature -contains 'Core' }
            Should -Invoke Connect-IntuneAccess -Times 1 -Exactly -ParameterFilter { $Feature -contains 'AssignmentExplorer' }
            Should -Invoke Connect-IntuneAccess -Times 1 -Exactly -ParameterFilter { $Feature -contains 'OperationalEvidence' }
            Should -Invoke Connect-IntuneAccess -Times 1 -Exactly -ParameterFilter { $Feature -contains 'PolicyAnalysis' }
            Should -Invoke Connect-IntuneAccess -Times 1 -Exactly -ParameterFilter { $Feature -contains 'AuditEvidence' }
            Should -Invoke Get-IntuneAccessTenantRbac -Times 1 -Exactly -ParameterFilter { $InitialUserPrincipalName -eq 'helpdesk@example.test' -and $IncludeWorkloadAssignments -and $IncludeOperationalEvidence -and $IncludePolicyAnalysis -and $IncludeAuditEvidence }
            Should -Invoke Export-IntuneAccessReport -Times 1 -Exactly -ParameterFilter { $Path -eq $path -and $Force }
            Should -Invoke Invoke-Item -Times 1 -Exactly -ParameterFilter { $LiteralPath -eq $path }
            $result.Tenant | Should -Be 'Example tenant'
            $result.Administrators | Should -Be 2
            $result.RoleAssignments | Should -Be 3
            $result.WorkloadObjects | Should -Be 4
            $result.WorkloadAssignments | Should -Be 5
            $result.ReportPath | Should -Be $path
            $result.Opened | Should -BeTrue
            $result.ReadOnly | Should -BeTrue
            $result.ToolVersion | Should -Be '2.0.1'
        }

        It 'saves and compares snapshots before rendering the explorer' {
            $path = Join-Path $TestDrive 'current.html'
            $snapshotPath = Join-Path $TestDrive 'current.snapshot.json'
            $baselinePath = Join-Path $TestDrive 'baseline.snapshot.json'

            $result = Start-IntuneAccess -Path $path -SnapshotPath $snapshotPath -BaselineSnapshotPath $baselinePath -NoOpen -Force

            Should -Invoke Export-IntuneAccessSnapshot -Times 1 -Exactly -ParameterFilter { $Path -eq $snapshotPath -and $Force }
            Should -Invoke Compare-IntuneAccessSnapshot -Times 1 -Exactly -ParameterFilter { $ReferencePath -eq $baselinePath -and $DifferencePath -eq $snapshotPath }
            Should -Invoke Export-IntuneAccessReport -Times 1 -Exactly
            $result.SnapshotPath | Should -Be $snapshotPath
            $result.SnapshotChanges | Should -Be 2
        }

        It 'uses the signed-in account as the initial explorer selection' {
            $path = Join-Path $TestDrive 'signed-in-user.html'

            $result = Start-IntuneAccess -Path $path -NoOpen

            Should -Invoke Get-IntuneAccessTenantRbac -Times 1 -Exactly -ParameterFilter { $InitialUserPrincipalName -eq 'signed.in@example.test' }
            Should -Invoke Invoke-Item -Times 0 -Exactly
            $result.Opened | Should -BeFalse
        }
    }
}
