USE [master]
GO

SET NOCOUNT ON;
DECLARE @DatabaseName nvarchar(128);
DECLARE @SQLcmd nvarchar(4000);

CREATE TABLE #SQLCommands (sqlcmd nvarchar(4000));

-- loop databases
DECLARE curDatabases CURSOR FOR
    SELECT [name] FROM sys.databases
    WHERE [name] NOT IN (
        'master', 'model', 'msdb', 'tempdb')
    AND [name] NOT LIKE 'AdventureWorks%'
    AND [name] NOT LIKE 'ReportServer%'
    ORDER BY [name] ASC;
OPEN curDatabases;
FETCH NEXT FROM curDatabases INTO @DatabaseName;
WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @SQLcmd = 'SELECT ''EXEC ' + QUOTENAME(@DatabaseName, '[') + '.sys.sp_refreshview '''''' + QUOTENAME(TABLE_SCHEMA, ''['') + ''.'' + QUOTENAME(TABLE_NAME, ''['') + '''''';''
FROM ' + QUOTENAME(@DatabaseName, '[') + '.INFORMATION_SCHEMA.VIEWS;'

    INSERT INTO #SQLCommands (sqlcmd)
    EXEC sp_executesql @SQLcmd;
    
    FETCH NEXT FROM curDatabases INTO @DatabaseName;
END
CLOSE curDatabases;
DEALLOCATE curDatabases;

-- loop commands temp table
DECLARE curSQLCMD CURSOR FOR 
    SELECT [sqlcmd] FROM #SQLCommands;
OPEN curSQLCMD;
FETCH NEXT FROM curSQLCMD INTO @SQLcmd;
WHILE (@@FETCH_STATUS = 0)
BEGIN
    --PRINT @SQLcmd;
    BEGIN TRY;
        EXEC sp_executesql @SQLcmd;
    END TRY
    BEGIN CATCH
        PRINT 'Error running "' + @SQLcmd + '"';
        PRINT ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM curSQLCMD INTO @SQLcmd;
END
CLOSE curSQLCMD;
DEALLOCATE curSQLCMD;


-- clean up
DROP TABLE #SQLCommands;
