function Invoke-Nmap {
    <#
    .SYNOPSIS
        Runs the NMAP command and then formats the output.
    .EXAMPLE
        Invoke-Nmap www.google.com
        Runs an NMAP scan of www.google.com and provides the results as powershell objects
    .INPUTS
        [String[]]$ComputerName
    .OUTPUTS
        [PoshNMAP.NMAPResult]
    #>

    [CmdletBinding(DefaultParameterSetName="default")]
    param (
        #A list of nmap host specifications
        [String[]][Parameter(Position=0,ParameterSetName="Default",ValueFromPipeline)]$computerName = "localhost",
        #A list of SNMP communities to scan. Defaults to public and private
        [String[]][Parameter(ParameterSetName="Default")]$snmpCommunityList = @("private","public"),
        #Specify this if you want the raw (non-Powershell-formatted) NMAP Output
        [Switch]$Raw,
        #Override the default nmap parameters
        $ArgumentList = @(
            "--open",
            "-T4",
            "-F"
        )
    )

    if ($snmpCommunityList) {
        $snmpCommunityFile = [io.path]::GetTempFileName()
        $snmpCommunityList > $snmpCommunityFile
        $argumentList += '--script','snmp-brute','--script-args',"snmpbrute.communitiesdb=$snmpCommunityFile"
    }
    $nmapexe = 'nmap.exe'

    if (-not $Raw) {
        $ArgumentList += "-oX","-"
    }

    $nmapresult = Invoke-NmapExe $nmapExe $argumentList $computerName

    if (-not $nmapResult) {throw "NMAP did not produce any output. Please review any errors that are present above this warning."}
    if ($Raw) {
        $nmapResult
    } else {
        [xml]$nmapresult | ConvertFrom-NmapXML -Format HashTable | % nmaprun
    }
    Remove-Item $snmpCommunityFile -Force -ErrorAction SilentlyContinue
}
