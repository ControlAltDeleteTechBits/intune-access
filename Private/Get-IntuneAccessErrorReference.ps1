function Get-IntuneAccessErrorReference {
    <#
    Returns Microsoft's published meaning for a small set of Intune error codes.
    Every entry is taken from the Intune app installation error reference on Microsoft Learn.
    Unknown codes return $null; callers must not invent a meaning.
    #>
    [CmdletBinding()]
    param([AllowNull()] [object] $ErrorCode)

    if ($null -eq $ErrorCode -or [string]::IsNullOrWhiteSpace([string] $ErrorCode)) { return $null }

    $hex = ''
    $text = ([string] $ErrorCode).Trim()
    $number = 0L
    if ($text -match '^0x[0-9a-f]{1,8}$') {
        $hex = ('0x{0:X8}' -f [Convert]::ToUInt32($text.Substring(2), 16))
    }
    elseif ([long]::TryParse($text, [ref] $number)) {
        if ($number -eq 0) { return $null }
        $hex = ('0x{0:X8}' -f [uint32] ($number -band 0xFFFFFFFFL))
    }
    else { return $null }

    $source = 'https://learn.microsoft.com/troubleshoot/mem/intune/app-management/app-install-error-codes'
    $reference = @{
        '0x87D1041C' = @{ Meaning = 'The application was not detected after installation completed successfully.'; NextCheck = 'Compare the app detection rule with what is actually on the device (registry view, file path, version and install context). Microsoft also lists user uninstall and self-updating apps as causes.' }
        '0x87D13B66' = @{ Meaning = 'The app is managed, but has expired or been removed by the user (iOS/iPadOS).'; NextCheck = 'Check whether the user removed the app, whether the app licence or download expired, and whether app detection matches the device response.' }
        '0x87D13B64' = @{ Meaning = 'The app installation has failed (iOS/iPadOS).'; NextCheck = 'Collect iOS/iPadOS console logs; Microsoft states they are needed to troubleshoot this error.' }
        '0x87D13B7D' = @{ Meaning = 'Unknown app installation error (iOS/iPadOS).'; NextCheck = 'Microsoft recommends checking that the Apple Volume Purchase Program token is current and functional.' }
        '0x80073CF3' = @{ Meaning = 'The package failed update, dependency or conflict validation.'; NextCheck = 'Check the AppXDeployment-Server event log on the device for the conflicting or missing dependency.' }
        '0x80073CFB' = @{ Meaning = 'The provided package is already installed, and reinstallation of the package is blocked.'; NextCheck = 'Increment the package version or remove the existing package for every user before reinstalling.' }
        '0x8000FFFF' = @{ Meaning = 'An unexpected error occurred during installation.'; NextCheck = 'Check the installation logs on the device; the code alone does not identify the cause.' }
    }

    if (-not $reference.ContainsKey($hex)) {
        return [PSCustomObject] @{ Hex = $hex; Meaning = ''; NextCheck = 'This code is not in the IntuneAccess reference. Search Microsoft Learn for the hexadecimal value and check device-side logs.'; Source = ''; State = 'NotInReference' }
    }
    [PSCustomObject] @{ Hex = $hex; Meaning = $reference[$hex].Meaning; NextCheck = $reference[$hex].NextCheck; Source = $source; State = 'PublishedReference' }
}
