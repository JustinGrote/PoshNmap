Describe 'ConvertFrom-NmapXml' {
    BeforeAll {
        Import-Module (Resolve-Path $PSScriptRoot/../PoshNmap/PoshNmap.psd1) -Force
        $Mocks = Join-Path $PSScriptRoot 'Mocks'
        $asusNmapXmlFile = Join-Path $Mocks 'asusrouter.nmapxml'
        $SCRIPT:asusNmapXmlContent = Get-Content $asusNmapXmlFile
    }

    It 'Input: Get-Content from file (string array)' {
        $asusNmapXmlContent | ConvertFrom-NmapXml | Should -BeOfType [PSCustomObject]
    }
    It 'Input: XML' {
        [XML]($asusNmapXmlContent) | ConvertFrom-NmapXml
    }
    It 'Output: PoshNmap by Default' {
        $asusNmapXmlContent | ConvertFrom-NmapXml | Should -BeOfType [PSCustomObject]
    }
    It -Pending 'Input: Single Unindented string (xml output maybe)' {
        [String]($asusNmapXmlContent) | ConvertFrom-NmapXml | Should -BeOfType [PSCustomObject]
    }
    It 'Output: PSObject with -OutFormat PSObject' {
        $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat PSObject | Should -BeOfType [PSCustomObject]
    }
    It 'Output: HashTable with -OutFormat HashTable' {
        $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat HashTable | Should -BeOfType [HashTable]
    }
    # It 'Output: NmapResult with -OutFormat PoshNmap' {
    #     $nmapResult = $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat PoshNmap
    #     $nmapResult | Should -Not -BeNullOrEmpty
    #     $nmapResult | ForEach-Object {
    #         'PoshNmapHost' | Should -BeIn $PSItem.psobject.typenames
    #     }
    # }
    It 'Output: NmapSummary with -OutFormat Summary' {
        $nmapSummary = $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat Summary
        $nmapSummary | Should -Not -BeNullOrEmpty
        $nmapSummary | ForEach-Object {
            'PoshNmapSummary' | Should -BeIn $PSItem.psobject.typenames
        }
    }
}
