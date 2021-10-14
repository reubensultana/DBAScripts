# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Init-PoShConsole.ps1

# start a new console, replacing the Window Title value with the Current User Name, and logging all local commands to a file
$host.ui.RawUI.WindowTitle = "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)";
Set-Location -Path "C:\Users\Public\Documents";
[string] $LogFolder = "$($(Get-Location).Path)\Log";
[string] $LogFileName = "$(Get-Date -Format 'yyyyMMdd')";
[string] $LogFilePath = "$($LogFolder)\$($LogFileName).log";
Start-Transcript -Path $LogFilePath -Append -IncludeInvocationHeader -NoClobber;
Clear-Host;


# start a new console, replacing the Window Title value with the Current User Name
$host.ui.RawUI.WindowTitle = "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)";
Set-Location -Path "C:\Users\Public\Documents";
Clear-Host;
