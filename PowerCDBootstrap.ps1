#requires -version 5.1
using namespace System.IO

#This bootstraps the invoke-build environment for PowerCD
param (
    #Specify the version of PowerCD to use. By default it will use the latest available either on this system or on Powershell Gallery
    [Version]$PowerCDVersion
)
$ErrorActionPreference = 'Stop'
$GLOBAL:ProgressPreference = 'SilentlyContinue'

#Invoke-Build Report style
if ($BuildRoot) {
    Write-Host -fore cyan "Task PowerCD.Bootstrap"
    $bootstrapTimer = [Diagnostics.Stopwatch]::StartNew()
}

try {
    Write-Debug "Searching for PowerCD MetaBuild in $pwd"
    #Test if this is a MetaBuild

    #Workaround for running a bootstrap script from the internet
    $PSModuleBuildScriptPath = if ($PSSCRIPTROOT) {$PSScriptRoot} else {Split-Path $MyInvocation.ScriptName}

    foreach ($MetaBuildPathItem in @(
        "$pwd/../PowerCD/PowerCD.psd1"
        "$pwd/PowerCD/PowerCD.psd1"
        "$PSModuleBuildScriptPath/../PowerCD/PowerCD.psd1"
        "$PSModuleBuildScriptPath/PowerCD/PowerCD.psd1"
    )) {
        if (Test-Path $MetaBuildPathItem) {
            #Cannot cast pathinfo output directly to fileinfo, but can use string as an intermediate
            [IO.FileInfo]$GLOBAL:MetaBuildPath = [String](Resolve-Path $MetaBuildPathItem)
            Write-Debug "PowerCD Metabuild Detected, importing source module: $MetaBuildPath"
            Import-Module $MetaBuildPath -Force -WarningAction SilentlyContinue
            return
        }
    }

    #Test if PowerCD is loaded already
    $CandidateModule = Get-Module PowerCD
    if ($CandidateModule) {
        if ($MetaBuildPath -and (Split-Path $CandidateModule.Path) -ne (Split-Path $MetaBuildPath)) {
            Write-Warning "Detected we are in PowerCD source folder $MetaBuildPath but PowerCD is currently loaded from $($LoadModule.Path). Reloading to current source module"
            Import-Module -Name $MetaBuildPath -Force
            return
        }
        if ($PowerCDVersion) {
            if ($CandidateModule.Version -eq $PowerCDVersion) {
                Write-Debug "Loaded PowerCD version matches PowerCDVersion"
                return
            } else {
                throw [NotImplementedException]"The loaded PowerCD Module Version $($CandidateModule.Version) is not the same as the requested $PowerCDVersion. Please load the requested module. In the future this will autodetect and download the correct version"
            }
        } else {
            #Module is loaded but no version specified, use existing
            #TODO: Check for latest powercd version
            Write-Debug "No PowerCDVersion specified, using existing loaded module"
            return
        }
    }

    Write-Verbose "PowerCD: Module not installed locally. Bootstrapping..."
    $InstallModuleParams = @{
        Name = 'PowerCD'
        Scope = 'CurrentUser'
        Force = $true
    }
    if ($PowerCDVersion) {$InstallModuleParams.RequiredVersion = $PowerCDVersion}
    $installedModule = Install-Module @InstallModuleParams -PassThru 4>$null
    if (-not $installedModule) {throw 'Error Installing PowerCD'}
    #FIXME: Remove after testing
    write-host 'Installing Module $InstalledModule'
    $installedModule | Import-Module -PassThru
} finally {
    if ($BuildRoot) {
        Write-Host -fore cyan "Done PowerCD.Bootstrap $([string]$bootstrapTimer.elapsed)"
    }
    if (
        (Get-Command -Name 'PowerCD.Tasks' -ErrorAction SilentlyContinue) -and
        (Get-Variable -Name '`*' -ErrorAction SilentlyContinue)
    ) {
        . PowerCD.Tasks
    }
}


# $pcdModuleParams = @{
#     Global = $true
#     Force = $true
#     WarningAction = 'SilentlyContinue'
# }
# if ($PowerCDMetaBuild) {
#     #Reinitialize
# }

