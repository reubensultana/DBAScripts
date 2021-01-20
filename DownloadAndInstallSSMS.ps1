# How To Install SQL Server Management Studio 2018 (v18.3)
Import-Module BitsTransfer
$url = "https://aka.ms/ssmsfullsetup"
$output = "./SSMS-Setup-ENU.exe"
$arguments = "/install /passive"
$start_time = Get-Date
Start-BitsTransfer -Source $url -Destination $output
Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"
Start-Process -FilePath $output -ArgumentList $arguments
