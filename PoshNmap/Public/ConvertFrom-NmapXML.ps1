using namespace newtonsoft.json
using namespace system.management.automation
function ConvertFrom-NmapXml {
<#
.SYNOPSIS
Converts NmapXML into various formats. Currently supported are JSON, PSObject, NmapReport
.NOTES
Only supports nmap reports piped from nmap directly. In the future will support existing full nmap reports
.EXAMPLE
nmap localhost -oX - | ConvertFrom-NmapXML -OutFormat JSON
Takes an NMAP run output and converts it into JSON
#>
    [CmdletBinding()]
    param (
        #Reads XML "Strings" one by one
        [Parameter(ValueFromPipeline)][String[]]$InputObject,

        #Choose the format that you want to convert the NMAPXML to. Valid options are: JSON or HashTable
        [ValidateSet('JSON','HashTable','PSObject','PoshNmap','Summary')]
        $OutFormat = 'PoshNmap'
    )

    begin {
        $xmlDocument = [Collections.ArrayList]@()
        $hostEntry = [Collections.ArrayList]@()
    }

    process {
        #Unwrap $InputObject if it was passed as an array
        foreach ($nmapLineItem in $inputObject) {
            #If the output format is not PoshNmap, we will coalesce into a single document and process at the end, otherwise we will do it in real time for the pipeline
            if ($OutFormat -ne 'PoshNmap') {
                $xmlDocument += $nmapLineItem
            #If this is a host entry, start capturing a host buffer
            } elseif ($nmapLineItem -match '^<host ') {
                $hostEntry += $nmapLineItem
            } elseif ($hostentry.count -ge 1) {
                if ($nmapLineItem -match '^</host>$') {
                    $hostEntry += $nmapLineItem
                    try {
                        (ConvertFromXml ([xml]$hostEntry).host).host | FormatPoshNmapHost
                    } finally {
                        $hostEntry = [Collections.ArrayList]@()
                    }
                } else {
                    $hostEntry += $nmapLineItem
                }
            }

            #If we are making a host entry, keep adding lines until we hit a </host> entry and then process it

        }
    }

    end {
        #If we don't have any post-processing, don't worry about it
        if (-not $xmlDocument) {continue}

        if ($xmlDocument -isnot [xml]) {
            try {
                $xmlDocument = [XML]$xmlDocument
            } catch [InvalidCastException] {
                $exception = [System.Management.Automation.PSInvalidCastException]::New("The input provided is not valid XML. If you are piping from nmap, did you use 'nmap -oX -'?")
                throwUser $exception
            }
        }

        if (-not $xmlDocument.nmaprun) {
            throwUser "The provided document is not a valid NMAP XML document (doesn't have an nmaprun element)"
        }

        $nmapRun = $xmlDocument.selectSingleNode('nmaprun')

        switch ($OutFormat) {
            'JSON' {
                ConvertFromXml $nmapRun -AsJSON
            }
            'PSObject' {
                (ConvertFromXml $nmapRun).nmaprun
            }
            'Summary' {
                FormatNmapOutputSummary -nmaprun (ConvertFromXml $nmapRun).nmaprun
            }
            'HashTable' {
                (ConvertFromXml $nmapRun).nmaprun | ConvertPSObjectToHashtable
            }
            Default {
                throwUser "Outformat $Outformat is not valid. This should not happen, file as an issue if you see this"
            }
        }
    }
}
