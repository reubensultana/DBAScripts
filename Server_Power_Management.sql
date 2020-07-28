use db_dba

--To allow advanced options to be changed.
EXEC sp_configure 'show advanced options', 1
GO
-- To update the currently configured value for advanced options.
RECONFIGURE WITH OVERRIDE
GO
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1
GO
-- To update the currently configured value for this feature.
RECONFIGURE WITH OVERRIDE
GO

CREATE TABLE #power
(
	ServerPowerPlan varchar(256)
);

INSERT INTO #power
exec xp_cmdshell 'powercfg /list'

Select 
	SUBSTRING(ServerPowerPlan, 
		CHARINDEX('(', ServerPowerPlan, 1)+1, 
		CHARINDEX(')', ServerPowerPlan, 1)-(CHARINDEX('(', ServerPowerPlan, 1)+1)
		)
from #power as ServerPowerPlan WHERE ServerPowerPlan LIKE '%*';

DROP TABLE #power

-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 0
GO
-- To update the currently configured value for this feature.
RECONFIGURE WITH OVERRIDE
GO
--To allow advanced options to be changed.
EXEC sp_configure 'show advanced options', 0
GO
-- To update the currently configured value for advanced options.
RECONFIGURE WITH OVERRIDE
GO
