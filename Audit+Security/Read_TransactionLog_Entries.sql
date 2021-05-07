/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Backup+Restore/Read_TransactionLog_Entries.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,1433"
:SETVAR DatabaseName "Adventureworks"

:CONNECT $(SQLServerInstance)
/* read the Transaction Log for the current database */
SET NOCOUNT ON;
DECLARE @Operation nvarchar(50) = N'UPDATE'; /* Options: INSERT, UPDATE, DELETE, or wildcard */
DECLARE @StartTime datetime; /* filters will not be appled if this value is NULL */
DECLARE @EndTime datetime; /* filters will not be appled if this value is NULL */
DECLARE @ObjectName nvarchar(128);
---------
SELECT 
    l.[Transaction ID], l.[Current LSN], l.[Transaction Name], l.[Operation], l.[Context],
    l.[AllocUnitName], l.[Begin Time], l.[End Time], SUSER_SNAME(l.[Transaction SID]) AS [Login Name]
FROM fn_db_log(NULL, NULL) l
WHERE 1=1
/* get records with the same [Transactio ID] value */
AND l.[Transactio ID] IN (
    SELECT [Transactio ID] FROM fn_dblog(NULL, NULL) WHERE 1=1
    /* filter for specific operations */
    AND [Transaction Name] LIKE @Operation
    /* filter on time range will not be applied is values are NULL */
    AND (([Begin Time] >= @StartTime) OR (@StartTime IS NULL))
    UNION ALL
    SELECT [Transactio ID] FROM fn_dblog(NULL, NULL) WHERE 1=1
    /* filter for specific operations */
    AND [Transaction Name] LIKE @Operation
    /* filter on time range will not be applied is values are NULL */
    AND (([End Time] >= @EndTime) OR (@EndTime IS NULL))
)
/* unneccessary overhead */
ORDER BY l.[Current LSN] ASC;
