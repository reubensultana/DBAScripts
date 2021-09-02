/* Source: https://github.com/reubensultana/DBAScripts/blob/master/System/InstanceDefaultLocations.sql */

/* Get the Instance default Data, Log and Backup locations */
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

DECLARE @DefaultData nvarchar(512);
DECLARE @DefaultLog nvarchar(512);
DECLARE @DefaultBackup nvarchar(512);
DECLARE @MasterData nvarchar(512);
DECLARE @MasterLog nvarchar(512);

EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DefaultData OUTPUT;

EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @DefaultLog OUTPUT;

EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @DefaultBackup OUTPUT;

EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\Parameters', N'SqlArg0', @MasterData OUTPUT;
SET @MasterData = SUBSTRING(@MasterData, 3, 255);
SET @MasterData = SUBSTRING(@MasterData, 1, LEN(@MasterData) - CHARINDEX('\', REVERSE(@MasterData)));

EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\Parameters', N'SqlArg1', @MasterLog OUTPUT;
SET @MasterLog = SUBSTRING(@MasterLog, 3, 255);
SET @MasterLog = SUBSTRING(@MasterLog, 1, LEN(@MasterLog) - CHARINDEX('\', REVERSE(@MasterLog)));

SELECT 
    @DefaultData AS [DefaultData], 
    @DefaultLog AS [DefaultLog], 
    @DefaultBackup AS [DefaultBackup], 
    @MasterData AS [MasterData], 
    @MasterLog AS [MasterLog];
GO
