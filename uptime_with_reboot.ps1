#Uptime with Reboot
<# This script gets a list of all windows machines and prints with their uptimes, then
gives the user the option to reboot certain ones#>

$computers = Get-ADComputer -Filter { OperatingSystem -like "*Windows*" } | Select-Object -ExpandProperty Name

$logfile = "C:\Users\Public\" + (Get-Date -Format "yyyyMMdd_HHmmss") + "_uptime_log.txt"

$uptimes = @()

foreach ($computer in $computers) {
    $lastBootTime = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computer).LastBootUpTime
    $uptimeDuration = (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBootTime)
    $uptimeString = $uptimeDuration.Days.ToString("D2") + " days, " + $uptimeDuration.Hours.ToString("D2") + " hours, " + $uptimeDuration.Minutes.ToString("D2") + " minutes"

    $uptimes += @{
        Number         = $null  # Placeholder for the numbering
        Computer       = $computer
        Uptime         = $uptimeString
        UptimeDuration = $uptimeDuration  # New property to store the duration as a TimeSpan object
    }
}

#$uptimes = $uptimes | Sort-Object -Property UptimeDuration -Descending
$uptimes = $uptimes | Sort-Object -Property UptimeDuration


Write-Host "Uptime Information:"
$index = 1
$uptimes | ForEach-Object {
    $_.Number = $index++
    Write-Host "$($_.Number): $($_.Computer) - $($_.Uptime)"
}

$rebootList = Read-Host "Enter the index numbers of the machines to reboot (separated by commas) or 'N' to end the script"
if ($rebootList -eq "N" -or $rebootList -eq "n") {
    Write-Host "Script ended. No machines were rebooted."
}
else {
    $rebootIndices = $rebootList.Split(",").ForEach({ $_.Trim() })
    $rebootMachines = $uptimes | Where-Object { $rebootIndices -contains $_.Number } | ForEach-Object { $_.Computer }

    if ($rebootMachines) {
        Write-Host "Are you sure you want to reboot the following machines?"
        $rebootMachines

        $confirm = Read-Host "Enter 'Y' to confirm or any other key to cancel"
        if ($confirm -eq "Y" -or $confirm -eq "y") {
            $credentials = Get-Credential -Message "Enter your credentials to reboot the machines"

            foreach ($machine in $rebootMachines) {
                Write-Host "Rebooting $machine..."
                Restart-Computer -ComputerName $machine -Credential $credentials -Force
            }

            Write-Host "Machines rebooted successfully."
        }
        else {
            Write-Host "Reboot canceled. No machines were rebooted."
        }
    }
    else {
        Write-Host "No valid machine numbers provided. No machines will be rebooted."
    }
}
