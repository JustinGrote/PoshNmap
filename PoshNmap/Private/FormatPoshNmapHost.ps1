using namespace Management.Automation
Update-TypeData -TypeName PoshNmapHost -DefaultDisplayPropertySet IPv4,FQDN,Status,OpenPorts -Force
function FormatPoshNmapHost {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)][pscustomobject]$PoshNmapHost
    )

    process {
        $hostnode = $PoshNmapHost

        #Deep copy the nmap result so when we output it as the nmapresult property, it is "unchanged"
        $nmapResult = [PSSerializer]::Serialize($hostnode, [int32]::MaxValue)

        # Init variables, with $entry being the custom object for each <host>.
        $service = $null
        $entry = [ordered]@{
            PSTypeName = 'PoshNmapHost'
            Hostname = $null
            Status = ($hostnode.status.state.Trim() | where length -ge 2)
            FQDNs = $hostnode.hostnames.hostname.name | select -Unique
            FDQN = $null
            IPv4 = $null
            IPv6 = $null
            MAC = $null
            #Arraylist used for performance as this can get large quickly
            Ports = New-Object Collections.ArrayList
            OpenPorts = $hostnode.ports.port | measure | % count
        }
        $entry.FQDN = $entry.FQDNs | select -first 1
        $entry.Hostname = $entry.FQDN -replace '^(\w+)\..*$','$1'
        FormatStringOut -InputObject $entry.Ports {$this.ports | measure | % count}

        # Process each of the supplied address properties, extracting by type.
        foreach ($addressItem in $hostnode.address) {
            switch ($addressItem.addrtype) {
                "ipv4" { $entry.IPv4 += $addressItem.addr}
                "ipv6" { $entry.IPv6 += $addressItem.addr}
                "mac" { $entry.MAC += $addressItem.addr}
            }
        }

        $hostnode.ports.port | foreach-object {
            $portResult = [pscustomobject][ordered]@{
                PSTypeName="PoshNmapPort"
                Protocol=$_.protocol
                Port=$_.portid
                Services=$_.service
                State=$_.state
                ScriptResult = @{}
            }
            $portResult | FormatStringOut -scriptblock {$this.protocol,$this.port -join ':'}
            $portResult.State | FormatStringOut -scriptblock {$this.state}
            $portResult.Services | FormatStringOut -scriptblock {($this.name,$this.product -join ':') + " ($([int]($this.conf) * 10)%)"}

            #TODO: Refactor this now that I'm better at Powershell :)
            # Build Services property. What a mess...but exclude non-open/non-open|filtered ports and blank service info, and exclude servicefp too for the sake of tidiness.
            if ($_.state.state -like "open*" -and ($_.service.tunnel.length -gt 2 -or $_.service.product.length -gt 2 -or $_.service.proto.length -gt 2)) {
                $OutputDelimiter = ', '
                $entry.Services += ($_.protocol,$_.portid,$service -join ':')+
                    ':'+
                    ($_.service.product,$_.service.version,$_.service.tunnel,$_.service.proto,$_.service.rpcnum -join " ").Trim() +
                    " <" +
                    ([Int] $_.service.conf * 10) + "%-confidence>$OutputDelimiter"
            }

            #Port Script Result Processing
            foreach ($scriptItem in $_.script) {
                $scriptResultEntry = [ordered]@{
                    PSTypeName = 'PoshNmapScriptResult'
                    id = $ScriptItem.id
                    output = $ScriptItem.output
                    table = [Collections.Arraylist]@()
                }

                #Loop through the script elements and create a hashtable for them
                foreach ($tableitem in $scriptItem.table) {
                    $scriptTable = @{
                        PSTypeName = 'PoshNmapScriptTable'
                    }
                    foreach ($elemItem in $tableitem.elem) {
                        $scriptTable[$elemItem.key] = $elemItem.'#text'
                    }
                    $scriptResultEntry.table += [PSCustomObject]$scriptTable
                }

                $portResult.scriptResult[$scriptItem.id] = [pscustomobject]$scriptResultEntry
            }
            $entry.Ports.Add($portResult) > $null
        }

        # If there is 100% Accuracy OS, show it
        $CertainOS = $hostnode.os.osmatch | where {$_.accuracy -eq 100} | select -first 1
        if ($CertainOS) {$Entry.OS = $certainOS.name; $Entry.OSDetail = $certainOS} else {$Entry.OS=$null}
        $entry.BestGuessOS = ($hostnode.os.osmatch | select -first 1).name
        $entry.BestGuessOSPercent = ($hostnode.os.osmatch | select -first 1).accuracy
        $entry.OSGuesses = $hostnode.os.osmatch
        if (@($entry.OSGuesses).count -lt 1) { $entry.OS = $null }

        if ($hostnode.hostscript -ne $null) {
            $hostnode.hostscript.script | foreach-object {
                $entry.Script += '<HostScript id="' + $_.id + '">' + $OutputDelimiter + ($_.output.replace("`n","$OutputDelimiter")) + "$OutputDelimiter</HostScript> $OutputDelimiter $OutputDelimiter"
            }
        }

        $entry.NmapResult = [PSSerializer]::Deserialize($nmapResult)

        [PSCustomObject]$entry
    }
}