    function InvokeNmapExe ($nmapExe,$argumentList,$computerName,[int]$updateInterval=1,[Switch]$Raw) {
        [Collections.Arraylist]$nmapExeOutput = New-Object Collections.ArrayList
        if (-not $Raw) {
            $ArgumentList += "-oX","-",'--stats-every',"200ms"
        }

        write-verbose "Invoking $nmapexe $argumentList $computerName"

        & $nmapexe $argumentList $computerName | Foreach-Object {
            if ($Raw) {$PSItem} else {
                #Process task entries
                if ($PSItem -match '^<taskprogress') {
                    $taskprogress = ([xml]$PSItem).taskprogress
                    #write-debug "Task $($taskProgress.task) is $([int]($taskProgress.percent))% complete with $($taskProgress.remaining) items left"

                    $ETA = [TimeSpan]::FromSeconds($taskProgress.etc - $taskProgress.time)
                    $WriteProgressParams = @{
                        Id=10
                        Activity = "Invoke-Nmap Scan of $($computername -join ',')"
                        Status = "$($taskProgress.task)"
                        CurrentOperation = "$($taskProgress.remaining) items remaining. ETA $ETA"
                        PercentComplete = $taskProgress.percent
                    }
                    Write-Progress @WriteProgressParams
                } else {
                    Write-Verbose $PSItem
                }

                $nmapExeOutput.Add($PSItem) > $null
            }
        }
        write-progress -id 10 -Activity 'Invoke-Nmap Scan' -Completed
        return $nmapExeOutput

    }