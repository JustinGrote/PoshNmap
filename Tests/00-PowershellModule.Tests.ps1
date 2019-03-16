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

#Find the module manifest. Get-ChildItem's last item is the one closest to the root directory. #FIXME: Do this in a safer manner
try {
    $moduleManifestFile = Get-ChildItem -File -Recurse *.psd1 -ErrorAction Stop | where name -notmatch '(depend|requirements)\.psd1$'| Select-Object -last 1
    $SCRIPT:moduleDirectory = $moduleManifestFile.directory
} catch {
    throw "Did not detect any module manifests in $ModulePath. Did you run 'Invoke-Build Build' first?"
}
Describe 'Powershell Module' {
    $ModuleName = $ModuleManifestFile.basename
    Context ($ModuleName) {
        It 'Has a valid Module Manifest' {
            if ($PSEdition -eq 'Core' -or $PSVersionTable.PSVersion -ge [Version]"5.1") {
                $Script:Manifest = Test-ModuleManifest $ModuleManifestFile -Verbose:$false
            } else {
                #Copy the Module Manifest to a temp file for testing. This fixes a bug where
                #Test-ModuleManifest caches the first result, thus not catching changes if subsequent tests are run
                $TempModuleManifestPath = [System.IO.Path]::GetTempFileName() + '.psd1'
                copy-item $ModuleManifestPath $TempModuleManifestPath
                $Script:Manifest = Test-ModuleManifest $TempModuleManifestPath -Verbose:$false
                remove-item $TempModuleManifestPath -verbose:$false
            }
        }

        It 'Has a valid root module' {
            Test-Path $Manifest.RootModule -Type Leaf | Should Be $true
        }

        It 'Has a valid folder structure (ModuleName\Manifest or ModuleName\Version\Manifest)' {
            $moduleDirectoryErrorMessage = "Module directory structure doesn't match either $ModuleName or $moduleName\$($Manifest.Version)"
            $ModuleManifestDirectory = $ModuleManifestFile.directory
            switch ($ModuleManifestDirectory.basename) {
                $ModuleName {$true}
                $Manifest.Version.toString() {
                    if ($ModuleManifestDirectory.parent -match $ModuleName) {$true} else {throw $moduleDirectoryErrorMessage}
                }
                default {throw $moduleDirectoryErrorMessage}
            }
        }

        It 'Has a valid Description' {
            $Manifest.Description | Should Not BeNullOrEmpty
        }

        It 'Has a valid GUID' {
            [Guid]$Manifest.Guid | Should BeOfType 'System.GUID'
        }

        It 'Has a valid Copyright' {
            $Manifest.Copyright | Should Not BeNullOrEmpty
        }

        It 'Exports all public functions' {
            $FunctionFiles = Get-ChildItem Public -Filter *.ps1
            $FunctionNames = $FunctionFiles.basename | ForEach-Object {$_ -replace '-', "-$($Manifest.Prefix)"}
            $ExFunctions = $Manifest.ExportedFunctions.Values.Name
            if ($ExFunctions -eq '*') {write-warning "Manifest has * for functions. You should individually specify your public functions prior to deployment for better discoverability"}
            if ($functionNames) {
                foreach ($FunctionName in $FunctionNames) {
                    $ExFunctions -contains $FunctionName | Should Be $true
                }
            }
        }

        It 'Has at least 1 exported command' {
            $Script:Manifest.exportedcommands.count | Should BeGreaterThan 0
        }
        It 'Can be imported as a module successfully' {
            #Make sure an existing module isn't present
            Remove-Module $moduleManifestFile.basename -ErrorAction SilentlyContinue
            $SCRIPT:BuildOutputModule = Import-Module $moduleManifestFile -PassThru -verbose:$false -erroraction stop
            $BuildOutputModule.Name | Should Be $ModuleName
            $BuildOutputModule | Should BeOfType System.Management.Automation.PSModuleInfo
        }
        It 'Can be removed as a module' {
            $BuildOutputModule | Remove-Module -erroraction stop -verbose:$false | Should BeNullOrEmpty
        }

    }
}
Describe 'Powershell Gallery Readiness (PSScriptAnalyzer)' {
    $results = Invoke-ScriptAnalyzer -Path $ModuleManifestFile.directory -Recurse -Setting PSGallery -Severity Error -Verbose:$false
    It 'PSScriptAnalyzer returns zero errors (warnings OK) using the Powershell Gallery ruleset' {
        if ($results) {write-warning ($results | Format-Table -autosize | out-string)}
        $results.Count | Should Be 0
    }
}


#Return to where we started
Pop-Location