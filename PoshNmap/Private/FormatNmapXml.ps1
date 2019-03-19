Update-TypeData -TypeName PoshNmapHost -DefaultDisplayPropertySet IPv4,FQDN,Status,OpenPorts -Force

function FormatNmapXml {
<#
.SYNOPSIS
Takes the raw formatting from ConvertFrom-NmapXML and makes a useful Powershell Object out of the output. Meant to be called from ConvertFrom-NmapXml
.INPUTS
[Hashtable]
.OUTPUTS
[PoshNmapResult]
.NOTES
The raw formatting is still available as the nmaprun property on the object, to maintain compatibility
#>

    [CmdletBinding()]
    param (
        #Nmaprun output from ConvertFrom-NmapXml. We use hashtable because it's the easiest to manipulate quickly
        [Parameter(ValueFromPipeline)][Hashtable]$InputNmapXml,
        #Return a summary of the scan rather than individual hosts
        [Switch]$Summary
    )

    if (-not $inputNmapXml.nmaprun) {throwUser "This is not a valid Hashtable output from Convert-NmapXML"}

    $nmaprun = $inputNmapXml.nmaprun

    #Only return a summary if that was requested
    if ($summary) {return (FormatNmapXmlSummary $nmapRun)}

    #Generate nicer host entries
    $i=1
    $itotal = $nmaprun.host | measure | % count
    foreach ($hostnode in $nmaprun.host) {
        write-progress -Activity "Parsing NMAP Result" -Status "Processing Scan Entries" -CurrentOperation "Processing $i of $itotal" -PercentComplete (($i/$itotal)*100)

        # Init variables, with $entry being the custom object for each <host>.
        $service = " " #service needs to be a single space.
        $entry = [ordered]@{
            PSTypeName = 'PoshNmapHost'
        }

        #Add raw host reference
        $entry.nmapResult = $hostnode

        # Extract state element of status
        $entry.Status = $hostnode.status.state.Trim()
        if ($entry.Status.length -lt 2) { $entry.Status = $null }

        # Extract fully-qualified domain name(s), removing any duplicates.
        $entry.FQDNs = $hostnode.hostnames.hostname.name | select -Unique
        $entry.FQDN = $entry.FQDNs | select -first 1

        # Note that this code cheats, it only gets the hostname of the first FQDN if there are multiple FQDNs.
        if ($entry.FQDN -eq $null) { $entry.HostName = $null }
        elseif ($entry.FQDN -like "*.*") { $entry.HostName = $entry.FQDN.Substring(0,$entry.FQDN.IndexOf(".")) }
        else { $entry.HostName = $entry.FQDN }

        # Process each of the <address> nodes, extracting by type.
        $hostnode.address | foreach-object {
            if ($_.addrtype -eq "ipv4") { $entry.IPv4 += $_.addr + " "}
            if ($_.addrtype -eq "ipv6") { $entry.IPv6 += $_.addr + " "}
            if ($_.addrtype -eq "mac")  { $entry.MAC  += $_.addr + " "}
        }
        if ($entry.IPv4 -eq $null) { $entry.IPv4 = $null } else { $entry.IPv4 = $entry.IPv4.Trim()}
        if ($entry.IPv6 -eq $null) { $entry.IPv6 = $null } else { $entry.IPv6 = $entry.IPv6.Trim()}
        if ($entry.MAC  -eq $null) { $entry.MAC  = $null }  else { $entry.MAC  = $entry.MAC.Trim()}


        # Process all ports from <ports><port>, and note that <port> does not contain an array if it only has one item in it.
        if ($hostnode.ports.port -eq $null) { $entry.Ports = $null ; $entry.Services = $null }
        else
        {
            $entry.Ports = @()

            $hostnode.ports.port | foreach-object {
                if ($_.service.name -eq $null) { $service = "unknown" } else { $service = $_.service.name }
                $entry.Ports += [ordered]@{
                    Protocol=$_.protocol
                    Port=$_.portid
                    Service=$service
                    State=$_.state.state
                }

                # Build Services property. What a mess...but exclude non-open/non-open|filtered ports and blank service info, and exclude servicefp too for the sake of tidiness.
                if ($_.state.state -like "open*" -and ($_.service.tunnel.length -gt 2 -or $_.service.product.length -gt 2 -or $_.service.proto.length -gt 2)) { $entry.Services += $_.protocol + ":" + $_.portid + ":" + $service + ":" + ($_.service.product + " " + $_.service.version + " " + $_.service.tunnel + " " + $_.service.proto + " " + $_.service.rpcnum).Trim() + " <" + ([Int] $_.service.conf * 10) + "%-confidence>$OutputDelimiter" }
            }
            if ($entry.Services -eq $null) { $entry.Services = $null } else { $entry.Services = $entry.Services.Trim() }
            #Provide a nicer ToString Output
            $entry.Ports | Add-Member -MemberType ScriptMethod -Name ToString -Force -Value {$this.protocol,$this.port -join ':'}
        }

        $entry.OpenPorts = $entry.ports.count

        # If there is 100% Accuracy OS, show it
        $CertainOS = $hostnode.os.osmatch | where {$_.accuracy -eq 100} | select -first 1
        if ($CertainOS) {$Entry.OS = $certainOS.name; $Entry.OSDetail = $certainOS} else {$Entry.OS=$null}
        $entry.BestGuessOS = ($hostnode.os.osmatch | select -first 1).name
        $entry.BestGuessOSPercent = ($hostnode.os.osmatch | select -first 1).accuracy
        $entry.OSGuesses = $hostnode.os.osmatch
        if (@($entry.OSGuesses).count -lt 1) { $entry.OS = $null }


        # Extract script output, first for port scripts, then for host scripts.
        $entry.Script = $null
        $hostnode.ports.port | foreach-object {
            if ($_.script -ne $null) {
                $entry.Script += "<PortScript id=""" + $_.script.id + """>$OutputDelimiter" + ($_.script.output -replace "`n","$OutputDelimiter") + "$OutputDelimiter</PortScript> $OutputDelimiter $OutputDelimiter"
            }
        }

        if ($hostnode.hostscript -ne $null) {
            $hostnode.hostscript.script | foreach-object {
                $entry.Script += '<HostScript id="' + $_.id + '">' + $OutputDelimiter + ($_.output.replace("`n","$OutputDelimiter")) + "$OutputDelimiter</HostScript> $OutputDelimiter $OutputDelimiter"
            }
        }
        $i++  #Progress counter...
        [PSCustomObject]$entry
    }
}