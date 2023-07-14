<# THIS SCRIPT IS A WORK IN PROGRESS #>
<#step 1: stage all files in 1 location in enclave including script,
#typically the following:
 1. windows kb.msu 
 2. windows defender av signature
 3. edge update.
 4. nessus agent
 #>



# Variables
# File source path; basically run this script and it will start naming stuff based on its location. 
$sourcePath =(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)+ "\"
# Patching year/quarter (grabs date info to make a new folder when robocopying files. easier for manual cleanup
$month = Get-Date -Format "MMMM"
$year = Get-Date -Format "yyyy"
switch ($month) {
        {"January", "February", "March" -contains $_} { $Q="Q1" }
        {"April", "May", "June" -contains $_} { $Q="Q2" }
        {"July", "August", "September" -contains $_} { $Q="Q3" }
        {"October", "November", "December" -contains $_} { $Q="Q4" }
}
#Write-Host  $Q"Patching"$year

# Get the list of all machines in the domain
$computerList =(Get-ADComputer -Filter {(OperatingSystem -like "*Windows*") -and (Name -notlike "*dc*") -and (Name -notlike "*wac*")} | Select-Object -ExpandProperty Name )
#get separate list for the util machines to do the for loop for the server core machines
$utilList =(Get-ADComputer -Filter {(OperatingSystem -like "*Windows*") -and (Name -like "*util*")} | Select-Object -ExpandProperty Name)

#robocopy loop to windows machines using the folder name from the date
foreach ($computer in $computerList) {
Write-Host "Copying patches to $computer..."
$destPath = ("\\" + $computer + "\C$\users\public\documents\$Q-Patching-$year\")
robocopy $sourcePath $destPath /E /COPYALL }
<#

server core help pls
need to make sure setting allows remote copy AND execute in settings somewhere
this part is a mess; i am using copy-vmfile bc i know it works but i think im murky on using invoke for the remote util to run it? 
yes i know i need to do the copy part before installing
and then when i go to actually execute on the server core machines, i think i need new pssession directly from the machine i am on to the server core, BUT
i need to check if that is allowed since I usually just use "connect" from hyper-v

#>
foreach ($computer in $utilList) {
$scVM = (Get-VM | Where-Object { $_.Name -like "*DC*" -or $_.Name -like "*WAC*" }).Name
        foreach ($computer in $scVM) {
                $session = New-PSSession -ComputerName $computer
                $installPath = "\C:\users\public\documents\$Q-Patching-$year\"
                $kbPatch =($installPath + (Get-ChildItem -Path $destPath -Filter "*kb*.msu").Name)
                $defenderPatch =$installPath + (Get-ChildItem -Path $destPath -Filter "*mpam*.exe").Name
                $nessusPatch =$installPath + (Get-ChildItem -Path $destPath -Filter "*NessusAgent*.msi").Name
                $edgePatch =$installPath + (Get-ChildItem -Path $destPath -Filter "*Edge*.msi").Name
<#copy to server core #>
        Invoke-Command -Session $session -ScriptBlock 
                { 
                        Copy-VMFile -Name $scVM -SourcePath $kbPatch -DestinationPath "C:\users\$env:USERNAME" -FileSource Host
                        Copy-VMFile -Name $scVM -SourcePath $defenderPatch -DestinationPath "C:\users\$env:USERNAME" -FileSource Host
                        Copy-VMFile -Name $scVM -SourcePath $nessusPatch -DestinationPath "C:\users\$env:USERNAME" -FileSource Host
                        Copy-VMFile -Name $scVM -SourcePath $edgePatch -DestinationPath "C:\users\$env:USERNAME" -FileSource Host
                }
        }
}

<#
install on remaining windows machines
need help with using network path or local path for installing
$destPath is already the network path above from robocopy
$installPath would be local
#>
foreach ($computer in $computerList) {
Write-Host "Installing patches on $computer..."

$installPath = "\C:\users\public\documents\$Q-Patching-$year\"

$session = New-PSSession -ComputerName $computer
#this looks at all the file names and gives them variables so i don't have to worry about crazy names (like copy of copy of etc.)
$kbPatch =($installPath + (Get-ChildItem -Path $destPath -Filter "*kb*.msu").Name)
$defenderPatch =$installPath + (Get-ChildItem -Path $destPath -Filter "*mpam*.exe").Name
$nessusPatch =$installPath + (Get-ChildItem -Path $destPath -Filter "*NessusAgent*.msi").Name
$edgePatch =$installPath + (Get-ChildItem -Path $destPath -Filter "*Edge*.msi").Name
#need big help here (actual patching lol)
Invoke-Command -Session $session -ScriptBlock { Start-Service -Name wuauserv }
Invoke-Command -Session $session -ScriptBlock { Stop-Service -Name "Tenable Nessus Agent" -Force }
#Invoke-Command -Session $session -ScriptBlock { dism.exe /online /add-package /PackagePath:$using:kbPatch /norestart }
Invoke-Command -Session $session -ScriptBlock { Start-Process wusa.exe -ArgumentList `"$filePath`", "/quiet /norestart" -NoNewWindow}
Invoke-Command -Session $session -ScriptBlock { Start-Process -FilePath "$using:defenderPatch" -ArgumentList "/q /norestart" -Wait }
Invoke-Command -Session $session -ScriptBlock { Start-Process -FilePath "msiexec.exe" -ArgumentList "/q", "$using:nessusPatch", "/norestart" }
Invoke-Command -Session $session -ScriptBlock { Start-Process -FilePath "msiexec.exe" -ArgumentList "/q", "$using:edgePatch", "/norestart" }
Invoke-Command -Session $session -ScriptBlock { Start-Service -Name "Tenable Nessus Agent" }
#Invoke-Command -Session $session -ScriptBlock { Remove-Item -Path $using:destPath -Recurse -Force }
Write-Host "Finishing up"
}

#would like to clean up all sessions at the end
#Get-PSSession | Remove-PSSession
#would like to have results printout; can use the other one here?
