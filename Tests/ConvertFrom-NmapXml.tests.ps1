Describe "ConvertFrom-NmapXml" {
    $Mocks = join-path $PSScriptRoot "Mocks"
    $asusNmapXmlFile = join-path $Mocks "asusrouter.nmapxml"
    $asusNmapXmlContent = get-content $asusNmapXmlFile
    It "Should Accept a raw string and an xml object" {
        [String]($asusNmapXmlContent) | ConvertFrom-NmapXml | Should -Not -BeNullOrEmpty
    }
    It "Should Accept an XML object" {
        [XML]($asusNmapXmlContent) | ConvertFrom-NmapXml | Should -Not -BeNullOrEmpty
    }
}