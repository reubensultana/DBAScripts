# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-RegionalSettings.ps1

# get machine system locale (regional settings)
# OPTION 1
Get-ComputerInfo | Select-Object -Property WindowsProductName,CsName,OsLocale,OsLocalDateTime,OsLanguage,TimeZone
# OPTION 2
Get-WinSystemLocale