# if ($PowerCDVersion) {
#     $candidateModules = Get-Module -Name PowerCD -ListAvailable
#     if ($PowerCDVersion) {
#         if ($PowerCDVersion -in $candidateModules.Version) {
#             Get-Module 'PowerCD' | Remove-Module -Force -ErrorAction Stop 4>$null
#             Import-Module @pcdModuleParams -RequiredVersion $PowerCDVersion 4>$null
#             return
#         }
#     }
# } else {
#     #Try loading native module if PowerCDVersion was not specified
#     $CandidateModule = Import-Module @pcdModuleParams -Name PowerCD -ErrorAction SilentlyContinue -PassThru
#     if ($CandidateModule) {return}
# }






# function DetectNestedPowershell {
#     #Fix a bug in case powershell was started in pwsh and it cluttered PSModulePath: https://github.com/PowerShell/PowerShell/issues/9957
#     if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
#         Write-Verbose 'Powershell 5.1 was started inside of pwsh, removing non-WindowsPowershell paths'
#         $env:PSModulePath = ($env:PSModulePath -split [Path]::PathSeparator | Where-Object {$_ -match 'WindowsPowershell'}) -join [Path]::PathSeparator
#         $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
#             Where-Object Version -lt 6.0.0 |
#             Sort-Object Version -Descending |
#             Select-Object -First 1
#         Remove-Module 'Microsoft.Powershell.Utility'
#         Import-Module $ModuleToImport -Force 4>&1 | Where-Object {$_ -match '^Loading Module.+psd1.+\.$'} | Write-Verbose
#     }
# }

#region HelperFunctions
# function Install-PSGalleryModule {
#     <#
#     .SYNOPSIS
#     Downloads a module from the Powershell Gallery using direct APIs. This is primarily used to bootstrap
#     #>

#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory)][String]$Name,
#         [Parameter(Mandatory)][String]$Destination,
#         [String]$Version
#     )
#     if (-not (Test-Path $Destination)) {throw "Destination $Destination doesn't exist. Please specify a powershell modules directory"}
#     $downloadURI = "https://www.powershellgallery.com/api/v2/package/$Name"
#     if ($version) {$downloadURI += "/$Version"}buc
#     try {
#         $ErrorActionPreference = 'Stop'
#         $tempZipName = "mybootstrappedPSGalleryModule.zip"
#         $tempDirPath = Join-Path ([io.path]::GetTempPath()) "$Name-$(get-random)"
#         $tempDir = New-Item -ItemType Directory -Path $tempDirPath
#         $tempFilePath = Join-Path $tempDir $tempZipName
#         [void][net.webclient]::new().DownloadFile($downloadURI,$tempFilePath)
#         [void][System.IO.Compression.ZipFile]::ExtractToDirectory($tempFilePath, $tempDir, $true)
#         $moduleManifest = Get-Content -raw (Join-Path $tempDirPath "$Name.psd1")
#         $modulePathVersion = if ($moduleManifest -match "ModuleVersion = '([\.\d]+)'") {$matches[1]} else {throw "Could not read Moduleversion from the module manifest"}
#         $itemsToRemove = @($tempZipName,'_rels','package','`[Content_Types`].xml','*.nuspec').foreach{
#             Join-Path $tempdir $PSItem
#         }
#         Remove-Item $itemsToRemove -Recurse

#         $destinationModulePath = Join-Path $destination $Name
#         $destinationPath = Join-Path $destinationModulePath $modulePathVersion
#         if (-not (Test-Path $destinationModulePath)) {$null = New-Item -ItemType Directory $destinationModulePath}
#         if (Test-Path $destinationPath) {Remove-Item $destinationPath -force -recurse}
#         $null = Move-Item $tempdir -Destination $destinationPath

#         Set-Location -path ([io.path]::Combine($Destination, $Name, $modulePathVersion))
#         #([IO.Path]::Combine($Destination, $Name, $modulePathVersion), $true)
#     } catch {throw $PSItem} finally {
#         #Cleanup
#         if (Test-Path $tempdir) {Remove-Item -Recurse -Force $tempdir}
#     }
# }
