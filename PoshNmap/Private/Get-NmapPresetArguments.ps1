#TODO: Pull this from a configuration file
function Get-NmapPresetArguments ($Preset) {
    $presetList = @{
        Default = ''
        Intense = '-T4 -A' -split '\s'
        IntensePlusUDP = '-sS -sU -T4 -A' -split '\s'
        IntenseAllTCP = '-p 1-65535 -T4 -A' -split '\s'
        IntenseNoPing = '-T4 -A -v -Pn' -split '\s'
        Quick = '-T4 -F' -split '\s'
        QuickPlus = '-sV -T4 -O -F –version-light' -split '\s'
        QuickTraceroute = '-sn -traceroute' -split '\s'
    }

    if ($Preset) {
        $presetList.$Preset
    } else {
        $presetList
    }
}