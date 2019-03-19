param (
    #Specify an alternate location for the Powershell Module. This is useful when testing a build in another directory
    [string]$ModulePath = (Get-Location)
)

#if we are in the "Tests" directory and there is a PSD file below this one, change to the module directory so relative paths work correctly.
$currentDir = Get-Location
if (
    (Test-Path $currentDir -PathType Container) -and
    $currentDir -match 'Tests$' -and
    (Get-Item (join-path ".." "*.psd1") | where name -notmatch '\.(depend|requirements)\.psd1$')
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

Describe "Invoke-Nmap" {
    $SCRIPT:nmapResult = "Test"
    $Mocks = (join-path $PSScriptRoot "Mocks")

    Mock -Modulename PoshNmap InvokeNmapExe {
        Get-Content -Raw "$Mocks\asusrouter.nmapxml"
    }.GetNewClosure() #GetNewClosure "Freezes" the mock. We use this to expand the variable present inside: https://stackoverflow.com/questions/49681015/access-external-variable-from-with-in-mock-script-block-pester

    It "Output: PSCustomObject by default" {
        $SCRIPT:nmapResult = Invoke-Nmap
        $nmapResult | Should -BeOfType [PSCustomObject]
    }

    It "Output: PoshNmap Output Data Sanity Check" {
        (Invoke-Nmap -OutFormat PSObject).nmaprun.host.ports.port | where portid -match '445' | % protocol | should -be 'tcp'
    }

    It "Output: XML Data Sanity Check" {
        (Invoke-Nmap -OutFormat PSObject).nmaprun.host.ports.port | where portid -match '445' | % protocol | should -be 'tcp'
    }
}
