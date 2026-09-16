function ConvertTo-IntuneAccessDeploymentOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $InputObject,
        [Parameter(Mandatory)] [object] $Workload,
        [Parameter(Mandatory)] [string] $ApiVersion,
        [Parameter(Mandatory)] [object[]] $ManagedDevice
    )

    $nestedDevice = Get-IntuneAccessProperty $InputObject 'managedDevice'
    $deviceId = [string] (Get-IntuneAccessProperty $InputObject 'deviceId' '')
    if ([string]::IsNullOrWhiteSpace($deviceId)) { $deviceId = [string] (Get-IntuneAccessProperty $nestedDevice 'id' '') }
    $deviceName = [string] (Get-IntuneAccessProperty $InputObject 'deviceName' '')
    if ([string]::IsNullOrWhiteSpace($deviceName)) { $deviceName = [string] (Get-IntuneAccessProperty $InputObject 'deviceDisplayName' '') }
    if ([string]::IsNullOrWhiteSpace($deviceName)) { $deviceName = [string] (Get-IntuneAccessProperty $nestedDevice 'deviceName' '') }
    $userPrincipalName = [string] (Get-IntuneAccessProperty $InputObject 'userPrincipalName' '')
    if ([string]::IsNullOrWhiteSpace($userPrincipalName)) { $userPrincipalName = [string] (Get-IntuneAccessProperty $nestedDevice 'userPrincipalName' '') }

    $state = ''
    foreach ($propertyName in @('status', 'installState', 'mobileAppInstallStatusValue', 'runState', 'detectionState', 'remediationState')) {
        $candidate = [string] (Get-IntuneAccessProperty $InputObject $propertyName '')
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { $state = $candidate; break }
    }
    if ([string]::IsNullOrWhiteSpace($state)) { $state = 'unknown' }

    $detail = ''
    foreach ($propertyName in @('installStateDetail', 'errorDescription', 'resultMessage', 'remediationScriptError', 'preRemediationDetectionScriptError', 'postRemediationDetectionScriptError')) {
        $candidate = [string] (Get-IntuneAccessProperty $InputObject $propertyName '')
        if (-not [string]::IsNullOrWhiteSpace($candidate)) { $detail = $candidate; break }
    }

    $errorCode = Get-IntuneAccessProperty $InputObject 'errorCode'
    $errorCodeHex = ''
    if ($null -ne $errorCode -and [long] $errorCode -ne 0) {
        # Decimal avoids older PowerShell parsing the hexadecimal mask as signed -1.
        $errorCodeHex = '0x{0:X8}' -f ([uint32] ([long] $errorCode -band 4294967295L))
    }

    $matchedDevice = $null
    $matchState = 'NotEvaluated'
    if (-not [string]::IsNullOrWhiteSpace($deviceId)) {
            $matchedDevice = $ManagedDevice | Where-Object Id -EQ $deviceId | Select-Object -First 1
        if ($null -ne $matchedDevice) { $matchState = 'MatchedById' }
    }
    if ($null -eq $matchedDevice -and -not [string]::IsNullOrWhiteSpace($deviceName)) {
        $nameMatches = @($ManagedDevice | Where-Object DeviceName -EQ $deviceName)
        if ($nameMatches.Count -eq 1) {
            $matchedDevice = $nameMatches[0]
            $matchState = 'MatchedByName'
        }
        elseif ($nameMatches.Count -gt 1) {
            $matchState = 'AmbiguousName'
        }
    }

    if ($null -ne $matchedDevice) {
        $deviceId = [string] $matchedDevice.Id
        $deviceName = [string] $matchedDevice.DeviceName
        if ([string]::IsNullOrWhiteSpace($userPrincipalName)) { $userPrincipalName = [string] $matchedDevice.UserPrincipalName }
    }

    $lastReported = $null
    foreach ($propertyName in @('lastStateUpdateDateTime', 'lastReportedDateTime', 'lastSyncDateTime')) {
        $candidate = Get-IntuneAccessProperty $InputObject $propertyName
        if ($null -ne $candidate -and -not [string]::IsNullOrWhiteSpace([string] $candidate)) { $lastReported = $candidate; break }
    }

    [PSCustomObject] @{
        PSTypeName        = 'IntuneAccess.DeploymentOutcome'
        Id                = [string] (Get-IntuneAccessProperty $InputObject 'id')
        WorkloadId        = [string] $Workload.Id
        WorkloadName      = [string] $Workload.Name
        WorkloadType      = [string] $Workload.WorkloadType
        SourceCollection  = [string] (Get-IntuneAccessProperty $Workload 'SourceCollection' '')
        DeviceId          = $deviceId
        DeviceName        = $deviceName
        UserPrincipalName = $userPrincipalName
        State             = $state
        Category          = Get-IntuneAccessOutcomeCategory -State $state
        StateDetail       = $detail
        ErrorCode         = $errorCode
        ErrorCodeHex      = $errorCodeHex
        LastReportedDateTime = $lastReported
        LastStateUpdateDateTime = Get-IntuneAccessProperty $InputObject 'lastStateUpdateDateTime'
        ExpectedStateUpdateDateTime = Get-IntuneAccessProperty $InputObject 'expectedStateUpdateDateTime'
        LastSyncDateTime   = Get-IntuneAccessProperty $InputObject 'lastSyncDateTime'
        DetectionState    = [string] (Get-IntuneAccessProperty $InputObject 'detectionState' '')
        RemediationState  = [string] (Get-IntuneAccessProperty $InputObject 'remediationState' '')
        PreRemediationDetectionScriptOutput = [string] (Get-IntuneAccessProperty $InputObject 'preRemediationDetectionScriptOutput' '')
        PreRemediationDetectionScriptError = [string] (Get-IntuneAccessProperty $InputObject 'preRemediationDetectionScriptError' '')
        RemediationScriptError = [string] (Get-IntuneAccessProperty $InputObject 'remediationScriptError' '')
        PostRemediationDetectionScriptOutput = [string] (Get-IntuneAccessProperty $InputObject 'postRemediationDetectionScriptOutput' '')
        PostRemediationDetectionScriptError = [string] (Get-IntuneAccessProperty $InputObject 'postRemediationDetectionScriptError' '')
        DeviceMatchState  = $matchState
        SourceApiVersion  = $ApiVersion
        EvidenceState     = 'Reported'
    }
}
