function Invoke-IntuneAccessGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [ValidateSet('v1.0', 'beta')] [string] $ApiVersion = 'v1.0',
        [ValidateRange(0, 10)] [int] $MaxRetryCount = 4,
        [switch] $SingleObject
    )

    $null = Assert-IntuneAccessConnection
    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw 'Invoke-MgGraphRequest is unavailable. Import Microsoft.Graph.Authentication and reconnect.'
    }

    $nextUri = if ($Uri -match '^https://graph\.microsoft\.com/') {
        $Uri
    }
    else {
        "https://graph.microsoft.com/$ApiVersion/$($Uri.TrimStart('/'))"
    }

    $items = [System.Collections.Generic.List[object]]::new()

    do {
        $attempt = 0
        while ($true) {
            try {
                Write-Verbose "GET $nextUri"
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri -OutputType PSObject
                break
            }
            catch {
                $statusCode = 0
                $responseProperty = $_.Exception.PSObject.Properties['Response']
                $errorResponse = if ($null -ne $responseProperty) { $responseProperty.Value } else { $null }
                $statusProperty = if ($null -ne $errorResponse) { $errorResponse.PSObject.Properties['StatusCode'] } else { $null }
                if ($null -ne $statusProperty -and $null -ne $statusProperty.Value) {
                    $statusCode = [int] $statusProperty.Value
                }
                elseif ($_.Exception.Message -match '\b(401|403|429|5\d\d)\b') {
                    $statusCode = [int] $Matches[1]
                }

                if ($statusCode -eq 401) {
                    throw 'Microsoft Graph rejected the session (HTTP 401). The token may have expired. Run Connect-IntuneAccess again.'
                }
                if ($statusCode -eq 403) {
                    throw "Microsoft Graph denied this read request (HTTP 403): $nextUri. Check Graph consent and the signed-in administrator's Intune permissions."
                }

                $retryable = $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -lt 600)
                if (-not $retryable -or $attempt -ge $MaxRetryCount) {
                    throw "Microsoft Graph read failed for $nextUri. $($_.Exception.Message)"
                }

                $retryAfter = 0
                $headersProperty = if ($null -ne $errorResponse) { $errorResponse.PSObject.Properties['Headers'] } else { $null }
                if ($null -ne $headersProperty -and $null -ne $headersProperty.Value) {
                    $retryAfterProperty = $headersProperty.Value.PSObject.Properties['RetryAfter']
                    $header = if ($null -ne $retryAfterProperty) { $retryAfterProperty.Value } else { $null }
                    $deltaProperty = if ($null -ne $header) { $header.PSObject.Properties['Delta'] } else { $null }
                    if ($null -ne $deltaProperty -and $null -ne $deltaProperty.Value) {
                        $retryAfter = [int] [Math]::Ceiling($deltaProperty.Value.TotalSeconds)
                    }
                }
                if ($retryAfter -le 0) {
                    $retryAfter = [Math]::Min(2 * [Math]::Pow(2, $attempt), 30)
                }

                $attempt++
                Write-Verbose "Graph returned HTTP $statusCode. Retrying in $retryAfter second(s), attempt $attempt of $MaxRetryCount."
                Start-Sleep -Seconds $retryAfter
            }
        }

        $valuePropertyExists = if ($response -is [System.Collections.IDictionary]) {
            $response.Contains('value')
        }
        else {
            $null -ne $response.PSObject.Properties['value']
        }
        $value = Get-IntuneAccessProperty -InputObject $response -Name 'value'
        if ($valuePropertyExists -and -not $SingleObject) {
            foreach ($item in @($value)) {
                $items.Add($item)
            }
        }
        else {
            $items.Add($response)
        }

        $nextLink = Get-IntuneAccessProperty -InputObject $response -Name '@odata.nextLink'
        if ($SingleObject) {
            $nextLink = $null
        }
        $nextUri = [string] $nextLink
    } while (-not [string]::IsNullOrWhiteSpace($nextUri))

    return $items.ToArray()
}
