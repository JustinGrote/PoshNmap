
function FormatNmapOutputSummary ($nmapRun) {

    #Parse the scanned services list
    foreach ($scanInfoItem in $nmaprun.scaninfo) {
        #In the original XML, ranges of ports are summarized, e.g., "500-522"
        #Desummarize and convert each port into an explicit object
        $nmapRunServices = foreach ($serviceItem in $($scanInfoItem.services.replace("-","..")).Split(",")) {
            if ( $serviceItem -like "*..*" ) {
                $serviceItem = invoke-expression "$serviceItem"
            }
            foreach ($service in $serviceItem) {
                [PSCustomObject][ordered]@{
                    Protocol = $scanInfoItem.protocol
                    ScanType = $scanInfoItem.type
                    Service = [int]$service
                }
            }
        }

        #Generate the run summary information
        [PSCustomObject][Ordered]@{
            PSTypeName = 'PoshNmapSummary'
            Scanner = $nmaprun.scanner
            Version = $nmaprun.version
            Arguments = $nmaprun.args
            XmlOutputVersion = $nmaprun.xmloutputversion
            ScanResult = $nmaprun.runstats.finished.exit
            StartTime = ConvertFrom-UnixTimeStamp $nmaprun.start
            FinishedTime = ConvertFrom-UnixTimeStamp $nmaprun.runstats.finished.time
            ElapsedSeconds = $nmaprun.runstats.finished.elapsed
            HostsTotal = $nmaprun.runstats.hosts.total
            HostsUp = $nmaprun.runstats.hosts.up
            HostsDown = $nmaprun.runstats.hosts.down
            VerboseLevel = $nmaprun.verbose.level
            DebugLevel = $nmaprun.verbose.level
            ServicesScanned = $nmapRunServices
            RawXML = $nmaprun
        }
    } #nmaprunservices = foreach

} #If SummaryOnly

