function Get-IntuneAccessAuditEvents {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 90)] [int] $Days = 30
    )

    $null = Assert-IntuneAccessConnection -RequiredScope @('DeviceManagementApps.Read.All')
    $since = [DateTimeOffset]::UtcNow.AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $uri = "deviceManagement/auditEvents?`$filter=activityDateTime ge $since&`$top=100"
    $events = [Collections.Generic.List[object]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $state = 'Available'
    try {
        foreach ($auditRecord in @(Invoke-IntuneAccessGraphRequest -Uri $uri -ApiVersion v1.0)) {
            $actor = Get-IntuneAccessProperty $auditRecord 'actor'
            $resources = @(
                foreach ($resource in @(Get-IntuneAccessProperty $auditRecord 'resources' @())) {
                    [PSCustomObject] @{
                        ResourceId         = [string] (Get-IntuneAccessProperty $resource 'resourceId' '')
                        DisplayName        = [string] (Get-IntuneAccessProperty $resource 'displayName' '')
                        Type               = [string] (Get-IntuneAccessProperty $resource 'type' '')
                        AuditResourceType  = [string] (Get-IntuneAccessProperty $resource 'auditResourceType' '')
                        ModifiedProperties = @(
                            foreach ($property in @(Get-IntuneAccessProperty $resource 'modifiedProperties' @())) {
                                [PSCustomObject] @{
                                    DisplayName = [string] (Get-IntuneAccessProperty $property 'displayName' '')
                                    OldValue    = [string] (Get-IntuneAccessProperty $property 'oldValue' '')
                                    NewValue    = [string] (Get-IntuneAccessProperty $property 'newValue' '')
                                }
                            }
                        )
                    }
                }
            )
            $events.Add([PSCustomObject] @{
                PSTypeName            = 'IntuneAccess.AuditEvent'
                Id                    = [string] (Get-IntuneAccessProperty $auditRecord 'id' '')
                DisplayName           = [string] (Get-IntuneAccessProperty $auditRecord 'displayName' '')
                ComponentName         = [string] (Get-IntuneAccessProperty $auditRecord 'componentName' '')
                Activity              = [string] (Get-IntuneAccessProperty $auditRecord 'activity' '')
                ActivityDateTime      = Get-IntuneAccessProperty $auditRecord 'activityDateTime'
                ActivityType          = [string] (Get-IntuneAccessProperty $auditRecord 'activityType' '')
                ActivityOperationType = [string] (Get-IntuneAccessProperty $auditRecord 'activityOperationType' '')
                ActivityResult        = [string] (Get-IntuneAccessProperty $auditRecord 'activityResult' '')
                Category              = [string] (Get-IntuneAccessProperty $auditRecord 'category' '')
                CorrelationId         = [string] (Get-IntuneAccessProperty $auditRecord 'correlationId' '')
                ActorUserPrincipalName = [string] (Get-IntuneAccessProperty $actor 'userPrincipalName' '')
                ActorApplication      = [string] (Get-IntuneAccessProperty $actor 'applicationDisplayName' '')
                ActorIpAddress        = [string] (Get-IntuneAccessProperty $actor 'ipAddress' '')
                Resources             = $resources
                ResourceIds           = @($resources.ResourceId | Where-Object { $_ } | Select-Object -Unique)
                SourceApiVersion      = 'v1.0'
                EvidenceState         = 'ReportedAuditEvent'
            })
        }
    }
    catch {
        $state = 'Unavailable'
        $warnings.Add("Intune audit events could not be collected. $($_.Exception.Message)")
    }

    [PSCustomObject] @{
        PSTypeName       = 'IntuneAccess.AuditEvidence'
        Events           = @($events | Sort-Object ActivityDateTime -Descending)
        CollectionStatus = [PSCustomObject] @{ State = $state; EventCount = $events.Count; Days = $Days; SourceApiVersion = 'v1.0'; Reason = if ($warnings.Count) { $warnings[0] } else { '' } }
        Warnings         = $warnings.ToArray()
        GraphPermissionsUsed = @('DeviceManagementApps.Read.All')
        ReadOnly         = $true
        GeneratedAt      = [DateTimeOffset]::Now
        ToolVersion      = $script:IntuneAccessVersion
    }
}
