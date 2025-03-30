# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Test-NetConnections.ps1

# IP Scanner
# OPTION 1
[string] $IpRange = "10.20.30."
1..255 | ForEach-Object {ping -n 1 -w 15 "$($IpRange)$($_)" | select-string "Reply from"}

# OPTION 2
[string] $IpRange = "10.20.30."
1..255 | ForEach-Object { Test-NetConnection -ComputerName "$($IpRange)$($_)"} | Format-Table -AutoSize

<# -------------------------------------------------- #>

# Ping with Logging
[string] $cmd = "ping"
$cmd += ".exe"
[string[]] $param = @("www.google.com", "-n", "5")
try { & $cmd $param | ForEach-Object { "{0:s}Z $($_.Trim())" -f $([System.DateTime]::UtcNow) } }
catch { "{0:s}Z ERROR: $($_.Exception.Message)" -f $([System.DateTime]::UtcNow) }

<# -------------------------------------------------- #>

# run "telnet" multiple times, with a 2 second delay between retries, outputting the results in table format
[string] $IpAddress = "10.20.30.40"
[string] $PortNumber = "1433"
1..10 | ForEach-Object { Test-NetConnection -ComputerName $IpAddress -Port $PortNumber; Start-Sleep -Seconds 2 } | Format-Table -AutoSize

# same as above, exporting to CSV
[string] $IpAddress = "10.20.30.40"
[string] $PortNumber = "1433"
[string] $OutputFilePath = ".\telnet.csv"
1..10 | ForEach-Object { Test-NetConnection -ComputerName $IpAddress -Port $PortNumber; Start-Sleep -Seconds 2 } | Export-Csv -Path $OutputFilePath -Delimiter "," -NoTypeInformation -NoClobber
