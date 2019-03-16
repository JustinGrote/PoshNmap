InModuleScope PoshNmap {

    Describe "Invoke-Nmap" {
        $SCRIPT:nmapResult = "Test"
        $Mocks = (join-path $PSScriptRoot "Mocks")

        Mock Invoke-NmapExe {
            Get-Content -Raw "$Mocks\asusrouter.nmapxml"
        }

        It "Produces a hashtable when invoked" {
            $SCRIPT:nmapResult = Invoke-Nmap
            $nmapResult | Should -BeOfType System.Collections.HashTable
        }

        It "Basic data verification sanity check" {
            $nmapresult.host.ports.port | where portid -match '445' | % protocol | should -be 'tcp'
        }
    }
}
