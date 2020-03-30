function InvokeNmapExe ($argumentList,$computerName) {
<#
.SYNOPSIS
Starts Nmap with supplied argument list and computername list
.NOTES
This function primarily exists to be mocked by Pester
#>
    $nmapexe = (Get-Command nmap).path
    & "$nmapexe" $argumentList $computerName
}

function StartNmap ($argumentList,$computerName,[int]$updateInterval=200,[Switch]$Raw) {
    if (-not $Raw) {
        $ArgumentList += "-oX","-",'--stats-every',"${updateInterval}ms"
    }

    write-verbose "Invoking nmap $argumentList $computerName"
    InvokeNmapExe $argumentList $computerName | Foreach-Object {
        if ($Raw) {$PSItem} else {
            #Strip taskprogress items and report them as progress instead
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
                $PSItem
            }
        }
    }

    write-progress -id 10 -Activity 'Invoke-Nmap Scan' -Completed
}

