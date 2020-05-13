#requires -version 5.1

#region PowerCDBootstrap
. ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://git.io/PCDBootstrap')))
#endregion PowerCDBootstrap

Task CITesting -Before PowerCD.Clean {
    dotnet gitversion
    dotnet dotnet-gitversion
}