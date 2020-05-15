

if ($psEdition -ne 'Core') {
    $dotNetTarget = "net40-client"
}

#Special Newtonsoft Handling
try {
    $loadedNewtonsoftVersion = [version]([newtonsoft.json.jsonconvert].assembly.fullname -replace '^.+Version=([\d\.]+),.+$','$1')
} catch {
    Write-Verbose "Newtonsoft.Json not loaded"
}
if ($PSEdition -ne 'Core') {
    if ($loadedNewtonSoftVersion) {
        if ($loadedNewtonSoftVersion.major -lt '11') {
            Write-Debug "Already loaded Newtonsoft.Json $loadedNewtonsoftVersion was detected and is less than version 11, falling back to compatible behavior"
            $SCRIPT:useLegacyXMLDeserializer = $true
        }
    } else {
        Add-Type -Path $PSSCriptRoot\PoshNmap\lib\Newtonsoft.Json-net40-client.dll
    }
}

#$AssembliesToLoad = Get-ChildItem -Path "$PSScriptRoot\lib\*-$dotNetTarget.dll" -ErrorAction SilentlyContinue

if ($AssembliesToLoad) {
    #If we are in a build or a pester test, load assemblies from a temporary file so they don't lock the original file
    #This helps to prevent cleaning problems due to a powershell session locking the file because unloading a module doesn't unload assemblies
    if ($BuildTask -or $TestDrive -or $env:BUILD_BUILDID) {
        write-verbose "Detected Invoke-Build or Pester, loading assemblies from a temp location to avoid locking issues"

        $TempAssembliesToLoad = @()
        foreach ($AssemblyPathItem in $AssembliesToLoad) {
            $TempAssemblyPath = [System.IO.Path]::GetTempFileName() + ".dll"
            Copy-Item $AssemblyPathItem $TempAssemblyPath
            $TempAssembliesToLoad += [System.IO.FileInfo]$TempAssemblyPath
        }

        $AssembliesToLoad = $TempAssembliesToLoad
    }

    $assembliestoLoad | Foreach-Object {
        [Reflection.Assembly]::LoadFile($AssembliesToLoad)
    }
}

#region SourceInit
#Dot source the files
Foreach($FolderItem in 'Private','Public') {
    $ImportItemList = Get-ChildItem -Path $PSScriptRoot\$FolderItem\*.ps1 -ErrorAction SilentlyContinue
    Foreach($ImportItem in $ImportItemList) {
        Try {
            . $ImportItem
        }
        Catch {
            throw "Failed to import function $($importItem.fullname): $_"
        }
    }
    if ($FolderItem -eq 'Public') {
        Export-ModuleMember -Function ($ImportItemList.basename | Where-Object {$PSitem -match '^\w+-\w+$'})
    }
}
#endregion SourceInit

#Import Settings files as global objects based on their filename
foreach ($ModuleSettingsItem in $ModuleSettings) {
    New-Variable -Name "$($ModuleSettingsItem.basename)" -Scope Global -Value (convertfrom-json (Get-Content -raw $ModuleSettingsItem.fullname)) -Force
}

#Export the public functions. This requires them to match the standard Noun-Verb powershell cmdlet format as a safety mechanism