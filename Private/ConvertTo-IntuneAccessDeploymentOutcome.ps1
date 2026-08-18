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
        $errorCodeHex = '0x{0:X8}' -f ([uint32] ([long] $errorCode -band 0xffffffffL))
    }

    $matchedDevice = $null
    $matchState = 'NotEvaluated'
    if (-not [string]::IsNullOrWhiteSpace($deviceId)) {
        $matchedDevice = @($ManagedDevice | Where-Object Id -EQ $deviceId | Select-Object -First 1)[0]
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
    foreach ($propertyName in @('lastReportedDateTime', 'lastSyncDateTime', 'lastStateUpdateDateTime')) {
        $candidate = Get-IntuneAccessProperty $InputObject $propertyName
        if ($null -ne $candidate -and -not [string]::IsNullOrWhiteSpace([string] $candidate)) { $lastReported = $candidate; break }
    }

    [PSCustomObject] @{
        PSTypeName        = 'IntuneAccess.DeploymentOutcome'
        Id                = [string] (Get-IntuneAccessProperty $InputObject 'id')
        WorkloadId        = [string] $Workload.Id
        WorkloadName      = [string] $Workload.Name
        WorkloadType      = [string] $Workload.WorkloadType
        DeviceId          = $deviceId
        DeviceName        = $deviceName
        UserPrincipalName = $userPrincipalName
        State             = $state
        Category          = Get-IntuneAccessOutcomeCategory -State $state
        StateDetail       = $detail
        ErrorCode         = $errorCode
        ErrorCodeHex      = $errorCodeHex
        LastReportedDateTime = $lastReported
        DeviceMatchState  = $matchState
        SourceApiVersion  = $ApiVersion
        EvidenceState     = 'Reported'
    }
}
