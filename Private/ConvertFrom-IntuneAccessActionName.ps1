function ConvertFrom-IntuneAccessActionName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Action
    )

    $trimmed = $Action -replace '^Microsoft\.Intune_', ''
    $resource = 'Other'
    $operation = $trimmed

    if ($trimmed -match '^(.+)[_/]([^_/]+)$') {
        $resource = $Matches[1] -replace '_', ' '
        $operation = $Matches[2] -replace '_', ' '
    }

    $friendlyResource = [regex]::Replace($resource, '(?<=[a-z0-9])(?=[A-Z])', ' ')
    $friendlyOperation = [regex]::Replace($operation, '(?<=[a-z0-9])(?=[A-Z])', ' ')
    if ($friendlyOperation.Length -gt 0) {
        $friendlyOperation = $friendlyOperation.Substring(0, 1).ToUpperInvariant() + $friendlyOperation.Substring(1)
    }

    return [PSCustomObject] @{
        RawAction          = $Action
        Resource           = $friendlyResource
        Operation          = $friendlyOperation
        FriendlyActionName = "$friendlyResource / $friendlyOperation"
    }
}
