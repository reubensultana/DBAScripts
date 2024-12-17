[string] $SourceServerName = ""
[string] $TargetServerName = ""
[string] $LocalOutputDir = "$($env:USERPROFILE)\Downloads\SSRSReports"

Install-Module -Name ReportingServicesTools -Force -Scope CurrentUser

# define the connection security values
$Credential = Get-Credential -Message "Authenticate to SSRS instances using"

# source variables
[string] $SourceHttpProtocol = "http" # must be one of "http" or "https"
[string] $SourceSsrsUri = "$($SourceHttpProtocol)://$($SourceServerName)/ReportServer/ReportServices2010.asmx?wsdl"

$SourceSsrsWebProxy = New-RsWebServiceProxy -ReportServerUri $SourceSsrsUri -Credential $Credential

# target variables
[string] $TargetHttpProtocol = "http" # must be one of "http" or "https"
[string] $TargetSsrsUri = "$($TargetHttpProtocol)://$($TargetServerName)/ReportServer/ReportServices2010.asmx?wsdl"

$TargetSsrsWebProxy = New-RsWebServiceProxy -ReportServerUri $TargetSsrsUri -Credential $Credential

# create the local directory
New-Item -Path $LocalOutputDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# export ALL catalog items from SOURCE to File System
Out-RsFolderContent -Proxy $SourceSsrsWebProxy -RsFolder "/" -Destination $LocalOutputDir -Recurse -Verbose

# deploy entire Directory Structure to TARGET
Write-RsFolderContent -Proxy $TargetSsrsWebProxy -Path "$($LocalOutputDir)\" -Destination "/" -Recurse -Overwrite -Verbose
