#Register-ArgumentCompleter -CommandName "Invoke-Nmap" -ParameterName "Preset" -ScriptBlock {[PoshNmapPresetArguments].GetEnumNames()}
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
`
    [CmdletBinding(DefaultParameterSetName="preset")]
    param (
        #A list of nmap host specifications
        [Parameter(
            Position=0,
            ValueFromPipeline
        )]
        [String[]]
        $computerName = "localhost",

        #Override the default nmap parameters
        [String[]]
        [Parameter(
            Position=1,
            ParameterSetName="custom"
        )]
        $ArgumentList = (Get-NmapPresetArguments -Preset 'Quick'),

        [String[]]
        [Parameter(
            ParameterSetName="preset",
            ValueFromPipeline
        )]
        $Preset = "Quick",

        #A list of SNMP communities to scan. Defaults to public and private
        [String[]]
        [Parameter()]
        $snmpCommunityList = @("private","public"),

        #Choose which format for the output (XML, JSON, HashTable, or PSObject). Default is PSObject
        [ValidateSet('PSObject','XML','JSON','Hashtable')]
        [String]$OutFormat = 'PSObject'
    )

    if ($Preset) {
        $ArgumentList = Get-NmapPresetArguments $Preset
    }

    if ($snmpCommunityList) {
        $snmpCommunityFile = [io.path]::GetTempFileName()
        $snmpCommunityList > $snmpCommunityFile
        $argumentList += '--script','snmp-brute','--script-args',"snmpbrute.communitiesdb=$snmpCommunityFile"
    }
    $nmapexe = 'nmap.exe'

    if (-not $Raw) {
        $ArgumentList += "-oX","-"
    }

    [String]$nmapresult = Invoke-NmapExe $nmapExe $argumentList $computerName

    if (-not $nmapResult) {throw "NMAP did not produce any output. Please review any errors that are present above this warning."}
    switch ($OutFormat) {
        'XML' {
            $nmapResult
        }
        'JSON' {
            $nmapResult | ConvertFrom-NmapXML
        }
        'PSObject' {
            $nmapResult | ConvertFrom-NmapXML -OutFormat PSObject
        }
        'HashTable' {
            $nmapResult | ConvertFrom-NmapXML -OutFormat HashTable
        }
    }

    Remove-Item $snmpCommunityFile -Force -ErrorAction SilentlyContinue
}
