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
        [Parameter(ValueFromPipeline)][XML[]]$InputObject,

        #Choose the format that you want to convert the NMAPXML to. Valid options are: JSON or HashTable
        [ValidateSet('JSON','HashTable','PSObject')]
        $OutFormat = 'JSON'
    )

    $jsonResult = foreach ($nmapXmlItem in $InputObject) {

        #Selecting NmapRun required for PS5.1 compatibility due to Newtonsoft.Json bug
        $nmapRunItem = ($nmapXmlItem).SelectSingleNode('nmaprun')

        #Indented JSON is important as we will use a regex to clean up the @ elements
        $convertedJson = [JsonConvert]::SerializeXmlNode($nmapRunItem,'Indented')

        #Remove @ symbols from xml attributes. There are no element/attribute collisions in the nmap xml (that we know of) so this should be OK.
        [Regex]$MatchConvertedAmpersand = '(?m)(?<=\s+\")(@)(?=.+\"\:)'
        $convertedJson = $convertedJson -replace $MatchConvertedAmpersand,''
        $convertedJson
    }

    switch ($OutFormat) {
        'JSON' {
            return $jsonResult
        }
        'PSObject' {
            return $jsonResult | ConvertFrom-Json
        }
        'HashTable' {
            #TODO: PSCore Method, add as potential feature flag
            #$jsonResult | ConvertFrom-Json -AsHashtable
            $nmapHashTable = $jsonResult | ConvertFrom-Json | ConvertPSObjectToHashtable
            return $nmapHashTable
        }
    }
}