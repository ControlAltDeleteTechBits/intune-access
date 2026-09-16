function Restore-IntuneAccessJsonStrings {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Element,[AllowNull()]$Target)
    if($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object){
        foreach($entry in $Element.EnumerateObject()){
            $property=$Target.PSObject.Properties[$entry.Name]
            if($null -eq $property){continue}
            if($entry.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::String){$property.Value=$entry.Value.GetString()}
            else {Restore-IntuneAccessJsonStrings -Element $entry.Value -Target $property.Value}
        }
    } elseif($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array){
        $position=0
        foreach($entry in $Element.EnumerateArray()){
            if($entry.ValueKind -eq [System.Text.Json.JsonValueKind]::String){$Target[$position]=$entry.GetString()}
            else {Restore-IntuneAccessJsonStrings -Element $entry -Target $Target[$position]}
            $position++
        }
    }
}

function ConvertFrom-IntuneAccessSnapshotJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Json,[switch]$CompatibilityParser)
    if(-not $CompatibilityParser -and (Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')){
        return ConvertFrom-Json -InputObject $Json -Depth 50 -DateKind String
    }
    # Older PowerShell versions parse ISO date strings automatically. Restore all
    # string tokens from the original JSON, retaining the normal numeric parser.
    $result=ConvertFrom-Json -InputObject $Json -Depth 50
    $options=[System.Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth=50
    $document=[System.Text.Json.JsonDocument]::Parse($Json,$options)
    try {
        if($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object){throw 'Snapshot JSON must be an object.'}
        Restore-IntuneAccessJsonStrings -Element $document.RootElement -Target $result
    } finally {$document.Dispose()}
    $result
}
