$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Intune audit evidence' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Scopes = @('DeviceManagementApps.Read.All') } }
        }

        It 'normalises actor, activity, resources and modified properties' {
            Mock Invoke-IntuneAccessGraphRequest {
                @([PSCustomObject] @{
                    id = 'audit-1'; displayName = 'Update policy'; componentName = 'DeviceConfiguration'; activity = 'Update device configuration'; activityDateTime = '2026-08-18T10:00:00Z'
                    activityType = 'Update'; activityOperationType = 'Update'; activityResult = 'Success'; correlationId = 'correlation-1'; category = 'DeviceConfiguration'
                    actor = [PSCustomObject] @{ userPrincipalName = 'admin@example.test'; applicationDisplayName = 'Microsoft Intune admin center'; ipAddress = '192.0.2.1' }
                    resources = @([PSCustomObject] @{ resourceId = 'policy-1'; displayName = 'Secure policy'; type = 'DeviceConfiguration'; auditResourceType = 'Policy'; modifiedProperties = @([PSCustomObject] @{ displayName = 'Assignments'; oldValue = 'Group A'; newValue = 'All devices' }) })
                })
            }

            $result = Get-IntuneAccessAuditEvents -Days 7

            $result.PSObject.TypeNames | Should -Contain 'IntuneAccess.AuditEvidence'
            $result.Events.Count | Should -Be 1
            $result.Events[0].ActorUserPrincipalName | Should -Be 'admin@example.test'
            $result.Events[0].ResourceIds | Should -Contain 'policy-1'
            $result.Events[0].Resources[0].ModifiedProperties[0].NewValue | Should -Be 'All devices'
            $result.CollectionStatus.State | Should -Be 'Available'
            Should -Invoke Invoke-IntuneAccessGraphRequest -ParameterFilter { $Uri -like 'deviceManagement/auditEvents*' -and $ApiVersion -eq 'v1.0' } -Times 1 -Exactly
        }

        It 'isolates an unavailable audit endpoint' {
            Mock Invoke-IntuneAccessGraphRequest { throw 'Simulated audit failure' }

            $result = Get-IntuneAccessAuditEvents

            $result.Events.Count | Should -Be 0
            $result.CollectionStatus.State | Should -Be 'Unavailable'
            $result.Warnings -join ' ' | Should -Match 'Simulated audit failure'
        }
    }
}
