function ParseNSEFile {
    [CmdletBinding()]
    param (
        $scriptsDir = (Join-Path ([io.fileinfo](command nmap).source).directory 'scripts')
    )
    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path $scriptsDir)) {
        write-warning "Could not find the nmap scripts directory at $scriptsdir, attempting to autodetect"
        $nmapDataPath = (& nmap -v 6>&1).where{$_ -match '^Read data files from'} -replace '^Read Data files from: (.+)$','$1'
        if (-not $nmapDataPath) {throw 'Nmap was requested to run scripts but the script folder could not be found'}
        $scriptsDir = Join-Path $nmapDataPath 'scripts'
    }

    $nseScriptFiles = Get-ChildItem $scriptsDir -Filter '*.nse'
    if (-not $nseScriptFiles) {throw "Could not find any nmap scripts in $nseScriptFiles"}

    $nseScriptFiles.foreach{
        gc -raw
    }
}


