#requires -version 5
using namespace System.IO
<#
.SYNOPSIS
Bootstraps Invoke-Build and starts it with supplied parameters.
.NOTES
If you already have Invoke-Build installed, just use Invoke-Build instead of this script. This is for CI/CD environments like Appveyor, Jenkins, or Azure DevOps pipelines.
.EXAMPLE
.\build.ps1
Starts Invoke-Build with the default parameters
#>

function FindInvokeBuild {
<#
.SYNOPSIS
Returns a path to an Invoke-Build powershell module either as a Powershell Module or in NuGet
#>
	param (
		#Specify the minimum version to accept as installed
		[Version]$MinimumVersion='5.4.1',
		#Specify this if you know it isn't present as a powershell module and want to save some detection time
		[Switch]$SkipPSModuleDetection,
		#Specify this if you just want a simple true/false result
		[Switch]$Quiet
	)

	if (-not $SkipPSModuleDetection) {
		write-verbose "Detecting InvokeBuild as a Powershell Module..."
		$invokeBuild = (Get-Module InvokeBuild -listavailable -erroraction silentlycontinue | sort version -descending | select -first 1) | where version -gt $MinimumVersion
	}

	if (-not $invokeBuild -and (get-command Get-Package -erroraction silentlycontinue)) {
		write-verbose "InvokeBuild not found as a Powershell Module. Checking for NuGet package..."
		$invokeBuild = Get-Package Invoke-Build -MinimumVersion $MinimumVersion -erroraction silentlycontinue | sort version -descending | select -first 1
	}

	if ($InvokeBuild) {

		if ($Quiet) {
			return $false
		} else {
			write-host -fore green "Invoke-Build $MinimumVersion is already installed. Please use the Invoke-Build command from now on instead of build.ps1."
			return $InvokeBuild
		}
	} else {
		write-warning "Invoke-Build not found either as a Powershell Module or as an Installed NuGet module."
		if ($Quiet) {
			return $true
		}
	}
}

function BootStrapInvokeBuild {
	#Get a temporary directory
	$tempFileObj = (New-TemporaryFile)
	$tempfile = $tempFileObj -replace '\.tmp$','.zip'
	$tempdir = $tempfileObj.DirectoryName

	#Fetch Invoke-Build and import the module
	$invokeBuildLatestURI = 'https://powershellgallery.com/api/v1/package/InvokeBuild'
	(New-Object Net.WebClient).DownloadFile($invokeBuildLatestURI, $tempfile)
	Expand-Archive $tempfile $tempdir -Force -ErrorAction stop

	$IBModule = Join-Path $tempdir 'InvokeBuild.psd1'
	Import-Module $IBModule -force
}

#region Main
if ($isCoreCLR) {write-host -fore green 'Detected Powershell Core'}
$IBModulePath = if (-not $FindInvokeBuild) {BootStrapInvokeBuild}
Invoke-Expression "Invoke-Build $($args -join ' ')"
exit $LastExitCode
#endRegion Main