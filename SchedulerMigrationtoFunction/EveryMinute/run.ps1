# Input bindings are passed in via param block.
param($Timer,[String[]] $InputBlob)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()
$originalUTCTime= (Get-Date -Year 2019 -Month 1 -Day 1 -Hour 0 -minute 0 -second 0).ToUniversalTime()
# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}


$jobs = $InputBlob -split "`r`n|`r|`n"

foreach ($job in $jobs){  
    if($job)
    {
        $jobName       = $job.split(",")[1]
        $uri           = $job.split(",")[2]
        $requestMethod = $job.split(",")[3]
        $interval      = [int] ($job.split(",")[4]).replace("Every","").replace("Minutes","").Trim()
        if(((New-TimeSpan -Start $originalUTCTime -End $currentUTCtime).Minutes / $interval ) -is [int])
        {
            $response= Invoke-WebRequest $uri -Method $requestMethod   
            "Returned status code for"+ $jobName + " is" + $response.StatusCode.tostring()
        }       
    }  
}
