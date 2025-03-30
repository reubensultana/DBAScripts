# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Set-ConsoleProperties.ps1

# Change the PowerShell console/window title
# OPTION 1
$host.ui.RawUI.WindowTitle = "My PowerShell Session";
# OPTION 2
$host.ui.RawUI.WindowTitle = "Running as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"

<# -------------------------------------------------- #>

# Change the prompt to show current folder without full path and greater than symbol at the end
# OPTION 1
function prompt { "$( ( Get-Item $pwd ).Name )>" }
# OPTION 2
function prompt { "$( Split-Path -leaf -path (Get-Location) )>" }
# OPTION 3
function prompt { "$( ( Get-Location | Get-Item ).Name )>" }
