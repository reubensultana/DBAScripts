USE [master]
GO

SET NOCOUNT ON;

DECLARE @sqlcmd nvarchar(2000);
DECLARE @DatabaseName nvarchar(128);
DECLARE @BackupFile nvarchar(256);
DECLARE @DataFileLocation nvarchar(256);
DECLARE @LogFileLocation nvarchar(256);
DECLARE @FileNumber tinyint;
DECLARE @ReplaceExisting bit;
DECLARE @RestrictAccess bit;
DECLARE @StatsValue tinyint;

SET @sqlcmd = '';
SET @DatabaseName = 'AdventureWorks2014';
SET @BackupFile = 'D:\MSSQL\BACKUP\AdventureWorks2014.BAK';
SET @DataFileLocation = 'D:\MSSQL\DATA\';
SET @LogFileLocation = 'D:\MSSQL\DATA\';
SET @FileNumber = 1; 
SET @ReplaceExisting = 1; 
SET @RestrictAccess = 1; 
SET @StatsValue = 15; 

DECLARE @ProductVersion nvarchar(128);
SET @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));

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

-- SQL Server 2008 and later versions
IF (@ProductVersion > '10')
BEGIN
    -- Shows the thumbprint of the Database Encryption Key
    ALTER TABLE #BackupFileList ADD [TDEThumbprint] varbinary(32) NULL;
END
-- for SQL Server 2012 and later versions
IF (@ProductVersion > '11')
BEGIN
    -- The URL for the Azure snapshot of the database file contained in the FILE_SNAPSHOT backup
    ALTER TABLE #BackupFileList ADD [SnapshotURL] nvarchar(360) NULL;
END


-- retrieve data from backup file
SET @sqlcmd = N'RESTORE FILELISTONLY FROM DISK=''' + @BackupFile + ''' WITH FILE=' + CAST(@FileNumber AS nvarchar(5)) + ';';

INSERT INTO #BackupFileList EXEC sp_executesql @sqlcmd;


-- build restore command
SET @sqlcmd = (
SELECT 'RESTORE DATABASE ' + QUOTENAME(@DatabaseName, '[') + '
FROM DISK=''' + @BackupFile + '''
WITH FILE=' + CAST(@FileNumber AS nvarchar(5)) + ', ' + CASE @ReplaceExisting WHEN 1 THEN 'REPLACE, ' ELSE '' END + CHAR(13) + CHAR(10)
);

SELECT @sqlcmd = @sqlcmd + COALESCE('    MOVE N''' + LogicalName + ''' TO N''' + 
    @DataFileLocation + REVERSE(SUBSTRING(REVERSE(PhysicalName), 1, CHARINDEX(N'\', REVERSE(PhysicalName))-1)) + ''', ' + CHAR(13) + CHAR(10), '')
FROM #BackupFileList
WHERE Type = 'D';

SELECT @sqlcmd = @sqlcmd + COALESCE('    MOVE N''' + LogicalName + ''' TO N''' + 
    @LogFileLocation + REVERSE(SUBSTRING(REVERSE(PhysicalName), 1, CHARINDEX(N'\', REVERSE(PhysicalName))-1)) + ''', ' + CHAR(13) + CHAR(10), '')
FROM #BackupFileList
WHERE Type = 'L';

SET @sqlcmd = @sqlcmd + (
    SELECT '    STATS=' + CAST(@StatsValue AS nvarchar(5)) + CASE @RestrictAccess WHEN 1 THEN ', RESTRICTED_USER' ELSE '' END + ';'
);


PRINT @sqlcmd;

DROP TABLE #BackupFileList;
