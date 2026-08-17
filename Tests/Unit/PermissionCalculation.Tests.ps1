$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Effective permission calculation' {
    InModuleScope IntuneAccess {
        BeforeAll {
            function New-TestAssignment {
                param(
                    [string] $Id,
                    [string] $Name,
                    [string[]] $Action,
                    [string] $Applicability = 'Confirmed',
                    [bool] $IsBuiltIn = $true
                )
                [PSCustomObject] @{
                    Id = $Id
                    Name = $Name
                    Applicability = $Applicability
                    Permissions = $Action
                    RoleDefinition = [PSCustomObject] @{ Id = "role-$Id"; DisplayName = "Role $Name"; IsBuiltIn = $IsBuiltIn }
                    AdminGroupEvidence = @([PSCustomObject] @{ GroupId = "group-$Id"; GroupName = "Group $Name" })
                    ScopeType = 'resourceScope'
                    RawIds = [PSCustomObject] @{ ScopeGroupIds = @("scope-$Id"); ScopeTagIds = @("tag-$Id") }
                }
            }
        }

        It 'scenario 1: resolves a complete single-assignment permission path' {
            $assignment = New-TestAssignment -Id '1' -Name 'UK Helpdesk' -Action 'Microsoft.Intune_ManagedDevices_Read'
            $result = @(Resolve-IntuneAccessPermissions -RoleAssignment $assignment)
            $result.Count | Should -Be 1
            $result[0].State | Should -Be 'Allowed'
            $result[0].Resource | Should -Be 'Managed Devices'
            $result[0].GrantedBy[0].RoleAssignmentName | Should -Be 'UK Helpdesk'
        }

        It 'scenario 2: unions permissions from two administrator groups' {
            $assignments = @(
                (New-TestAssignment -Id '1' -Name 'Read' -Action 'Microsoft.Intune_ManagedDevices_Read')
                (New-TestAssignment -Id '2' -Name 'Lock' -Action 'Microsoft.Intune_ManagedDevices_RemoteLock')
            )
            $result = @(Resolve-IntuneAccessPermissions -RoleAssignment $assignments)
            $result.RawAction | Should -Contain 'Microsoft.Intune_ManagedDevices_Read'
            $result.RawAction | Should -Contain 'Microsoft.Intune_ManagedDevices_RemoteLock'
        }

        It 'scenario 3: retains every source for a duplicate permission' {
            $assignments = @(
                (New-TestAssignment -Id '1' -Name 'First' -Action 'Microsoft.Intune_ManagedDevices_Read')
                (New-TestAssignment -Id '2' -Name 'Second' -Action 'Microsoft.Intune_ManagedDevices_Read')
            )
            $result = @(Resolve-IntuneAccessPermissions -RoleAssignment $assignments)
            $result.Count | Should -Be 1
            $result[0].IsDuplicate | Should -BeTrue
            $result[0].GrantedBy.Count | Should -Be 2
        }

        It 'scenario 4: reads custom-role actions without a built-in permission table' {
            $assignment = New-TestAssignment -Id '4' -Name 'Custom' -Action 'Contoso.Extension_Action_DoThing' -IsBuiltIn $false
            $result = @(Resolve-IntuneAccessPermissions -RoleAssignment $assignment)
            $result[0].RawAction | Should -Be 'Contoso.Extension_Action_DoThing'
            $result[0].State | Should -Be 'Allowed'
        }

        It 'scenario 6: preserves unknown applicability as NotEvaluated' {
            $assignment = New-TestAssignment -Id '6' -Name 'Nested' -Action 'Microsoft.Intune_ManagedDevices_Read' -Applicability 'NotEvaluated'
            $result = @(Resolve-IntuneAccessPermissions -RoleAssignment $assignment)
            $result[0].State | Should -Be 'NotEvaluated'
        }
    }
}
