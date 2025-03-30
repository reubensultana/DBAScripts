# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-SoftwareList.ps1

# List Software Installed
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | `
    Select-Object DisplayName,Publisher,InstallDate,DisplayVersion | `
    Format-Table -AutoSize
