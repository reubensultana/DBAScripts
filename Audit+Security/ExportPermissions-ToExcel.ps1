# Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/ExportPermissions-ToExcel.ps1

Import-Module dbatools,ImportExcel

# report output parameters
[string] $ReportFileName = "PermissionsReport"
[string] $ExportFolder = "C:\Users\Public\Documents"
[string] $ExportFileName = "$(Get-Date -Format 'yyyyMMdd_HHmmss')"
[string] $ExportFilePath = "$ExportFolder\$($ReportFileName)_$($ExportFileName).xlsx"

# list of instances to report on
$Instances = @(
    "localhost,14331"
    ,"localhost,14332"
    ,"localhost,14333"
)

Write-Host $("Export started at {0}" -f $(Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host "Output file: $ExportFilePath"

# remove any file with the same name
if (Test-Path -Path $ExportFilePath -PathType Leaf) { Remove-Item -Path $ExportFilePath -Force }

# export data
foreach ($Instance in $Instances) {
    Write-Host "Processing $Instance"
    Get-DbaUserPermission -SqlInstance $Instance | Export-Excel -Path $ExportFilePath -AutoSize -FreezeTopRow -BoldTopRow -WorksheetName $($Instance.replace("\", "$"))
}

Write-Host $("Export completed at {0}" -f $(Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
