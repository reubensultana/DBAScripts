# --------------------------------------------------------------------------------
# PowerShell Commands for SQL Server Reporting Services
# See also: Microsoft Docs - Report Server Web Service
# https://docs.microsoft.com/en-us/sql/reporting-services/report-server-web-service/report-server-web-service
# --------------------------------------------------------------------------------
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# check if the NuGet provider is installed 
[string] $NuGetVersion = (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue).Version
if (($NuGetVersion -eq "") -or ($NuGetVersion -lt "2.8.5.201")) {
    # install the package
    Write-Host "NuGet provider is required to continue. Installing..." 
    Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force
}

# check if the SSRS Tools are installed - https://github.com/Microsoft/ReportingServicesTools
[string] $SSRSToolsCheck = (Get-Module "ReportingServicesTools" -ErrorAction SilentlyContinue).Name
if ($SSRSToolsCheck -eq "") {
    # install the package
    Write-Host "Reporting Services Tools are missing. Installing..." 
    Install-Module -Name "ReportingServicesTools" -Force
}

# list available commands for this module
Get-Command -Module "ReportingServicesTools"

# using SQL Server Performance Dashboard Reports as sample reports
# a zip file containing the reports can be downloaded from GitHub at:
# https://github.com/Microsoft/tigertoolbox/raw/master/SQL-performance-dashboard-reports/SQL%20Server%20Performance%20Dashboard%20Reporting%20Solution.zip

# for the sake of this example the reports will be extracted to the C:\TEMP\SSRSDemo folder

# define variables to connect to our SSRS environment
[string] $ServerName = "localhost"
[string] $HttpProtocol = "http" # enter "http" or "https"
[string] $SSRSUri = "$($HttpProtocol)://$ServerName/ReportServer/ReportService2010.asmx?wsdl"
[string] $SSRSInstanceName = "SSRS"
# define the connection security values
$LoginName = "Domain01\User01"
$LoginSecret = ConvertTo-SecureString -String "P@sSwOrd" -AsPlainText -Force
$Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $LoginName, $LoginSecret
# ...or avoid typing credentials in plain test and prompt the user...
$Credential = Get-Credential -Message "Authenticate with $SSRSInstanceName instance on $ServerName"


# create a Proxy for the SSRS connection
$SSRSWebProxy = New-RsWebServiceProxy -ReportServerUri $SSRSUri -Credential $Credential
# ...or...
# connect to the SSRS instance
# Connect-RsReportServer -ComputerName $ServerName -ReportServerInstance $SSRSInstanceName -ReportServerUri $SSRSUri -ReportServerVersion "SQLServer2017" -Credential $Credential

# NOTE: (procedure to be tested)
# Connections will fail with the message "There was an error downloading 'https://localhost/ReportServer/ReportService2010.asmx'." 
#  when the SSRS service is set to start up using the Virtual Account. Recommendation is to use a Domain Account instead.
# Tested with HTTP (i.e. not HTTPS) and Proxy connection worked. Might be an issue with the Certificate...


[string] $SSRSFolder = "SSRS_Demo"
[string] $SSRSFolderDescription = "SQL Server Performance Dashboard"
[string] $LocalReportFolder = "C:\TEMP\SSRS_Demo\SQL Server Performance Dashboard"
[string] $LocalOutputFolder = "C:\TEMP\SSRS_Out"

# list items in root
Get-RsFolderContent -Proxy $SSRSWebProxy -RsFolder "/"


# create a new folder in the SSRS root
New-RsFolder -Proxy $SSRSWebProxy -RsFolder "/" -FolderName $SSRSFolder -Description $SSRSFolderDescription -Verbose | Out-Null


# deploy a single report
Write-RsCatalogItem -Proxy $SSRSWebProxy -Path "$LocalReportFolder\performance_dashboard_main.rdl" -Destination "/$SSRSFolder" -Verbose


# remove a single report
Remove-RsCatalogItem -Proxy $SSRSWebProxy -Path "/$SSRSFolder/performance_dashboard_main" -Verbose


# deploy report items in an entire folder with Write-RsFolderContent
Write-RsFolderContent -Proxy $SSRSWebProxy -Path "$LocalReportFolder\" -Destination "/$SSRSFolder" -Verbose


# list items in the new folder
Get-RsFolderContent -Proxy $SSRSWebProxy -RsFolder "/$SSRSFolder" -Recurse
# piping them to the Out-GridView cmdlet gives you a UI
Get-RsFolderContent -Proxy $SSRSWebProxy -RsFolder "/$SSRSFolder" -Recurse | Out-GridView


# export a single catalog item (report) to file system
Out-RsCatalogItem -Proxy $SSRSWebProxy -RsItem "/$SSRSFolder/performance_dashboard_main" -Destination "$LocalOutputFolder/$SSRSFolder" -Verbose


# export ALL catalog items to file system
Out-RsFolderContent -Proxy $SSRSWebProxy -RsFolder "/" -Destination $LocalOutputFolder -Recurse -Verbose


# remove all report items in a folder 
$SSRSReports = Get-RsFolderContent -Proxy $SSRSWebProxy -RsFolder "/$SSRSFolder" -Recurse | Where-Object -Property TypeName -eq -Value "Report"
foreach ($Report in $SSRSReports) { Remove-RsCatalogItem -Proxy $SSRSWebProxy -Path ($Report.Path) -Verbose -Confirm:$false -ErrorAction SilentlyContinue }


# remove the sample folder
Remove-RsCatalogItem -Proxy $SSRSWebProxy -Path "/$SSRSFolder" -Verbose -Confirm:$false
