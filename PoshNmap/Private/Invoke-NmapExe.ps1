    #We wrap the nmap execution in a function so we can mock test it with Pester
    function Invoke-NmapExe ($nmapExe,$argumentList,$computerName) {
        & $nmapexe $argumentList $computerName
    }