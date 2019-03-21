using namespace newtonsoft.json
using namespace system.management.automation
function ConvertFrom-NmapXml {
<#
.SYNOPSIS
Converts NmapXML into various formats. Currently supported are JSON, PSObject, NmapReport
.EXAMPLE
nmap localhost -oX - | ConvertFrom-NmapXML -OutFormat JSON
Takes an NMAP run output and converts it into JSON

#>
    [CmdletBinding(DefaultParameterSetName="String")]
    param (
        #The NMAPXML content
        [Parameter(ParameterSetName='String',ValueFromPipeline)][String[]]$InputString,
        [Parameter(ParameterSetName='XML',ValueFromPipeline)][XML[]]$InputObject,

        #Choose the format that you want to convert the NMAPXML to. Valid options are: JSON or HashTable
        [ValidateSet('JSON','HashTable','PSObject','PoshNmap','Summary')]
        $OutFormat = 'JSON'
    )

    process {
        #If strings were passed via pipeline, assume it is output from nmap XML which is multiple lines and coalesce them into one large document.
        $InputObjectBundle += $InputString
    }

    end {
        try {
            [XML]$CombinedDocument = $InputObjectBundle
        } catch [InvalidCastException] {
            $exception = [System.Management.Automation.PSInvalidCastException]::New("The input provided is not valid XML. If you are piping from nmap, did you use 'nmap -oX -'?")
            throwUser $exception
        }

        if ($CombinedDocument) {$inputObject = $CombinedDocument}
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
                #TODO: PSCore Method, add as potential feature flag but for now use same method for both to avoid incompatibilities
                #$jsonResult | ConvertFrom-Json -AsHashtable
                return $jsonResult | ConvertFrom-Json | ConvertPSObjectToHashtable
            }
            'PoshNmap' {
                return $jsonResult | ConvertFrom-Json | FormatNmapXml
            }
            'Summary' {
                return $jsonResult | ConvertFrom-Json | FormatNmapXml -Summary
            }
        }
    }
}