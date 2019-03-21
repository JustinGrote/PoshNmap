function FormatStringOut () {
<#
.SYNOPSIS
Change what is shown when the supplied object is cast to a string. Use $this to reference the supplied object
.EXAMPLE
[String](FormatStringOut (Get-Item .) {$this.name})
#>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$inputObject,
        [Parameter(Mandatory,Position=0)][ScriptBlock]$scriptBlock
    )

    process {
        if ($inputObject) {
            $AddMemberParams = @{
                InputObject = $inputObject
                MemberType = 'ScriptMethod'
                Name = 'ToString'
                Force = $true
                Value = $scriptBlock
            }
            Add-Member @AddMemberParams
        }
    }

}