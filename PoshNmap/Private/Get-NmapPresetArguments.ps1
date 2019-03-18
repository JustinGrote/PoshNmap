#TODO: Pull this from a configuration file
function Get-NmapPresetArguments ($Preset) {
    $presetList = [ordered]@{
        Default = ''
        Intense = '-T4 -A' -split '\s'
        IntenseAllTCP = '-T4 -p 1-65535 -A' -split '\s'
        IntensePlusUDP = '-T4 -sS -sU -A' -split '\s'
        IntenseNoPing = '-T4 -A -v -Pn' -split '\s'
        PingSweep = '-T4 -sn'
        Quick = '-T4 -F' -split '\s'
        QuickPlus = '-T4 -sV -O -F –version-light' -split '\s'
        QuickTraceroute = '-T4 -sn -traceroute' -split '\s'
    }

    if ($Preset) {
        $presetList.$Preset
    } else {
        $presetList
    }
}