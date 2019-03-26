using namespace Newtonsoft.Json
function ConvertFromXML {
#TODO: This requires newtonsoft.json. Present in 6.1 but add a check for 5.1
<#
.SYNOPSIS
Uses the newtonsoft.json library to convert XML into an intermediate object. Supports PSObject (Default) and JSON
#>
    [CmdletBinding()]
    param (
        #The XML to convert to an object
        [Parameter(ValueFromPipeline)][XML.XMLElement]$Xml,
        #Output as JSON instead of just PSObject
        [Switch]$AsJSON,
        #Use the raw element processings that newtonsoft.json uses. Only need this if you have conflicting names between your attributes and elements
        [Switch]$Raw
    )

    $json = [JsonConvert]::SerializeXmlNode($Xml,'Indented')

    if (-not $Raw) {
        [Regex]$MatchConvertedAmpersand = '(?m)(?<=\s+\")(@)(?=.+\"\:)'
        $convertedJson = $json -replace $MatchConvertedAmpersand,''
    }


    if ($AsJson) {return $convertedJson}

    return ConvertFrom-Json $convertedJson

}