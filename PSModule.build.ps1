#requires -version 5.1

#region PowerCDBootstrap
. ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://git.io/PCDBootstrap'))) -PowerCDVersion 0.8.2
#endregion PowerCDBootstrap

task TestPrereqs -Before PowerCD.Test.Pester {
    if (-not (command 'nmap' -ErrorAction SilentlyContinue)) {
        if ($isLinux) {
            sudo apt install nmap -y
        } else {
            choco install nmap -y
        }
    }
}