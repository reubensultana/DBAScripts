/* Source: https://github.com/reubensultana/DBAScripts/blob/master/ERRORLOG/Configure_ErrorLog.sql */

USE [master]
GO
SET NOCOUNT ON;

-- check if the OS is Windows or Linux
DECLARE @HostPlatform nvarchar(256); -- Windows or Linux
SET @HostPlatform = (SELECT TOP(1) host_platform FROM sys.dm_os_host_info);

IF (@HostPlatform != 'Windows')
BEGIN
    RAISERROR('This script is not yet supported on non-Windows platforms', 16, 1);
    RETURN
END

-- Increase the number of ErrorLog files to 99 
EXEC xp_instance_regwrite 
    N'HKEY_LOCAL_MACHINE', 
    N'Software\Microsoft\MSSQLServer\MSSQLServer', 
    N'NumErrorLogs', 
    REG_DWORD, 99;

-- Set a limit for the size of the ErrorLog file (30MB).
EXEC xp_instance_regwrite 
    N'HKEY_LOCAL_MACHINE',
    N'Software\Microsoft\MSSQLServer\MSSQLServer', 
    N'ErrorLogSizeInKb', 
    REG_DWORD, 30720;

GO
