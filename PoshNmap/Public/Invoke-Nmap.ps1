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
        [Parameter(
            ParameterSetName="custom",
            Mandatory,
            Position=1
        )]
        [String[]]
        $ArgumentList,

        [String]
        [Parameter(
            ParameterSetName="preset",
            ValueFromPipeline
        )]
        [String]$Preset = "Quick",

        #Choose which format for the output (XML, JSON, HashTable, PSObject, or Raw). Default is PSObject
        [ValidateSet('PoshNmap','Summary','Raw','PSObject','XML','JSON','Hashtable')]
        [String]$OutFormat = 'PoshNmap',

        #Show all results, not just online hosts
        [Switch]$All,

        #Perform an SNMP community scan. This is also done automatically with the "snmp" preset
        [Switch]$Snmp,

        #A list of SNMP communities to scan. Defaults to public and private
        [String[]]
        [Parameter()]
        $snmpCommunityList = @("public","private"),

        #Run one or more nmap scripts along with the operation
        [String[]]$Script,

        #Supply arguments to those scripts
    )

    if ($ArgumentList) {$ArgumentList = $ArgumentList.split(' ')}

    if ($Preset -and ($PSCmdlet.ParameterSetName -ne 'Custom')) {
        $nmapPresetArgumentNames = (Get-NmapPresetArguments).keys
        if ($Preset -notin $nmapPresetArgumentNames) {
            throwUser New-Object ArgumentException -ArgumentList "Invoke-Nmap: Value $Preset is not a valid choice. Please choose one of: $($nmapPresetArgumentNames -join ', ')","Preset"
        } else {
            $ArgumentList = Get-NmapPresetArguments $Preset
        }
    }

    if ($Preset -eq 'snmp') {$snmp = $true}
    if ($snmp) {
        $snmpCommunityFile = [io.path]::GetTempFileName()
        #Special file format required
        ($snmpCommunityList -join "`n") + "`n" | Set-Content -NoNewLine -Encoding ASCII -Path $snmpCommunityFile -Force
        $argumentList += '--script','snmp-brute','--script-args',"snmp-brute.communitiesdb=$snmpCommunityFile"
    }

    if (-not $All) {
        $argumentList += '--open'
    }

    try {
        switch -regex ($OutFormat) {
            'Raw|XML' {
                if ($Outformat -eq 'XML') {$argumentlist += '-oX','-'}
                StartNmap $argumentList $computerName -Raw
                break
            }
            default {
                StartNmap $argumentList $computerName | ConvertFrom-NmapXml -OutFormat $OutFormat
            }
        }
    } finally {
        if ($snmp -and (Test-Path $snmpCommunityFile)) {Remove-Item $snmpCommunityFile -Force -ErrorAction SilentlyContinue}
    }
}
