# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Export-DataToExcel.ps1

# export table/s to an Excel file (installation of Excel not required)
Import-Module dbatools,ImportExcel

[string] $InstanceName = "localhost,14331"
[string] $DatabaseName = "AdventureWorks"

# list of tables to export
$TableList = @(
    "dbo.Table1"
    ,"dbo.Table2"
    ,"dbo.Table3"
)

# report output parameters
[string] $ReportFileName = "00123456"
[string] $ExportFolder = "C:\Users\Public\Documents"
[string] $ExportFileName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')"
[string] $ExportFilePath = "$ExportFolder\$($ReportFileName)_$($InstanceName.replace("\", "$"))_$($DatabaseName)_$($ExportFileName).xlsx"

Write-Output "Export started at {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Write-Output "Exporting to $($ExportFilePath)"

#remove file with same name
if (Test-Path $ExportFilePath -PathType Leaf) { Remove-Item $ExportFilePath -Force }

# export tables to Excel
foreach ($Table in $TableList) {
    Write-Output "Exporting table $($Table)"
    Invoke-DbaQuery -SqlInstance $InstanceName -DatabaseName $DatabaseName -Query "SELECT * FROM $($Table)" -CommandType Text | `
        Export-Excel -Path $ExportFilePath -AutoSize -FreezeTopRow -BoldTopRow -WorksheetName $($Table)
}

Write-Output "Export completed at {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
