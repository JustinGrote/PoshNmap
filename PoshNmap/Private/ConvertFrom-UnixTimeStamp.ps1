function ConvertFrom-UnixTimestamp{
    param (
        [int]$UnixTimestamp=0,
        #Specify if you wish the time to be returned as UTC instead of the current timezone
        [switch]$AsUTC
    )

    #Unix Epoch Start (1/1/1970 12:00:00am UTC)
    [datetime]$origin = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)

    $result = $origin.AddSeconds($UnixTimestamp)

    if (!($AsUTC)) {
        $result = [System.TimeZone]::CurrentTimeZone.ToLocalTime($result)
    }

    $result
}