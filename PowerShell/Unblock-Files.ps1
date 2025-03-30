# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Unblock-Files.ps1

[string] $CreationTime = "2023-05-15"
Get-ChildItem -Filter *.zip | Where-Object -Property CreationTime -ge -Value $CreationTime | Unblock-File
