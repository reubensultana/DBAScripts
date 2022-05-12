# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/PoSh-OneLiners.ps1

# List Software Installed
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, Publisher, InstallDate, DisplayVersion | Format-Table -AutoSize

# Find Windows Product Key
wmic path softwarelicensingservice get OA3xOriginalProductKey

# IP Scanner
1..255 | ForEach-Object {ping -n 1 -w 15 10.12.13.$_ | select-string "Reply from"}

# Ping with Logging
[string] $cmd = "ping"
$cmd += ".exe"
[string[]] $param = @("www.google.com", "-n", "5")
try { & $cmd $param | ForEach-Object { "{0:s}Z $($_.Trim())" -f $([System.DateTime]::UtcNow) } }
catch { "{0:s}Z ERROR: $($_.Exception.Message)" -f $([System.DateTime]::UtcNow) }

# Create a series of 12 folders
1..12 | ForEach-Object { mkdir $_.ToString().PadLeft(2, "0") }

# Rename files using number values
$Prefix = "IMG"; $i = 1; Get-ChildItem *.* | Where-Object -Property Name -NotLike "$Prefix*"  | ForEach-Object {Rename-Item $_ -NewName ('{0}_{1:D4}{2}' -f $Prefix, $i++, $($_.Extension))}

# Rename files using number values, using the last file number of the series as a starting point
$Prefix = "IMG"; 
[int] $i = $($(Get-ChildItem *.* | Where-Object -Property Name -Like "$Prefix*" | Sort-Object -Descending -Top 1).BaseName.Replace("$($Prefix)_", ""));
if ($null -eq $i) { $i = 1 } else { $i += 1 };
Get-ChildItem *.* | Where-Object -Property Name -NotLike "$Prefix*"  | ForEach-Object {Rename-Item $_ -NewName ('{0}_{1:D4}{2}' -f $Prefix, $i++, $($_.Extension))}

# Change the Console Title
$host.ui.RawUI.WindowTitle = "My PowerShell Session";

# Change the prompt to show current folder without full path and greater than symbol at the end
function prompt { "$( ( Get-Item $pwd ).Name )>" }
# or:
function prompt { "$( Split-Path -leaf -path (Get-Location) )>" }
# or:
function prompt { "$( ( Get-Location | Get-Item ).Name )>" }
