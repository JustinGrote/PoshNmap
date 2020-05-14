#requires -version 5.1

#region PowerCDBootstrap
. ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://git.io/PCDBootstrap')))
#endregion PowerCDBootstrap

task PoshNmap.TestPrereqs -Before PowerCD.Test {
    if (-not (command 'nmap' -ErrorAction SilentlyContinue)) {
        if ($isLinux) {
            apt-get install nmap
        } else {
            choco install nmap -y
        }
    }
}