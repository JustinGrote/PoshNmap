

function FormatNmapOutput {
<#
.SYNOPSIS
Takes the raw formatting from ConvertFrom-NmapXML and makes a useful Powershell Object out of the output. Meant to be called from ConvertFrom-NmapXml
.INPUTS
[PSCustomObject]
.OUTPUTS
[PoshNmapResult]
.NOTES
The raw formatting is still available as the nmaprun property on the object, to maintain compatibility
#>

    [CmdletBinding()]
    param (
        #Nmaprun output from ConvertFrom-NmapXml. Should basically be XML -> Json -> PSObject output
        [Parameter(ValueFromPipeline)][PSCustomObject]$InputNmapObject,
        #Return a summary of the scan rather than individual hosts
        [Switch]$Summary
    )

    if (-not $inputNmapObject.nmaprun) {throwUser "This is not a valid Object output from Convert-NmapXML"}
    $nmaprun = $inputNmapObject.nmaprun

    #Only return a summary if that was requested
    if ($summary) {return (FormatNmapOutputSummary $nmapRun)}

    #Generate nicer host entries
    $i=1
    $itotal = $nmaprun.host | measure | % count
    foreach ($hostnode in $nmaprun.host) {
        write-progress -Activity "Parsing NMAP Result" -Status "Processing Scan Entries" -CurrentOperation "Processing $i of $itotal" -PercentComplete (($i/$itotal)*100)
        FormatPoshNmapHost $hostnode
    }
}