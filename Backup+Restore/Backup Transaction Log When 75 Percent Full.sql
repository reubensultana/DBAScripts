USE [master]
GO

SET NOCOUNT ON;
DECLARE @DatabaseName nvarchar(128);

CREATE TABLE #logspace (
    database_name sysname,
    log_size_mb NUMERIC(15,8),
    log_space_percent NUMERIC(15,8),
    status SMALLINT );
INSERT INTO #logspace EXECUTE('dbcc sqlperf(logspace)');

IF EXISTS(
    SELECT 1 FROM #logspace 
    WHERE (database_name NOT IN ('master', 'model', 'msdb', 'tempdb', 'db_dba')
        AND database_name NOT LIKE 'ReportServer$%')
    AND log_space_percent > 75
    AND DATABASEPROPERTYEX(database_name, 'Recovery') IN ('BULK_LOGGED', 'FULL'))
BEGIN
    PRINT 'Backing up databases having the transaction log > 75% full';
    PRINT '************************************************************';
    DECLARE curDatabases CURSOR READ_ONLY FOR 
        SELECT database_name FROM #logspace 
        WHERE (database_name NOT IN ('master', 'model', 'msdb', 'tempdb', 'db_dba')
            AND database_name NOT LIKE 'ReportServer$%')
        AND log_space_percent > 75
        AND DATABASEPROPERTYEX(database_name, 'Recovery') IN ('BULK_LOGGED', 'FULL')
        ORDER BY log_space_percent DESC, database_name ASC;

    OPEN curDatabases;
    FETCH NEXT FROM curDatabases INTO @DatabaseName;
    WHILE (@@FETCH_STATUS = 0)
    BEGIN
        PRINT 'Backing up the log for database: ' + @DatabaseName;
        PRINT '------------------------------------------------------------';
        EXECUTE [db_dba].[dbo].[usp_maint_tlogbackup] 
            @path = 'E:\MSSQL2K5\MSSQL.1\MSSQL\BACKUP'
            ,@onedbname = @DatabaseName
            ,@excludedbs = '';

	    FETCH NEXT FROM curDatabases INTO @DatabaseName;
    END
    CLOSE curDatabases;
    DEALLOCATE curDatabases;
END;
DROP TABLE #logspace;
