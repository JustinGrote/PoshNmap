param (
    #Specify an alternate location for the Powershell Module. This is useful when testing a build in another directory
    [string]$ModulePath = (Get-Location)
)

#if we are in the "Tests" directory, move up a directory
$currentDir = Get-Location
if (
    (Test-Path $currentDir -PathType Container) -and
    $currentDir -match 'Tests$'
) {
    $ModulePath = (split-path $modulepath)
}

#If an alternate module root was specified, set that to our running directory.
if ($ModulePath -ne (get-location).path) {Push-Location $ModulePath}

#Find the module manifest. Get-ChildItem's last item is the deepest one available, so it will favor release builds over the raw source, but will use the source module if a release build is unavailable. #FIXME: Do this in a safer manner
try {
    $moduleManifestFile = Get-ChildItem -File -Recurse *.psd1 -ErrorAction Stop | where name -notmatch '(depend|requirements)\.psd1$'| Select-Object -last 1
    $SCRIPT:moduleDirectory = $moduleManifestFile.directory
} catch {
    throw "Did not detect any module manifests in $ModulePath. Did you run 'Invoke-Build Build' first?"
}

import-module $moduleManifestFile

Describe "ConvertFrom-NmapXml" {
    $Mocks = join-path $PSScriptRoot "Mocks"
    $asusNmapXmlFile = join-path $Mocks "asusrouter.nmapxml"
    $asusNmapXmlContent = get-content $asusNmapXmlFile

    It "Input: Get-Content from file (string array)" {
        $asusNmapXmlContent | ConvertFrom-NmapXml | Should -BeOfType [PSCustomObject]
    }
    It -Pending "Input: Single Unindented string (xml output maybe)" {
        [String]($asusNmapXmlContent) | ConvertFrom-NmapXml | Should -BeOfType [PSCustomObject]
    }
    It "Input: XML" {
        [XML]($asusNmapXmlContent) | ConvertFrom-NmapXml
    }
    It "Output: PoshNmap by Default" {
        $asusNmapXmlContent | ConvertFrom-NmapXml | Should -BeOfType [PSCustomObject]
    }
    It "Output: PSObject with -OutFormat PSObject" {
        $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat PSObject | Should -BeOfType [PSCustomObject]
    }
    It "Output: HashTable with -OutFormat HashTable" {
        $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat HashTable | Should -BeOfType [HashTable]
    }
    It "Output: NmapResult with -OutFormat PoshNmap" {
        $nmapResult = $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat PoshNmap
        $nmapResult | Should -Not -BeNullOrEmpty
        $nmapResult | ForEach-Object {
            'PoshNmapHost' | Should -BeIn $PSItem.psobject.typenames
        }
    }
    It "Output: NmapSummary with -OutFormat Summary" {
        $nmapSummary = $asusNmapXmlContent | ConvertFrom-NmapXml -OutFormat Summary
        $nmapSummary | Should -Not -BeNullOrEmpty
        $nmapSummary | ForEach-Object {
            'PoshNmapSummary' | Should -BeIn $PSItem.psobject.typenames
        }
    }
}