# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Set-DailyTranscript.ps1

# Can be added to the PowerShell Profile to start automatically whenever a PowerShell session is started

# Log all commands to a text file
Set-Location -Path "C:\Users\Public\Documents"
[string] $LogFolder = "$($(Get-Location).Path))\LOG"
[string] $LogFileName = "PoSh_Transcript_$(Get-Date -Format 'yyyyMMdd')"
[string] $LogFilePath = "$($LogFolder)\$($LogFileName).txt"
Start-Transcript -Path $LogFilePath -Append -IncludeInvocationHeader -NoClobber
Clear-Host
# NOTE: Stop logging using "Stop-Transcript"
