# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/MyPoShProfile.ps1

# Change the Window Title to show the Login running the PoSh session
$host.ui.RawUI.WindowTitle = "Running as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)";
# Change the startup directory to the Public Documents - customise as required
Set-Location -Path "C:\Users\Public\Documents"
Clear-Host

# display the current Public P
Write-Host "Your public IP address is: $($(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content)"

# download and load the Get-RandomPassword from my GitHub repo
[string] $Url = "https://raw.githubusercontent.com/reubensultana/DBAScripts/master/PowerShell/Get-RandomPassword.ps1"
$SplitUrl = $Url.Split("/")
[string] $FileName = $SplitUrl.item($SplitUrl.Count-1)
if ($true -eq $(Test-Path -Path $FileName)) { Remove-Item -Path $FileName -Force}
Import-Module BitsTransfer
Start-BitsTransfer -Source $Url -Description $FileName
. .\$FileName
Remove-Item -Path $FileName -Force
# Usage: Get-RandomPassword 25 | Set-Clipboard
