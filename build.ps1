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

$ErrorActionPreference = 'Stop'

#Add TLS 1.2 to potential security protocols on Windows Powershell. This is now required for powershell gallery
if ($PSEdition -eq 'Desktop'){
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 'Tls12'
}

#Verify Invoke-Build Prerequisite
if (-not (Get-Command Invoke-Build -ErrorAction SilentlyContinue | where version -ge '5.5.7')) {
    write-verbose "Invoke-Build not found. Bootstrapping..."
    Install-Module -Name InvokeBuild -MinimumVersion '5.5.7' -MaximumVersion '5.99.99' -Scope CurrentUser -Force 4>$null
}

#Passthrough Invoke-Build
Push-Location $PSScriptRoot
try {
    Invoke-Expression "Invoke-Build $($args -join ' ')"
} catch {
    throw $PSItem
} finally {
    Pop-Location
}