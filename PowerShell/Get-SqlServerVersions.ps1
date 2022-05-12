# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-SqlServerVersions.ps1

# NOTE: The information retrieved is based on data https://www.sqlserverversions.com/


# retrieve all versions, service packs, patches, hotfixes, updates, etc. (6.0 to date)
$Query = "select *"
$URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = Invoke-WebRequest $URL
$SqlServerVersions.Content | ConvertFrom-Csv | Out-GridView


# same as above, however limiting results to the 2017 version
$SqlVersion = "2017"
$Query = "select * where A='" + $SqlVersion + "'"
$URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = Invoke-WebRequest $URL
$SqlServerVersions.Content | ConvertFrom-Csv | Out-GridView
