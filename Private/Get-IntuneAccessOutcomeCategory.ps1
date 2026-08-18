function Get-IntuneAccessOutcomeCategory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()] [string] $State
    )

    $normalisedState = ([string] $State).ToLowerInvariant()
    switch ($normalisedState) {
        { $_ -in @('success', 'installed', 'compliant', 'remediated') } { return 'Success' }
        { $_ -in @('failed', 'fail', 'error', 'noncompliant', 'conflict', 'scripterror', 'remediationfailed', 'uninstallfailed') } { return 'Error' }
        { $_ -in @('pending', 'pendinginstall', 'notinstalled') } { return 'Pending' }
        { $_ -in @('notapplicable', 'skipped', 'notassigned') } { return 'Not applicable' }
        default { return 'Unknown' }
    }
}
