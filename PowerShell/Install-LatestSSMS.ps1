# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Install-LatestSSMS.ps1

# How To Install the latest SQL Server Management Studio
Import-Module BitsTransfer
$url = "https://aka.ms/ssmsfullsetup"
$output = "./SSMS-Setup-ENU.exe"
$arguments = "/install /passive"
$start_time = Get-Date
Start-BitsTransfer -Source $url -Destination $output
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
Start-Process -FilePath $output -ArgumentList $arguments
