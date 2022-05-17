# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-SqlServerVersions.ps1

# NOTE: The information retrieved is based on data https://www.sqlserverversions.com/

# retrieve all versions, service packs, patches, hotfixes, updates, etc. (6.0 to date)
Add-Type -Assembly System.Web # [System.Web.HttpUtility]::UrlEncode() needs this

[string] $Query = "select *"
[string] $URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = Invoke-WebRequest $URL
$SqlServerVersions.Content | ConvertFrom-Csv | Out-GridView


# same as above, however limiting results to the 2017 version
Add-Type -Assembly System.Web # [System.Web.HttpUtility]::UrlEncode() needs this

[string] $SqlVersion = "2017"
[string] $Query = "select * where A='" + $SqlVersion + "'"
[string] $URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = Invoke-WebRequest $URL
$SqlServerVersions.Content | ConvertFrom-Csv | Out-GridView



# retrieve the latest build for all versions (6.0 to date)
Add-Type -Assembly System.Web # [System.Web.HttpUtility]::UrlEncode() needs this

[string] $Query = "select *"
[string] $URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = $(Invoke-WebRequest $URL).Content | ConvertFrom-Csv
# $SqlServerVersions | Out-GridView

$UniqueVersions = $SqlServerVersions | Select-Object -Property "SqlServer" -Unique
# $UniqueVersions | Out-GridView

$LatestRelease = $UniqueVersions | ForEach-Object { $SqlServerVersions | Where-Object -Property "SqlServer" -EQ -Value $_.SqlServer | Sort-Object -Property "ReleaseDate" -Descending | Select-Object * -First 1 }
# $LatestRelease | Out-GridView

$LatestRelease | Export-Csv -Path .\SqlServerBuilds.csv -Force -NoClobber -NoTypeInformation
