# Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/GetAccessToSQL.ps1

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force;

# check if you are running as Administrator
function isAdministrator {
  $wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal=New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $wid
  $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
  return $principal.IsInRole($adminRole)
}
[bool] $runningAsAdmin = isAdministrator
if ($runningAsAdmin -eq $false) { Throw "You must be running this script as Administrator" }

[string] $LoginName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name # Read-Host -Prompt 'Which login name requires access? '
[string] $ServerInstance = $(Get-WmiObject Win32_Computersystem).Name;

[string] $ScheduledTaskName = "Add me to SQL Server sysadmins role";
[bool] $HasAccess = $false;
[int] $IterationAttempts = 0;

$ScheduledTaskActions = @(); # array to store multiple ScheduledTaskAction
# command to create the login
$ScheduledTaskActions += New-ScheduledTaskAction -Execute "sqlcmd.exe" -Argument "-S ""$ServerInstance"" -E -d ""master"" -Q ""IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE [name] = '$LoginName') CREATE LOGIN [$LoginName] FROM WINDOWS;""";
# command to add the login to the sysadmin role
$ScheduledTaskActions += New-ScheduledTaskAction -Execute "sqlcmd.exe" -Argument "-S ""$ServerInstance"" -E -d ""master"" -Q ""ALTER SERVER ROLE [sysadmin] ADD MEMBER [$LoginName];""";
# ...or for SQL Server 2008 and earlier
# $ScheduledTaskActions += New-ScheduledTaskAction -Execute "sqlcmd.exe" -Argument "-S ""$ServerInstance"" -E -d ""master"" -Q ""EXEC sp_addsrvrolemember [$LoginName], [sysadmin];""";
 
# run the task "as Administrator"
$ScheduledTaskPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest;

$ScheduledTask = New-ScheduledTask -Action $ScheduledTaskActions -Principal $ScheduledTaskPrincipal;
Register-ScheduledTask -TaskName $ScheduledTaskName -InputObject $ScheduledTask | Out-Null;

# run it!
while ($false -eq $HasAccess) {
  Start-ScheduledTask -TaskName $ScheduledTaskName;
  Start-Sleep -Seconds 5 -ErrorAction SilentlyContinue | Out-Null
  $IterationAttempts += 1;
  # check if the currenttly logged on account has access
  try { 
      Invoke-Sqlcmd -ServerInstance $ServerInstance -Database "master" -Query "SELECT 1;" -AbortOnError  | Out-Null
      $HasAccess = $true
      Write-Verbose "Access to SQL Server $ServerInstance has been confirmed";
  }
  catch { $HasAccess = $false }
  # exit after 10 attempts
  if ($IterationAttempts -gt 10 ) {
    Write-Error "Could not confirm access to SQL Server instance $ServerInstance. Kindly verify this before proceeding with the next steps."
    break;
  }
}

# remove it - not needed any more
Unregister-ScheduledTask -TaskName $ScheduledTaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null;
