USE [DBAToolbox]
GO

IF OBJECT_ID(N'dbo.usp_restore_and_replace') IS NULL
    EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_restore_and_replace] AS SELECT CURRENT_TIMESTAMP' 
GO

ALTER PROCEDURE [dbo].[usp_restore_and_replace] (
    @DatabaseName nvarchar(128),        -- database name
    @RestorePath nvarchar(800),         -- folder storing backup files
    @DataFileLocation nvarchar(800),    -- location where the database DATA files will be stored
    @LogFileLocation nvarchar(800),     -- location where the database LOG files will be stored
    @FileNumber tinyint = 1,            -- [OPTIONAL] Backup file number in the media set
    @ReplaceExisting bit = 0,           -- [OPTIONAL] Replace database with the same name - 1: True; 0: False
    @RestrictAccess bit = 0,            -- [OPTIONAL] Restrict access to the database when complete - 1: True; 0: False
    @SetReadOnly bit = 0,               -- [OPTIONAL] Set the database as Read-Only when complete - 1: True; 0: False
    @StatsValue tinyint = 10,           -- [OPTIONAL] Percentage restore completion
    @DebugMode tinyint = 1              -- [OPTIONAL] Debugging messages level - 0: Logging Only (no execute); 1: No Logging; 2: Normal; 3: Advanced
)
AS
/*
----------------------------------------------------------------------------
-- Object Name:             dbo.usp_restore_and_replace
-- Project:                 N/A
-- Business Process:        N/A
-- Purpose:                 Restore the latest backup of a database from the specified location
-- Detailed Description:    Duplicate a database onto another DBMS - requires access to file sharing ports
-- Database:                db_dba - restores database specified in variable @DatabaseName
-- Dependent Objects:       database specified in variable @DatabaseName
-- Called By:               SysAdmin

-- 
--------------------------------------------------------------------------------------
-- Rev   | CMR      | Date Modified  | Developer             | Change Summary
--------------------------------------------------------------------------------------
--   1.0 |          | 11/05/2012     | Reuben Sultana        | First implementation (based on existing code)
--   1.1 |          | 10/07/2015     | Reuben Sultana        | Added support for changes in RESTORE FILELISTONLY output
--       |          |                |                       | 

--
*/
BEGIN
    SET NOCOUNT ON;
    SET ARITHABORT ON;
    SET QUOTED_IDENTIFIER ON;

    DECLARE @LoggingOnly tinyint;
    DECLARE @LogDisabled tinyint;
    DECLARE @LogEnabled  tinyint;
    DECLARE @LogAdvanced tinyint;

    DECLARE @backupfilepath VARCHAR(255); -- full backup file path
    DECLARE @filename VARCHAR(50); -- backup file name

    DECLARE @timestamp VARCHAR(20); -- timestamp used for logging
    DECLARE @datesuffix VARCHAR(20); -- date suffix used for temporary database

    DECLARE @cmd NVARCHAR(4000); -- commands executed by procedures xp_cmdshell and sp_executesql

    DECLARE @DatabaseName_TEMP VARCHAR(80); -- temporary database name

    DECLARE @table VARCHAR(255); -- table name used for reindexing purposes
    DECLARE @fillfactor INT; -- stores index fill factor value
    
    DECLARE @SALoginName NVARCHAR(128); -- login name for the 'sa'
    
    SET @LoggingOnly = 0; -- non-executing mode
    SET @LogDisabled = 1; -- will execute...
    SET @LogEnabled  = 2; -- will execute...
    SET @LogAdvanced = 3; -- will execute...
    
    -- starting restore
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Starting database restore...', -1, -1, @timestamp) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    SET @datesuffix = '_' + CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 112) + REPLACE(CONVERT(VARCHAR(5), CURRENT_TIMESTAMP, 108), ':', '');
    SET @DatabaseName_TEMP = @DatabaseName + @datesuffix;
    SET @fillfactor = 100; -- index fill factor set to 100% since no pages will be added/modified/deleted
    
    SET @SALoginName = (SELECT [name] FROM sys.sql_logins WHERE sid = 0x01);
    
    -- display input parameters
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Target Database Name:      %s', -1, -1, @DatabaseName) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Source Restore Path:       %s', -1, -1, @RestorePath) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Target Data File Location: %s', -1, -1, @DataFileLocation) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Target Log File Location:  %s', -1, -1, @LogFileLocation) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Backup File Number:        %d', -1, -1, @FileNumber) WITH NOWAIT;
    
    SET @cmd = (SELECT CASE @ReplaceExisting WHEN 1 THEN 'Yes' ELSE 'No' END);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Replace Existing Database: %s', -1, -1, @cmd) WITH NOWAIT;
    
    SET @cmd = (SELECT CASE @RestrictAccess WHEN 1 THEN 'Yes' ELSE 'No' END);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Restrict Access:           %s', -1, -1, @cmd) WITH NOWAIT;
    
    SET @cmd = (SELECT CASE @SetReadOnly WHEN 1 THEN 'Yes' ELSE 'No' END);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Target Database Read-Only: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Restore Progress Every:    %d percent', -1, -1, @StatsValue) WITH NOWAIT;
    
    -- display logging level
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    SET @cmd = (
        SELECT CASE @DebugMode
            WHEN @LoggingOnly THEN 'Logging Only'
            WHEN @LogDisabled THEN 'Logging Disabled'
            WHEN @LogEnabled  THEN 'Logging Enabled'
            WHEN @LogAdvanced THEN 'Advanced Logging'
        END
        );
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('Logging Level:             %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    
    -- check if database exists
    IF (@ReplaceExisting = 1) AND NOT EXISTS(SELECT 1 FROM sys.databases WHERE [name] = @DatabaseName)
    BEGIN
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        RAISERROR('%s: Database %s does not exist. ''ReplaceExisting'' option will be ignored.', -1,-1, @timestamp, @DatabaseName)
    END
    
    -- change configuration options (sql server 2005 and later)
    IF EXISTS(SELECT 1 FROM sys.configurations WHERE [name] = 'xp_cmdshell' AND [value_in_use] = 0)
    BEGIN
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Modifying server options...', -1, -1, @timestamp) WITH NOWAIT;
        IF EXISTS(SELECT 1 FROM sys.configurations WHERE [name] = 'show advanced options' AND [value_in_use] = 0)
        BEGIN
            EXEC master.sys.sp_configure 'show advanced options' , 1;
            RECONFIGURE WITH OVERRIDE;
        END
        
        EXEC master.sys.sp_configure 'xp_cmdshell' , 1;
        RECONFIGURE WITH OVERRIDE;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END

    -- map network drive
    IF (@restorepath LIKE '\\%')
    BEGIN
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Connecting to source folder network path...', -1, -1, @timestamp) WITH NOWAIT;
        SET @cmd = 'net use ' + @restorepath;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
        -- catch if the network path is un/available
        BEGIN TRY
            EXEC master.sys.xp_cmdshell @cmd, NO_OUTPUT;
        END TRY
        BEGIN CATCH
            SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
            SET @cmd = 'Error: ' + CONVERT(varchar(50), ERROR_NUMBER()) +
                ', Severity: ' + CONVERT(varchar(5), ERROR_SEVERITY()) +
                ', State: ' + CONVERT(varchar(5), ERROR_STATE()) + CHAR(13) + 
                'Message: ' + ERROR_MESSAGE();
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('%s - %s ', -1, -1, @timestamp, @cmd) WITH NOWAIT;
            RETURN
        END CATCH
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END
    
    -- create temp tables
    CREATE TABLE #filelist (filepath VARCHAR(255) NULL);

    CREATE TABLE #BackupFileList (
        LogicalName nvarchar(128), -- Logical name of the file.
        PhysicalName nvarchar(260), -- Physical or operating-system name of the file.
        Type char(1), -- The type of file, one of: L = Microsoft SQL Server log file; D = SQL Server data file; F = Full Text Catalog 
        FileGroupName nvarchar(128), -- Name of the filegroup that contains the file.
        Size numeric(20,0), -- Current size in bytes.
        MaxSize numeric(20,0), -- Maximum allowed size in bytes.
        FileID bigint, -- File identifier, unique within the database.
        CreateLSN numeric(25,0), -- Log sequence number at which the file was created.
        DropLSN numeric(25,0) NULL, -- The log sequence number at which the file was dropped. If the file has not been dropped, this value is NULL.
        UniqueID uniqueidentifier, -- Globally unique identifier of the file.
        ReadOnlyLSN numeric(25,0) NULL, -- Log sequence number at which the filegroup containing the file changed from read-write to read-only (the most recent change).
        ReadWriteLSN numeric(25,0) NULL, -- Log sequence number at which the filegroup containing the file changed from read-only to read-write (the most recent change).
        BackupSizeInBytes bigint, -- Size of the backup for this file in bytes.
        SourceBlockSize int, -- Block size of the physical device containing the file in bytes (not the backup device).
        FileGroupID int, -- ID of the filegroup.
        LogGroupGUID uniqueidentifier NULL, -- NULL. 
        DifferentialBaseLSN numeric(25,0) NULL, -- For differential backups, changes with log sequence numbers greater than or equal to DifferentialBaseLSN are included in the differential. For other backup types, the value is NULL. 
        DifferentialBaseGUID uniqueidentifier, -- For differential backups, the unique identifier of the differential base. For other backup types, the value is NULL.
        IsReadOnly bit, -- 1 = The file is read-only.
        IsPresent bit -- 1 = The file is present in the backup.
    );
	
	-- >= 2008
    IF (CONVERT(nvarchar(20), SERVERPROPERTY('ProductVersion')) LIKE '1[0-2]%')
        ALTER TABLE #BackupFileList ADD TDEThumbprint varbinary(32); -- Shows the thumbprint of the Database Encryption Key.
    
    -- >- 2014 (Azure ONLY)
    /*
    IF (CONVERT(nvarchar(20), SERVERPROPERTY('ProductVersion')) LIKE '1[2]%') 
        ALTER TABLE #BackupFileList ADD SnapshotURL nvarchar(360); -- The URL for the Azure snapshot of the database file contained in the FILE_SNAPSHOT backup
    */

    -- get list of database files (BAK) present in the source folder
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Retrieving latest backup file name from live server.', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = 'dir /b /od "' + @restorepath + '\' + @DatabaseName + '*.bak"';
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    -- catch if the path is un/available
    BEGIN TRY
        INSERT INTO #filelist EXEC master.sys.xp_cmdshell @cmd;
        
        IF (@@ROWCOUNT = 0)
            RAISERROR('The folder %s does not contain valid SQL Server backup files.', 16, 1, @restorepath);
    END TRY
    BEGIN CATCH
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        SET @cmd = 'Error: ' + CONVERT(varchar(50), ERROR_NUMBER()) +
            ', Severity: ' + CONVERT(varchar(5), ERROR_SEVERITY()) +
            ', State: ' + CONVERT(varchar(5), ERROR_STATE()) + CHAR(13) + 
            'Message: ' + ERROR_MESSAGE();
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('%s - %s ', -1, -1, @timestamp, @cmd) WITH NOWAIT;
        RETURN
    END CATCH
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

    -- get last backup file name
    SELECT TOP 1 @filename = filepath FROM #filelist WHERE filepath IS NOT NULL ORDER BY filepath DESC;

    -- full backup file name
    SET @backupfilepath = @restorepath + '\' + @filename;
    
    -- retrieve data from backup file
    SET @cmd = N'USE [master]; RESTORE FILELISTONLY FROM DISK=''' + @backupfilepath + ''' WITH FILE=' + CAST(@FileNumber AS nvarchar(5)) + ';';
    -- catch if the database file is/not a valid SQL Server backup file
    BEGIN TRY
        INSERT INTO #BackupFileList EXEC sp_executesql @cmd;
    END TRY
    BEGIN CATCH
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        SET @cmd = 'Error: ' + CONVERT(varchar(50), ERROR_NUMBER()) +
            ', Severity: ' + CONVERT(varchar(5), ERROR_SEVERITY()) +
            ', State: ' + CONVERT(varchar(5), ERROR_STATE()) + CHAR(13) + 
            'Message: ' + ERROR_MESSAGE();
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('%s - %s ', -1, -1, @timestamp, @cmd) WITH NOWAIT;
        RETURN
    END CATCH

    -- build restore command
    SET @cmd = (
    SELECT 'USE [master]; RESTORE DATABASE ' + QUOTENAME(@DatabaseName_TEMP, '[') + '
FROM DISK=''' + @backupfilepath + '''
WITH FILE=' + CAST(@FileNumber AS nvarchar(5)) + ', ' + CASE @ReplaceExisting WHEN 1 THEN 'REPLACE, ' ELSE '' END + CHAR(13)
    );
    
    SELECT @cmd = @cmd + COALESCE('    MOVE N''' + LogicalName + ''' TO N''' + 
        @DataFileLocation + REVERSE(SUBSTRING(REVERSE(PhysicalName), 1, CHARINDEX(N'\', REVERSE(PhysicalName))-1)) + ''', ' + CHAR(13), '')
    FROM #BackupFileList
    WHERE Type = 'D';

    SELECT @cmd = @cmd + COALESCE('    MOVE N''' + LogicalName + ''' TO N''' + 
        @LogFileLocation + REVERSE(SUBSTRING(REVERSE(PhysicalName), 1, CHARINDEX(N'\', REVERSE(PhysicalName))-1)) + ''', ' + CHAR(13), '')
    FROM #BackupFileList
    WHERE Type = 'L';

    SET @cmd = @cmd + (
        SELECT '    STATS=' + CAST(@StatsValue AS nvarchar(5)) + CASE @RestrictAccess WHEN 1 THEN ', RESTRICTED_USER' ELSE '' END + ';'
    );
    
    -- append timestamp to file names
    SET @cmd = REPLACE(@cmd, '.mdf', @datesuffix + '.mdf');
    SET @cmd = REPLACE(@cmd, '.ndf', @datesuffix + '.ndf');
    SET @cmd = REPLACE(@cmd, '.ldf', @datesuffix + '.ldf');
    
    /***** START RESTORE *****/
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Starting restore from file: ''%s''', -1, -1, @timestamp, @backupfilepath) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Restore command: ', -1, -1) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('%s ', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    BEGIN TRY
        IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    END TRY
    BEGIN CATCH
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        SET @cmd = 'Error: ' + CONVERT(varchar(50), ERROR_NUMBER()) +
            ', Severity: ' + CONVERT(varchar(5), ERROR_SEVERITY()) +
            ', State: ' + CONVERT(varchar(5), ERROR_STATE()) + CHAR(13) + 
            'Message: ' + ERROR_MESSAGE();
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('%s - %s ', -1, -1, @timestamp, @cmd) WITH NOWAIT;
        RETURN
    END CATCH
    -- filler...
    IF (@DebugMode = @LoggingOnly) 
        BEGIN
            RAISERROR('.', -1, -1, @cmd) WITH NOWAIT;
            RAISERROR('..', -1, -1, @cmd) WITH NOWAIT;
            RAISERROR('...', -1, -1, @cmd) WITH NOWAIT;
            RAISERROR('....', -1, -1, @cmd) WITH NOWAIT;
            RAISERROR('.....', -1, -1, @cmd) WITH NOWAIT;
        END
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    /***** END RESTORE *****/


    -- report and correct pages and row count inaccuracies in the catalog views
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Running DBCC UPDATEUSAGE.', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = 'USE [master]; DBCC UPDATEUSAGE([%1]);';
    SET @cmd = REPLACE(@cmd, '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

    -- Check the logical and physical integrity of all objects
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Running DBCC CHECKDB.', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = 'USE [master]; DBCC CHECKDB([%1]);';
    SET @cmd = REPLACE(@cmd, '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

    -- change recovey model to BULK_LOGGED (see http://technet.microsoft.com/en-us/library/ms191484(SQL.90).aspx)
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Changing recovery model for database %s to %s.', -1, -1, @timestamp, @DatabaseName_TEMP, 'BULK_LOGGED') WITH NOWAIT;
    SET @cmd = 'USE [master]; ALTER DATABASE [%1] SET RECOVERY BULK_LOGGED WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [%1] SET RECOVERY BULK_LOGGED;';
    SET @cmd = REPLACE(@cmd, '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

    -- reindex all tables
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Starting reindexing.', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = 'DECLARE tablecursor CURSOR FOR 
    SELECT QUOTENAME(TABLE_CATALOG, ''['') + ''.'' + QUOTENAME(TABLE_SCHEMA, ''['') + ''.'' + QUOTENAME(TABLE_NAME, ''['') as tablename
    FROM [%1].INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = ''BASE TABLE''';  
    SET @cmd = REPLACE(@cmd, '%1', @DatabaseName_TEMP);

    -- create table cursor
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd; -- do not execute for @LoggingOnly mode
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;

    IF (@DebugMode > @LoggingOnly) -- do not execute for @LoggingOnly mode
    BEGIN
        OPEN tablecursor;  
        FETCH NEXT FROM tablecursor INTO @table;  
        WHILE (@@FETCH_STATUS = 0)  
        BEGIN
            SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
            SET @cmd = 'ALTER INDEX ALL ON ' + @table + ' REBUILD WITH (FILLFACTOR = ' + CONVERT(VARCHAR(3),@fillfactor) + ', SORT_IN_TEMPDB=ON, ALLOW_ROW_LOCKS=ON, ALLOW_PAGE_LOCKS=ON);';
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Reindexing table %s', -1, -1, @timestamp, @table) WITH NOWAIT;
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
            IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;

            FETCH NEXT FROM tablecursor INTO @table;  
        END;  
        CLOSE tablecursor;
        DEALLOCATE tablecursor;
    END
    ELSE
    BEGIN
        RAISERROR('.', -1, -1, @cmd) WITH NOWAIT;
        RAISERROR('..', -1, -1, @cmd) WITH NOWAIT;
        RAISERROR('...', -1, -1, @cmd) WITH NOWAIT;
        RAISERROR('....', -1, -1, @cmd) WITH NOWAIT;
        RAISERROR('.....', -1, -1, @cmd) WITH NOWAIT;
    END


    -- notify...
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Reindexing complete.  All indexes rebuilt with fillfactor %d.', -1, -1, @timestamp, @fillfactor) WITH NOWAIT;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

    -- change recovey model to SIMPLE to avoid transaction log backups
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Changing recovery model for database %s to %s.', -1, -1, @timestamp, @DatabaseName_TEMP, 'SIMPLE') WITH NOWAIT;
    SET @cmd = 'USE [master]; ALTER DATABASE [%1] SET RECOVERY SIMPLE WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [%1] SET RECOVERY SIMPLE;';
    SET @cmd = REPLACE(@cmd, '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    
    -- change database owner on TEMP database
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Modifying database owner', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = REPLACE('USE [master]; EXEC [%1]..sp_changedbowner ''%2'';', '%1', @DatabaseName_TEMP);
    SET @cmd = REPLACE(@cmd, '%2', @SALoginName);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

    -- change IsAutoShrink property on TEMP database
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Changing IsAutoShrink property', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = REPLACE('USE [master]; ALTER DATABASE [%1] SET AUTO_SHRINK OFF;', '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    
    -- change Page Verify property to Checksum on TEMP database
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Changing Page Verify property to Checksum', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = REPLACE('USE [master]; ALTER DATABASE [%1] SET PAGE_VERIFY CHECKSUM;', '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    
    -- restrict access to TEMP database
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Restricting access to TEMPORARY database.', -1, -1, @timestamp) WITH NOWAIT;
    SET @cmd = 'USE [master]; ALTER DATABASE [%1] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [%1] SET RESTRICTED_USER;';
    SET @cmd = REPLACE(@cmd, '%1', @DatabaseName_TEMP);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
    IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    
    
    -- replace TARGET database
    IF (@ReplaceExisting = 1)
    BEGIN
        IF EXISTS(SELECT 1 FROM sys.databases WHERE [name] = @DatabaseName)
        BEGIN
            -- kill all connections
            SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Killing existing connections.', -1, -1, @timestamp) WITH NOWAIT;
            
            DECLARE @SysProcId SMALLINT;
            DECLARE SysProc CURSOR LOCAL FORWARD_ONLY DYNAMIC READ_ONLY FOR
                SELECT DISTINCT [SPID] FROM master.dbo.sysprocesses
                WHERE [dbid] = DB_ID(@DatabaseName);

            OPEN SysProc    -- kill all the processes running against the database
            FETCH NEXT FROM SysProc INTO @SysProcId
            WHILE (@@FETCH_STATUS = 0)
            BEGIN
                SET @cmd = 'KILL ' + CAST(@SysProcId AS NVARCHAR(10));
                IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing command: %s', -1, -1, @cmd) WITH NOWAIT;
                IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
                FETCH NEXT FROM SysProc INTO @SysProcId
            END
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

            -- restrict access to TARGET database
            SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Restricting access to TARGET database.', -1, -1, @timestamp) WITH NOWAIT;
            SET @cmd = 'USE [master]; ALTER DATABASE [%1] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [%1] SET RESTRICTED_USER;';
            SET @cmd = REPLACE(@cmd, '%1', @DatabaseName);
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
            IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;

            -- drop TARGET database
            SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Deleting TARGET database.', -1, -1, @timestamp) WITH NOWAIT;
            SET @cmd = REPLACE('USE [master]; DROP DATABASE [%1];', '%1', @DatabaseName);
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
            IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
            IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
        END
        
        -- rename TEMPORARY database as TARGET
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Renaming TEMPORARY database as TARGET.', -1, -1, @timestamp) WITH NOWAIT;
        SET @cmd = REPLACE('USE [master]; ALTER DATABASE [%1] MODIFY NAME = [%2];', '%1', @DatabaseName_TEMP);
        SET @cmd = REPLACE(@cmd, '%2', @DatabaseName);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
        IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END
    
    IF (@RestrictAccess = 0)
    BEGIN
        -- allow access to NEW database
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Allowing access to NEW database.', -1, -1, @timestamp) WITH NOWAIT;
        SET @cmd = 'USE [master]; ALTER DATABASE [%1] SET MULTI_USER;';
        SET @cmd = REPLACE(@cmd, '%1', @DatabaseName);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
        IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END
    
    IF (@SetReadOnly = 1)
    BEGIN
        -- set NEW database as Read-Only
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Setting NEW database as Read-Only.', -1, -1, @timestamp) WITH NOWAIT;
        SET @cmd = 'USE [master]; ALTER DATABASE [%1] SET READ_ONLY;';
        SET @cmd = REPLACE(@cmd, '%1', @DatabaseName);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
        IF (@DebugMode > @LoggingOnly) EXEC sp_executesql @cmd;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END
    
    -- cleanup...
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Starting cleanup', -1, -1, @timestamp) WITH NOWAIT;

    -- remove temp tables
    DROP TABLE #filelist;
    DROP TABLE #BackupFileList;
    
     -- remove network share
    IF (@restorepath LIKE '\\%') -- remove network share
    BEGIN
        SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Deleting connection to source folder network path.', -1, -1, @timestamp) WITH NOWAIT;
        SET @cmd = 'net use /d ' + @restorepath;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogEnabled) RAISERROR('Executing: %s', -1, -1, @cmd) WITH NOWAIT;
        IF (@DebugMode > @LoggingOnly) EXEC master.sys.xp_cmdshell @cmd, NO_OUTPUT;
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END

    -- change configuration options (sql server 2005 and later)
    IF EXISTS(SELECT 1 FROM sys.configurations WHERE [name] = 'xp_cmdshell' AND [value_in_use] = 1)
    BEGIN
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Modifying server options...', -1, -1, @timestamp) WITH NOWAIT;
        IF EXISTS(SELECT 1 FROM sys.configurations WHERE [name] = 'show advanced options' AND [value_in_use] = 0)
        BEGIN
            EXEC master.sys.sp_configure 'show advanced options' , 1;
            RECONFIGURE WITH OVERRIDE;
        END

        EXEC master.sys.sp_configure 'xp_cmdshell' , 0;
        RECONFIGURE WITH OVERRIDE;
        
        IF EXISTS(SELECT 1 FROM sys.configurations WHERE [name] = 'show advanced options' AND [value_in_use] = 1)
        BEGIN
            EXEC master.sys.sp_configure 'show advanced options' , 0;
            RECONFIGURE WITH OVERRIDE;
        END
        IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('----------', -1, -1) WITH NOWAIT;
    END

    -- restore complete
    SET @timestamp = CONVERT(VARCHAR(19), CURRENT_TIMESTAMP, 121);
    IF (@DebugMode = @LoggingOnly) OR (@DebugMode > @LogDisabled) RAISERROR('%s: Database restore complete.', -1, -1, @timestamp) WITH NOWAIT;
END
GO

/*
EXEC db_dba.dbo.usp_restore_and_replace 
    @DatabaseName = 'AdventureWorks',
    @RestorePath = 'D:\TEMP',
    @DataFileLocation = 'D:\MSSQL\MSSQL.1\MSSQL\DATA\',
    @LogFileLocation = 'E:\MSSQL\MSSQL.1\MSSQL\DATA\',
    @FileNumber = 1,
    @ReplaceExisting = 1,
    @RestrictAccess = 0,
    @StatsValue = 5,
    @DebugMode = 0;
*/
