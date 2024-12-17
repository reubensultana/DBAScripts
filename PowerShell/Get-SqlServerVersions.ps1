# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-SqlServerVersions.ps1

# NOTE: The information retrieved is based on data from https://www.sqlserverversions.com/

# 1 ----------
# retrieve all versions, service packs, patches, hotfixes, updates, etc. (6.0 to date)
Add-Type -Assembly System.Web # [System.Web.HttpUtility]::UrlEncode() needs this

[string] $Query = "select *"
[string] $URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = Invoke-WebRequest $URL
$SqlServerVersions.Content | ConvertFrom-Csv | Out-GridView


# 2 ----------
# same as above, however limiting results to the 2017 version
Add-Type -Assembly System.Web # [System.Web.HttpUtility]::UrlEncode() needs this

[string] $SqlVersion = "2017"
[string] $Query = "select * where A='" + $SqlVersion + "'"
[string] $URL   = "https://docs.google.com/spreadsheets/d/16Ymdz80xlCzb6CwRFVokwo0onkofVYFoSkc7mYe6pgw/gviz/tq?tq=" + [System.Web.HttpUtility]::UrlEncode($Query) + "&tqx=out:csv"

$SqlServerVersions = Invoke-WebRequest $URL
$SqlServerVersions.Content | ConvertFrom-Csv | Out-GridView


# 3 ----------
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


# 4 ----------
# another approach, using a spreadsheet maintained and hosted by Microsoft
Clear-Host
# retrieve all version, service packs, patches, hostfixes, updates, etc. (2005 to date)
# Install-Module ImportExcel
Import-Module ImportExcel

[string] $SqlServerBuilds = "./SqlServerBuilds.xlsx"
[string] $URL = "https://aka.ms/sqlserverbuilds"

# download file
Remove-Item -Path $SqlServerBuilds -Force -ErrorAction SilentlyContinue | Out-Null
Invoke-WebRequest -Uri $URL -OutFile $SqlServerBuilds

# supported versions
# $Years = @("2016", "2017", "2019", "2022")
$Years = $((Get-Date).AddYears(-10).Year)..$((Get-Date).Year)
$Years | ForEach-Object {
    Import-Excel -Path $SqlServerBuilds -WorksheetName $_ -EndRow 2 -ErrorAction SilentlyContinue
} | Select-Object "Build Number","KB Number","KB URL","Cumulative Update or Secudity ID" | Format-Table -AutoSize

# open the spreadsheet
Start-Process -FilePath $SqlServerBuilds
