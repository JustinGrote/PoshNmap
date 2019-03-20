#TODO: Pull this from a configuration file
function Get-NmapPresetArguments ($Preset) {
    $presetList = [ordered]@{
        Default = ''
        Intense = '-T4 -A'
        IntenseAllTCP = '-T4 -p 1-65535 -A'
        IntensePlusUDP = '-T4 -sS -sU -A'
        IntenseNoPing = '-T4 -A -v -Pn'
        PingSweep = '-T4 -sn'
        Quick = '-T4 -F'
        QuickPlus = '-T4 --version-intensity 2 -sV -O -F'
        QuickTraceroute = '-T4 -sn -traceroute'
        Snmp = '-T4 -sU -p U:161'
    }

    #The call operator wants this as an array
    $updatedPresetList = [ordered]@{}
    foreach ($presetListItem in $presetList.keys) {
        $updatedPresetList[$presetListItem] = $presetList[$presetListItem] -split '\s'
    }
    $presetList = $updatedPresetList

    if ($Preset) {
        $presetList.$Preset
    } else {
        $presetList
    }
}