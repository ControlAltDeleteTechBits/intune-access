$modulePath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'IntuneAccess.psd1'
Import-Module $modulePath -Force

Describe 'Graph request handling' {
    InModuleScope IntuneAccess {
        BeforeEach {
            Mock Assert-IntuneAccessConnection { [PSCustomObject] @{ Account = 'tester@example.test' } }
        }

        It 'scenario 7: follows every pagination link' {
            Mock Invoke-MgGraphRequest {
                if ($Uri -eq 'https://graph.microsoft.com/v1.0/things') {
                    return [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'one' }); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/things?page=2' }
                }
                return [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'two' }) }
            }
            $result = @(Invoke-IntuneAccessGraphRequest -Uri 'things')
            $result.id | Should -Be @('one', 'two')
            Should -Invoke Invoke-MgGraphRequest -Times 2
        }

        It 'scenario 8: retries a throttled read' {
            $script:attempt = 0
            Mock Start-Sleep {}
            Mock Invoke-MgGraphRequest {
                $script:attempt++
                if ($script:attempt -eq 1) {
                    $response = [PSCustomObject] @{
                        StatusCode = 429
                        Headers = [PSCustomObject] @{
                            RetryAfter = [PSCustomObject] @{ Delta = [TimeSpan]::FromSeconds(7) }
                        }
                    }
                    $exception = [System.Exception]::new('Graph returned HTTP 429')
                    $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response
                    throw $exception
                }
                return [PSCustomObject] @{ value = @([PSCustomObject] @{ id = 'after-retry' }) }
            }
            $result = @(Invoke-IntuneAccessGraphRequest -Uri 'things' -MaxRetryCount 2)
            $result[0].id | Should -Be 'after-retry'
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -eq 7 }
        }

        It 'returns no records for an empty Graph collection' {
            Mock Invoke-MgGraphRequest {
                return [PSCustomObject] @{ value = @() }
            }

            $result = @(Invoke-IntuneAccessGraphRequest -Uri 'things')

            $result.Count | Should -Be 0
            Should -Invoke Invoke-MgGraphRequest -Times 1
        }
        It 'stops a repeated page instead of returning partial success' {
            Mock Invoke-MgGraphRequest {
                [PSCustomObject] @{value=@([PSCustomObject]@{id='one'});'@odata.nextLink'=$Uri}
            }
            {Invoke-IntuneAccessGraphRequest -Uri 'things'} | Should -Throw '*repeated pagination link*'
            Should -Invoke Invoke-MgGraphRequest -Times 1
        }
        It 'stops a multi-page cycle without making a third request' {
            Mock Invoke-MgGraphRequest {
                $next=if($Uri -eq 'https://graph.microsoft.com/v1.0/things'){'https://graph.microsoft.com/v1.0/things?page=2'}else{'https://graph.microsoft.com/v1.0/things'}
                [PSCustomObject] @{value=@([PSCustomObject]@{id='one'});'@odata.nextLink'=$next}
            }
            {Invoke-IntuneAccessGraphRequest -Uri 'things'} | Should -Throw '*partial results*'
            Should -Invoke Invoke-MgGraphRequest -Times 2
        }
    }
}
