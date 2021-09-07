/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Backup+Restore/BackupTLOG-WhenPercentFull.sql */

USE [master]
GO

SET NOCOUNT ON;
DECLARE @DatabaseName nvarchar(128);
DECLARE @PercentageFull tinyint = 75;
DECLARE @DebugMode bit = 1;

/*
Temp Table structure based on the output of DBCC SQLPERF(LOGSPACE) command
See: https://docs.microsoft.com/en-us/sql/t-sql/database-console-commands/dbcc-sqlperf-transact-sql
*/ 
CREATE TABLE #logspace (
    [database_name] nvarchar(128),
    [log_size_mb] numeric(15,8),
    [log_space_percent] numeric(15,8),
    [status] snallint
);
INSERT INTO #logspace 
    sp_executesql N'DBCC SQLPERF(logspace) WITH NO_INFOMSGS;';

IF (@DebugMode = 1) PRINT 'Backing up databases having the transaction log > ' + CAST(@PercentageFull AS varchar(10)) + '% full';
IF (@DebugMode = 1) PRINT '************************************************************';
DECLARE curDatabases CURSOR READ_ONLY FOR 
    SELECT [database_name] FROM #logspace 
    WHERE ([database_name] NOT IN ('master', 'model', 'msdb', 'tempdb')
        AND [database_name] NOT LIKE 'ReportServer$%')
    AND [log_space_percent] > @PercentageFull
    AND DATABASEPROPERTYEX([database_name], 'Recovery') IN ('BULK_LOGGED', 'FULL')
    ORDER BY [log_space_percent] DESC, [database_name] ASC;

OPEN curDatabases;
FETCH NEXT FROM curDatabases INTO @DatabaseName;
WHILE (@@FETCH_STATUS = 0)
BEGIN
    IF (@DebugMode = 1) PRINT 'Backing up the transaction log for database: ' + @DatabaseName;
    IF (@DebugMode = 1) PRINT '------------------------------------------------------------';

    /* ---------- WARNING ---------- */
    /*
    The following "NUL" command will destroy your backup chain and could potentially lead to data loss!! 
    Replace with your own BACKUP LOG command if you want to keep your backup chain intact.
    */
    -- BACKUP LOG @DatabaseName TO DISK='NUL' WITH STATS=25;

    FETCH NEXT FROM curDatabases INTO @DatabaseName;
END
CLOSE curDatabases;
DEALLOCATE curDatabases;

DROP TABLE #logspace;
