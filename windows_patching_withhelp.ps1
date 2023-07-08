<#
https://www.catalog.update.microsoft.com/
https://www.microsoft.com/en-us/edge/business/download
https://code.visualstudio.com/download
https://www.microsoft.com/en-us/wdsi/defenderupdates



#>
# Variables
# File source path; finds location of this script
$sourcePath = (Split-Path -Path $MyInvocation.MyCommand.Path -Parent)+"\"

# Patching year/quarter; gets info for robocopy folder name
$month = Get-Date -Format "MMMM"
$year = Get-Date -Format "yyyy"
switch ($month) {
    {"January", "February", "March" -contains $_} { $Q="Q1" }
    {"April", "May", "June" -contains $_} { $Q="Q2" }
    {"July", "August", "September" -contains $_} { $Q="Q3" }
    {"October", "November", "December" -contains $_} { $Q="Q4" }
                }

$patchFolder = $Q+"Patching"+$year
$patchDir = "Users\Public\Documents\$patchFolder\"

#this is the newfolder the updates are sent to
$destPath = "C:\$patchdir"

#network path for folder on remote machine
$destNPath = "\\$computer\C$\$patchDir"

#wusa and msiexec locations
$wusaLoc = (Get-Command -Name wusa).Source
$msiexecLoc = (Get-Command -Name msiexec).Source

#results file where results will be stored $env:USERNAME
#$resultsFile = "C:\Users\Public\Documents\results.txt"

# Get the list of all machines in the domain excluding server core
$computerList =(Get-ADComputer -Filter {(OperatingSystem -like "*Windows*")-and (Name -like "*wac*") -and (Name -like "*dc*")}| Select-Object -ExpandProperty Name )

        #Robocopy
        foreach ($computer in $computerList) {
        Write-Host "Copying patches to $computer..."

        #copy silently
        robocopy $sourcePath $destNPath /S #/CREATE /E
        Write-Host "Completed copying"
        }








