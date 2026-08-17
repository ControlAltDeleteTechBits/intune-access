@{
    Severity = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        # Export is protected by ShouldProcess. Connection state is delegated to the Graph SDK.
        'PSUseShouldProcessForStateChangingFunctions',
        # Collection-oriented private helpers follow the names in the published architecture.
        # Every exported command uses a singular noun.
        'PSUseSingularNouns'
    )
}
