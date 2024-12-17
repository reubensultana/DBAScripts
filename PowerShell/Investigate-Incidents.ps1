# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Investigate-Incidents.ps1

# General commands used to investigate Incidents

# open a shell on the target server using PowerShell Remoting
Enter-PSSession -ComputerName MyRemoteServer.contoso.com

# Get the last 10 files, sorted by date in descending order; useful when reviewing log files
Get-ChildItem -File | Sort-Object -Descending -Property LastWriteTime | Select-Object LastWriteTime,Name -First 10

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
# NOTE: Stop logging using "Stop-Transcript"

# List all SQL Server services
Get-Service | Where-Object -Property "DisplayName" -Like -Value "*SQL*" | Format-Table -AutoSize
# or
Get-Service "*SQL*" | Format-Table -AutoSize

# get the public IP address
$(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

# delete all files and folders in a directory
# WARNINIG: make sure you know what you're doing!
Get-ChildItem -Path "C:\TEMP" -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# get file sizes in MB and GB
Get-ChildItem -File | `
    Select-Object Name, @{name='SizeMB';expr={[int]($_.Length/1MB)}}, @{name='SizeGB';expr={[int]($_.Length/1GB)}} | `
    Format-Table -AutoSize

# get firewall rules starting with a specific name
[string] $RuleName = "MyCustomRule*"
Get-NetFirewallRule | Where-Object -Property DisplayName -Like -Value $RuleName | Format-Table -AutoSize
Get-FirewallRules | Where-Object -Property Desc -Like -Value $RuleName | Format-Table -AutoSize

# run "telnet" multiple times, with a 2 second delay between retries, outputting the results in table format
1..10 | ForEach-Object { Test-NetConnection -ComputerName 10.20.30.40 -Port 1433; Start-Sleep -Seconds 2 } | Format-Table -AutoSize

# same as above, exporting to CSV
1..10 | ForEach-Object { Test-NetConnection -ComputerName 10.20.30.40 -Port 1433; Start-Sleep -Seconds 2 } | Export-Csv -Path .\telnet.csv -Delimiter "," -NoTypeInformation -NoClobber

# reclaim space used by Docker VHDX
# first stop all services and applications
net stop com.docker.service
taskkill /IM "docker.exe" /F
taskkill /IM "Docker Desktop.exe" /F
wsl --shutdown

# now reclaim inflated disk space
Optimize-VHD -Path $Env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx -Mode Full

# clean up all TEMP directories
@(
    "$($env:TEMP)"
    "$($env:TMP)"
    "$($env:windir)\Temp"
    "$($env:localappdata)\Temp"
) | ForEach-Object { Get-ChildItem -Path $_ -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -ErrorAction SilentlyContinue -Verbose }
