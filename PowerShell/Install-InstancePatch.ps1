# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Install-InstancePatch.ps1

# Update the Build Reference so DBATOOLS is aware of the latest SP/CU versions
# Set the versions to whatever version you're using
Get-DbaBuildReference -MajorVersion 2017 -CumulativeUpdate 29 -Update

# Create a list of servers that you want to patch (or retrieve them from your CMDB)
$ServerList = 'SQL01','SQL02','SQL03'

# Create a credential to pass in to the Update-DbaInstance command; this will prompt for your password
$cred = Get-Credential DOMAIN\your.account

# Set the version that you want to update to
$version = '2017CU29'

# Start Patching! The -Restart option will allow it to restart the SQL Server as needed
Update-DbaInstance -ComputerName $ServerList -Path '\\network\share\path\SQLSERVER\2017\CU29\' -Credential $cred -Version $version -Restart
<#
NOTE
---------
Instances are patched in sequence, that is, *not* in parallel, so it will be time-consuming.
Parallell-ish installations can be acheived using multiple PowerShell terminals.
Alternatively you can write your own code using PowerShell Runspaces.
#>


# CREDIT: https://sqlnuggets.com/patching-multiple-sql-servers-with-powershell-and-dbatools/
