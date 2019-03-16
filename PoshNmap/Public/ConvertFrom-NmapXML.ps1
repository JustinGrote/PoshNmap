using namespace newtonsoft.json

function ConvertFrom-NmapXml {
<#
.SYNOPSIS
Converts NmapXML into various formats. Currently supported are JSON, PSObject, NmapReport
.EXAMPLE
nmap localhost -oX - | ConvertFrom-NmapXML
#>
    [CmdletBinding()]
    param (
        #The NMAPXML content
        [Parameter(ValueFromPipeline)][XML]$InputObject,

        #Choose the format that you want to convert the NMAPXML to. Valid options are: JSON or HashTable
        [ValidateSet('JSON','HashTable')]
        $Format = 'JSON'
    )

    $jsonResult = foreach ($nmapXmlItem in $InputObject) {
        #Indented JSON is important as we will use a regex to clean up the @ elements
        $convertedJson = [JsonConvert]::SerializeXmlNode($nmapXmlItem,'Indented')

        #Remove @ symbols from xml attributes. There are no element/attribute collisions in the nmap xml (that we know of) so this should be OK.
        [Regex]$MatchConvertedAmpersand = '(?m)(?<=\s+\")(@)(?=.+\"\:)'
        $convertedJson = $convertedJson -replace $MatchConvertedAmpersand,''
        $convertedJson
    }
    if ($Format -eq 'HashTable') {
        $jsonResult | ConvertFrom-Json -AsHashtable
    } else {
        $jsonResult
    }
}