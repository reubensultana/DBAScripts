# General commands used to investigate Incidents

# open a shell on the target server using PowerShell Remoting
Enter-PSSession -ComputerName MyRemoteServer.contoso.com

# Get the last 10 files, sorted by date in descending order; useful when reviewing log files
Get-ChildItem | Sort-Object -Descending -Property LastWriteTime | Select-Object LastWriteTime,Name -First 10

# Output the contents of a file to the console
Get-Content -Path "C:\TEMP\mylog.txt" -Raw

# Copy the contents of a file to Clipbiard
Get-Content -Path "C:\TEMP\mylog.txt" -Raw | Set-Clipboard

# Retrieve details for the last reboots (Event ID 1074) today
Get-WinEvent -FilterHashtable @{logname='System'; id=1074} -MaxEvents 5 -ErrorAction SilentlyContinue | `
    Where-Object -Property TimeCreated -Value $(Get-Date -Format "yyyy-MM-dd").ToString() -GE | `
    Format-Table -Wrap

# Get volume size and space available
Get-Volume | Select-Object PSComputerName,HealthStatus,DriveType,DriveLetter,FileSystem,FileSystemLabel, @{name='SizeMB';expr={[int]($_.Size/1MB)}},@{name='FreeMB';expr={[int]($_.SizeRemaining/1MB)}}, @{name='SizeGB';expr={[int]($_.Size/1GB)}},@{name='FreeGB';expr={[int]($_.SizeRemaining/1GB)}}, @{name='PercentFree';expr={[int](($_.SizeRemaining/$_.Size)*100)}} -Unique | Format-Table -AutoSize

# Change the PowerShell console/window title
$host.ui.RawUI.WindowTitle = "Running as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"

# Log all commands to a text file
Set-Location -Path "C:\Users\Public\Documents"
[string] $LogFolder = "$($(Get-Location).Path))\LOG"
[string] $LogFileName = "PoSh_Transcript_$(Get-Date -Format 'yyyyMMdd')"
[string] $LogFilePath = "$($LogFolder)\$($LogFileName).txt"
Start-Transcript -Path $LogFilePath -Append -IncludeInvocationHeader -NoClobber
Clear-Host
# Stop logging using "Stop-Transcript"

# List SQL Server servics
Get-Service | Where-Object -Property "DispolyName" -Like -Value "*SQL*"

