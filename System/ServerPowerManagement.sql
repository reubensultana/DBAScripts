/* Source: https://github.com/reubensultana/DBAScripts/blob/master/System/ServerPowerManagement.sql */

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

-- Enable and update the currently configured value for this feature
EXEC sp_configure 'show advanced options', 1
RECONFIGURE WITH OVERRIDE
GO
-- Enable and update the currently configured value for this feature
EXEC sp_configure 'xp_cmdshell', 1
RECONFIGURE WITH OVERRIDE
GO

CREATE TABLE #power ( ServerPowerPlan varchar(256) );

INSERT INTO #power
exec xp_cmdshell 'powercfg /list'

SELECT  
	SUBSTRING(ServerPowerPlan, 
		CHARINDEX('(', ServerPowerPlan, 1)+1, 
		CHARINDEX(')', ServerPowerPlan, 1)-(CHARINDEX('(', ServerPowerPlan, 1)+1)
		)
FROM #power AS ServerPowerPlan 
WHERE ServerPowerPlan LIKE '%*';

DROP TABLE #power

-- Disable and update the currently configured value for this feature
EXEC sp_configure 'xp_cmdshell', 0
RECONFIGURE WITH OVERRIDE
GO
-- Disable and update the currently configured value for this feature
EXEC sp_configure 'show advanced options', 0
RECONFIGURE WITH OVERRIDE
GO
