using namespace System.Management.Automation
function throwUser {
<#
.SYNOPSIS
Throws a terminating exception record that shows the cmdlet as the source of the error, rather than the inner "throw". Makes for more user friendly errors than simply using "throw"
.INPUTS
[String]
[Exception]
[Object]
.OUTPUTS
[Management.Automation.ErrorRecord]
.LINK
https://powershellexplained.com/2017-04-10-Powershell-exceptions-everything-you-ever-wanted-to-know/ - Section on $PSCmdlet.ThrowTerminatingError()
.EXAMPLE
ThrowException "Some Error Occured"
.EXAMPLE
ThrowException [System.ApplicationException]
#>
    [CmdletBinding()]
    param (
        #Use anything you would normally use for "throw"
        [Parameter(Mandatory)]$InputObject
    )

    #Generate an error record from "throw"
    try {
        throw $InputObject
    } catch {
        $errorRecord = $PSItem
    }

    #Because this command is itself a cmdlet, we need the parent Cmdlet "context" to show the proper line numbers of the error, which is why scope 1 is used. If that doesn't exist then just use normal scope
    try {
        $myPSContext = (Get-Variable -Scope 1 'PSCmdlet' -Erroraction Stop).Value
    } catch [ItemNotFoundException] {
        $myPSContext = $PSCmdlet
    }
    $myPSContext.ThrowTerminatingError($errorRecord)
}