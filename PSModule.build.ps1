#requires -version 5.1

#region PowerCDBootstrap
. ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://git.io/PCDBootstrap'))) -PowerCDVersion 0.8.5
#endregion PowerCDBootstrap