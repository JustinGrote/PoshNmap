Register-ArgumentCompleter -CommandName "Invoke-Nmap" -ParameterName "Preset" -ScriptBlock {(Get-NmapPresetArguments).keys}

function Invoke-Nmap {
    <#
    .SYNOPSIS
        Runs the NMAP command and then formats the output.
    .INPUTS
        [String[]]$ComputerName
    .OUTPUTS
        Depends on -OutFormat parameter
    .EXAMPLE
        Invoke-Nmap scanme.nmap.org
        Runs an NMAP scan with the Quick scan preset and provides the result as a formatted Powershell Object
    .EXAMPLE
        Invoke-Nmap scanme.nmap.org "-t4 -p 80,443"
        This is similar to running nmap "bare" but enjoy the format processing of invoke-nmap

    #>

    [CmdletBinding(DefaultParameterSetName="preset")]
    param (
        #A list of nmap host specifications. Defaults to localhost
        [Parameter(
            Position=0,
            ValueFromPipeline
        )]
        [String[]]
        $computerName = "localhost",

        #Specify raw argument parameters to nmap
        [String[]]
        [Parameter(
            ParameterSetName="custom",
            Mandatory,
            Position=1
        )]
        $ArgumentList,

        [String]
        [Parameter(
            ParameterSetName="preset",
            ValueFromPipeline
        )]
        [String]$Preset = "Quick",

        #Choose which format for the output (XML, JSON, HashTable, PSObject, or Raw). Default is PSObject
        [ValidateSet('Raw','PSObject','XML','JSON','Hashtable')]
        [String]$OutFormat = 'PSObject',

        #A list of SNMP communities to scan. Defaults to public and private
        [String[]]
        [Parameter()]
        $snmpCommunityList = @("private","public")
    )

    if ($Preset) {
        $nmapPresetArgumentNames = (Get-NmapPresetArguments).keys
        if ($Preset -notin $nmapPresetArgumentNames) {
            throwUser New-Object ArgumentException -ArgumentList "Invoke-Nmap: Value $Preset is not a valid choice. Please choose one of: $($nmapPresetArgumentNames -join ', ')","Preset"
        } else {
            $ArgumentList = Get-NmapPresetArguments $Preset
        }
    }

    if ($snmpCommunityList) {
        $snmpCommunityFile = [io.path]::GetTempFileName()
        $snmpCommunityList > $snmpCommunityFile
        $argumentList += '--script','snmp-brute','--script-args',"snmpbrute.communitiesdb=$snmpCommunityFile"
    }
    $nmapexe = 'nmap.exe'

    if ($OutFormat -eq 'Raw') {
        Invoke-NmapExe $nmapExe $argumentList $computerName
        exit $LASTEXITCODE
    }

    $ArgumentList += "-oX","-"
    try {
        [String]$nmapresult = Invoke-NmapExe $nmapExe $argumentList $computerName
    } finally {
        if (Test-Path $snmpCommunityFile) {Remove-Item $snmpCommunityFile -Force -ErrorAction SilentlyContinue}
    }


    if (-not $nmapResult) {throwUser "NMAP did not produce any output. Please review any errors that are present above this warning."}
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
}
