    #We wrap the nmap execution in a function so we can mock test it with Pester
    function Invoke-NmapExe ($nmapExe,$argumentList,$computerName,[int]$updateInterval=1) {
        [Collections.Arraylist]$nmapExeOutput = New-Object Collections.ArrayList
        $argumentList += '-v','--stats-every',"200ms"
        write-verbose "Invoking $nmapexe $argumentList $computerName"

        & $nmapexe -v $argumentList $computerName | Foreach-Object {
            #Process task entries
            if ($PSItem -match '^<taskprogress') {
                $taskprogress = ([xml]$PSItem).taskprogress
                #write-debug "Task $($taskProgress.task) is $([int]($taskProgress.percent))% complete with $($taskProgress.remaining) items left"

                $ETA = [TimeSpan]::FromSeconds($taskProgress.etc - $taskProgress.time)
                $WriteProgressParams = @{
                    Id=10
                    Activity = "Invoke-Nmap Scan of $($computername -join ',')"
                    Status = "$($taskProgress.task)"
                    CurrentOperation = "$($taskProgress.remaining) hosts remaining. ETA $ETA"
                    PercentComplete = $taskProgress.percent
                }
                Write-Progress @WriteProgressParams
            }

            $nmapExeOutput.Add($PSItem) > $null
        }

        return $nmapExeOutput
    }