# Install the updates on each machine without rebooting
foreach ($computer in $computerList) {

    # Install the updates on the remote machine using PowerShell remoting
    Invoke-Command -ComputerName $computer -ScriptBlock {

        # Go to folder with files
        Set-Location -Path "C:\Users\Public\Documents\Q2Patching2023\"
        Write-Host $PWD
    
        # Install the cumulative update without rebooting
        Write-Host "Installing Windows Updates"
        $kbUpdate = (Get-ChildItem -Path $PWD -Filter "*kb*.msu").FullName
        Write-Host $kbUpdate
        #Start-Process -FilePath $using:wusaLoc -ArgumentList "`kbUpdate`"", "/quiet", "/norestart"
        Start-Process -FilePath $using:wusaLoc -ArgumentList $kbUpdate, "/norestart", "/quiet"

        # Install the Defender signature update
        Write-Host "Installing Windows Defender Updates"
        $defenderUpdate = (Get-ChildItem -Path .\ -Filter "*mpam-fe*").FullName
        Start-Process -FilePath $defenderUpdate

              # Install the Microsoft Edge update without rebooting
        Write-Host "Installing Edge Updates"
        $edgeUpdate = (Get-ChildItem -Path $PWD -Filter "*MicrosoftEdgeEnterprise*").FullName
        #Start-Process -FilePath $using:msiexecLoc -ArgumentList "/i", $edgeUpdate, "/qn", "/norestart"
        #Start-Process -FilePath $using:msiexecLoc -ArgumentList "/i", "`"$edgeUpdate`"", "/quiet", "/norestart"
        Write-Host $edgeUpdate

        Start-Process -FilePath $edgeUpdate /qn

        
#remove old edge        
         $edgeExecutable = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -Recurse

        $edgeV = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -Recurse | ForEach-Object {
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).ProductVersion
}

$uniqueSortedVersions = ( $edgeV | Select-Object -Unique | Sort-Object -Property { [version]$_ } )

#write-host $uniqueSortedVersions
# Assign the lowest version to $edgeOld
$edgeOld = ($uniqueSortedVersions | Select-Object -First 1)
$edgeNew = ($uniqueSortedVersions | Select-Object -Last 1)

write-host $edgeOld
write-host $edgeNew

Get-Process -NAME *edge* | Stop-Process -force

if (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\$edgeOld")
{
remove-item "C:\Program Files (x86)\Microsoft\Edge\Application\$edgeOld" -Recurse -Force -erroraction stop
}


if (test-path "C:\Program Files (x86)\Microsoft\Edge\Application\new_msedge.exe")
{start-process "C:\Program Files (x86)\Microsoft\Edge\Application\new_msedge.exe" } 
else {start-process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"}
start-sleep -seconds 30
Get-Process -NAME *edge* | Stop-Process -force





        #Stop the Nessus Agent Service (required for update without reboot)
        Stop-Service -Name "Tenable Nessus Agent" -Force

        # Install the Nessus Agent update without rebooting
        Write-Host "Installing Nessus Agent Updates"
        $nessusUpdate = (Get-ChildItem -Path $PWD -Filter "*NessusAgent*.msi").FullName
        #Start-Process -FilePath $using:msiexecLoc -ArgumentList "/i", $nessusUpdate, "/qn", "/norestart" -Wait
        #Start-Process -FilePath $using:msiexecLoc -ArgumentList "/i", "`$nessusUpdate`"", "/quiet", "/norestart"
        #Start-Process -FilePath $nessusUpdate /qn
        #start-process $using:msiexecLoc -argumentlist "/i", $nessusUpdate, "/qn"
        # Install/update the Nessus Agent
        $installProcess = start-process -filepath $using:msiexecLoc -argumentlist "/i", $nessusUpdate, "/qn" -PassThru
        $installProcess.WaitForExit()

        # Check the installation/update exit code
        $exitCode = $installProcess.ExitCode
            if ($exitCode -eq 0) {
            Write-Host "Nessus Update completed successfully."
            } else {
            Write-Host "Nessus Update failed with exit code: $exitCode"
            }
 
        }
        }



























        #Restart the Nessus Agent Service
        #Start-Service -Name "Tenable Nessus Agent"





        #>
        <#
        # Get updated version info
        # Recently Installed Hotfixes
        $KB = @()
        $hotfixes = Get-HotFix | Sort-Object -Property InstalledOn -Descending
        $mostRecentDate = $hotfixes[0].InstalledOn
        $startDate = $mostRecentDate.AddDays(-20)
        $recentHotfixes = ($hotfixes | Where-Object { $_.InstalledOn -ge $startDate })

        foreach ($hotfix in $recentHotfixes) {
                    $hotfixId = $hotfix.HotfixId
                    $KB += $hotfixId
                        }
                                    
        # Reboot Status
        $rebootPending = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA SilentlyContinue) -ne $null
                if ($rebootPending) {
                $rebootStatus = "Yes"
                } else {
                $rebootStatus = "No"
                                 }

        # Defender Signature 
        $defenderV = (Get-MPComputerStatus | Select-Object NISSignatureVersion).NISSignatureVersion

        # Microsoft Edge Version
        $edgeExecutable = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -Recurse | Select-Object -First 1
        $edgeV = (Get-Item $edgeExecutable.FullName).VersionInfo.ProductVersion

        # Nessus Agent Version
        $nessusV = (Get-ItemProperty -Path "HKLM:\Software\Tenable\Nessus Agent").version

        #Create a custom object with the retrieved information
        [PSCustomObject]@{
                "Date:" = $mostRecentDate
                "Reboot:" = $rebootStatus
                "KBs:" = $KB
                "Defender" = $defenderV
                "Edge:" = $edgeV
                "Nessus:" = $nessusV
                                   }
        #Remove Install Files and Folder
        #Remove-Item -Path "$destPath\*" -Recurse -Force
        #empty recycle bin
        #Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        }
        }

        Write-Host "Edge Version will not update until after reboot"
         #idk how to make it go into file| Out-File -Append -FilePath $resultsFile
       
        #Write-Output "Host: $computer`nDate: $kbinstallDate`nReboot: $rebootStatus`nHotfixes: $hotfixID`nDefender: $defenderV`nEdge: $edgeV`nNessus: $nessusV`n`n"

        
        #>




<#
        




$utilList =(Get-ADComputer -Filter {(OperatingSystem -like "*Windows*") -and (Name -like "*util*")} | Select-Object -ExpandProperty Name)




# Get current DC/WAC list and store on Hyper-V Host Machine
foreach ($computer in $utilList) {
    # Get virtual machines with "dc" or "wac" in the name
    $scVM = Get-VM -ComputerName $computer | Where-Object { $_.Name -match "dc|wac" }

    # Create VM.txt file path on remote computer
    $vmTxtFilePath = "\\$computer\c$\Users\Public\Documents\VM.txt"

    # Write virtual machine names to VM.txt file on remote computer
    $scVM.Name | Set-Content -Path $vmTxtFilePath
}
#>
