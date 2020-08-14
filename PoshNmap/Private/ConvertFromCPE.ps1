function ConvertFromCPE {
<#
.SYNOPSIS
Converts a common platform enumeration string into a powershell object
.LINK
https://nmap.org/book/output-formats-cpe.html
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)][String]$CPE
    )

    process {
        if ($CPE -notlike 'cpe:/*') {write-error "$CPE is not a valid CPE string";return}

        $CPEParts = $CPE -split ':'

        [PSCustomObject]@{
            PSTypeName = 'PoshNmapCommonPlatformEnumeration'
            Type = switch ($CPEParts[1]) {
                '/a' {
                    'Application'
                }
                '/h' {
                    'Hardware'
                }
                '/o' {
                    'OS'
                }
            }
            Product = $CPEParts[2]
            Version = $CPEParts[3]
            Update = $CPEParts[4]
            Edition = $CPEParts[5]
            Language = $CPEParts[6]
        }
    }


}