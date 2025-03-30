# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-Series.ps1

# Create a series of 12 directories
1..12 | ForEach-Object { mkdir $_.ToString().PadLeft(2, "0") }

# determine the date 28 days from today, and every 28 days thereafter for the next 6 months
[int] $Increment = 28; [int] $Periods = 6; [datetime] $StartDate = Get-Date; [int] $i = 0; while ($i -lt $Periods) {$i+=1; $StartDate = $StartDate.AddDays($Increment); Write-Host $StartDate.ToShortDateString()}
