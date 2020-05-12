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

#First checks for a "metabuild" (PowerCD building PowerCD), then does normal detection
try {
    Write-Debug "Searching for PowerCD MetaBuild in $pwd"

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

    #Normal bootstrap
    function BootstrapModule {
        param (
            $ModuleSpecification,
            $Path = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PowerCD')
        )
        $vEnvDir = New-Item -ItemType Directory -Force -Path $Path

        try {
            $currentPSModulePath = $env:PSModulePath
            $env:PSModulePath = $vEnvDir,$env:PSModulePath -join [io.path]::PathSeparator

            #This is done for performance. If the module is found loaded it won't try to search filesystem
            $moduleLoaded = (Get-Module -FullyQualifiedName $moduleSpecification -ErrorAction SilentlyContinue)
            $moduleAvailable = if (-not $moduleLoaded) {
                (Get-Module -ListAvailable -FullyQualifiedName $moduleSpecification -ErrorAction SilentlyContinue)
            } else { $true }

            if (-not $moduleLoaded) {
                $moduleParams = @{
                    Name = $moduleSpecification.ModuleName
                    MinimumVersion = $moduleSpecification.ModuleVersion
                    MaximumVersion = $moduleSpecification.MaximumVersion
                    Force = $true
                    ErrorAction = 'Stop'
                }
                if (-not $moduleAvailable) {
                    Write-Verbose "$($ModuleSpecification.ModuleName) not found locally. Bootstrapping..."
                    Save-Module @moduleParams -Path $vEnvDir
                }
                Import-Module @moduleParams
            }
        } catch {
            throw $PSItem
        } finally {
            #Revert PSModulePath
            $env:PSModulePath = $currentPSModulePath
        }
    }

    $pcdModuleSpec = @{
        ModuleName = 'PowerCD'
    }
    #Fallback to a minimum PowerCD requirement
    if ($PowerCDVersion) {
        $pcdModuleSpec.RequiredVersion = $PowerCDVersion
    } else {
        $pcdModuleSpec.ModuleVersion = '0.8.0'
    }
    BootstrapModule $pcdModuleSpec

} catch {
    write-host -fore Red "ERROR CAUGHT WHILE BOOTSTRAPPING MODULE: $_"
    throw $_
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
