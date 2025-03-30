# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Set-FileNames.ps1

# OPTION 1: Rename files using number values
$Prefix = "IMG"; $i = 1; Get-ChildItem *.* | Where-Object -Property Name -NotLike "$Prefix*"  | ForEach-Object {Rename-Item $_ -NewName ('{0}_{1:D4}{2}' -f $Prefix, $i++, $($_.Extension))}


# OPTION 2: Rename files using number values, using the last file number of the series as a starting point
$Prefix = "IMG"; 
[int] $i = $($(Get-ChildItem *.* | Where-Object -Property Name -Like "$Prefix*" | Sort-Object -Descending -Top 1).BaseName.Replace("$($Prefix)_", ""));
if ($null -eq $i) { $i = 1 } else { $i += 1 };
Get-ChildItem *.* | Where-Object -Property Name -NotLike "$Prefix*"  | ForEach-Object {Rename-Item $_ -NewName ('{0}_{1:D4}{2}' -f $Prefix, $i++, $($_.Extension))}
