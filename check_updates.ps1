<# Script that gets a list of windows machines in current domain and checks for certain patching updates,
prints them on the screen and then adds them to a results.txt into the folder the script is being run from #>

$computerList =(Get-ADComputer -Filter {(OperatingSystem -like "*Windows*")} | Select-Object -ExpandProperty Name)
$sourcePath =(Split-Path -Path $MyInvocation.MyCommand.Path -Parent)
$date = get-date -format "yyyyMMdd-HHmmss"
$outputFile = "C:\Users\Public\Documents\Results-$date.txt"
$results = @()
# Loop through the list of machines and verify that the patches are installed
foreach ($computer in $computerList) {
    Write-Host "Verifying patches on $computer..."
    # Create a new PSSession to the remote machine
    $session = New-PSSession -ComputerName $computer
    # Verify that the patches are installed on the remote machine
    $kbDInstalled = Invoke-Command -Session $session -ScriptBlock { (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1 InstalledOn).installedon }
    $kbVInstalled = Invoke-Command -Session $session -ScriptBlock { (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1 HotFixID).hotfixid }
    $defenderDInstalled = Invoke-Command -Session $session -ScriptBlock { (Get-MPComputerStatus | Select-Object NISSignatureLastUpdated).NISSignatureLastUpdated }
    $defenderVInstalled = Invoke-Command -Session $session -ScriptBlock { (Get-MPComputerStatus | Select-Object NISSignatureVersion).NISSignatureVersion }
    $nessusInstalled = Invoke-Command -Session $session -ScriptBlock { (get-itemproperty -path "hklm:\software\tenable\Nessus Agent").version }
    #Create a custom object with the retrieved information
    $object = [PSCustomObject]@{
        "ComputerName" = $computer
        "HotFix Date" = $kbDInstalled
        "HotFix Version" = $kbVInstalled
        "Defender Date" = $defenderDInstalled
        "Defender Version" = $defenderVInstalled
        "Nessus Version" = $nessusInstalled
    }
    # Add the object to the results array
    $results += $object
Write-Output "Host: $computer`nHotfixDate: $kbVInstalled`nHotfixVersion: $kbVInstalled`nDefenderDate: $defenderDInstalled`nDefenderVersion: $defenderVInstalled`nNessusVerson: $nessusInstalled`n`n"
}
# Export the results
Write-Host "Results also found at $outputFile"
$results | format-table -autosize | Out-file -filePath $outputFile
