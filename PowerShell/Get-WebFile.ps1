# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-WebFile.ps1

# OPTION 1 - Using BitsTransfer
Import-Module BitsTransfer
[string] $BaseUri = "https://aka.ms/ssmsfullsetup"
[string] $FileName = "SSMS-Setup-ENU.exe"
[string] $TargetDir = "$($env:USERPROFILE)\Downloads"
[datetime] $StartTime = Get-Date

Start-BitsTransfer -Source "$($BaseUri)" -Destination "$($TargetDir)\$($FileName)"
Write-Output "Time taken: $((Get-Date).Subtract($StartTime).Seconds) second(s)"

<# -------------------------------------------------- #>

# OPTION 2 - Using System.Net.WebClient
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[string] $BaseUri = "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/"
[string] $FileName = "AdventureWorks2022.bak"
[string] $TargetDir = "$($env:USERPROFILE)\Downloads"
[datetime] $StartTime = Get-Date

[string] $UriNamespace = ""
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers['x-emc-namespace'] = $UriNamespace

$WebClient.DownloadFile("$($BaseUri)\$($FileName)", "$($TargetDir)\$($FileName)")
Write-Output "Time taken: $((Get-Date).Subtract($StartTime).Seconds) second(s)"
