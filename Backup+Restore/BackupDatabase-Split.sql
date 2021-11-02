/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Backup+Restore/BackupDatabase-Split.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,14331"
:SETVAR DatabaseName "Adventureworks"
:SETVAR BackupLocation "D:\DatabaseBackups\"
:SETVAR StatsValue "10"
/* IMPORTANT: set "BackupFiles" to a reasonable value - don't get smart with this */
:SETVAR BackupFiles "4"
/* The "VerifyBackup" option will trigger the RESTORE VERIFYONLY command after the backup completes; valid values are 1 and 0 */
:SETVAR VerifyBackup "1"
:SETVAR DebugMode "1"

:CONNECT $(SQLServerInstance)
USE [master]
GO
DECLARE @BackupLocation nvarchar(2000) = N'$(BackupLocation)';
DECLARE @DateSuffix nvarchar(19) = REPLACE(REPLACE(REPLACE(CONVERT(varchar(19), CURRENT_TIMESTAMP, 121), '-', ''), ':', ''), ' ', '_');
DECLARE @ServerName nvarchar(128) = REPLACE(@@SERVERNAME, '\', '$');
DECLARE @DatabaseName nvarchar(128) = '$(DatabaseName)';
DECLARE @BackupFileName nvarchar(1000) = @BackupLocation + @ServerName + '_' + @DatabaseName + '_' + @DateSuffix + '.BAK';
DECLARE @BackupFiles tinyint = $(BackupFiles);
DECLARE @VerifyBackup bit = $(VerifyBackup);
DECLARE @DebugMode bit = $(DebugMode);
DECLARE @SqlCmd nvarchar(max) = N'';
EXEC xp_create_subdir @BackupLocation;
----------
DECLARE @BackupFileNames nvarchar(max) = N'';
IF (@BackupFiles > 40) SET @BackupFiles = 40; -- don't be ridiculous...
DECLARE @Numerals tinyint = LEN(CAST(@BackupFiles AS varchar(5)));

IF (@BackupFiles <= 1) -- just in case it's set to something less than 1
BEGIN
    -- single file backup
    SET @BackupFileNames = @BackupFileNames + CHAR(13) + CHAR(10) + N'    DISK=' + @BackupFileName
END
ELSE
BEGIN
    -- generate multiple file names
    -- table of numbers
    WITH cte_Numbers (number) AS (
        SELECT 1 AS [number]
        UNION ALL
        SELECT [number] + 1
        FROM cte_Numbers WHERE [number] < @BackupFiles )
    SELECT @BackupFileNames = @BackupFileNames + CHAR(13) + CHAR(10) + N'    DISK=''' + REPLACE(@BackupFileName, N'.BAK', (N'_' + RIGHT(REPLICATE(N'0', @Numerals) + CAST([number] AS varchar(10)), @Numerals) + N'.BAK')) + N''','
    FROM cte_Numbers;

    -- remove the trailing comma
    SET @BackupFileNames = SUBSTRING(@BackupFileNames, 1, LEN(@BackupFileNames)-1);
END
----------
IF (@DebugMode = 0) PRINT 'Backing up [' + @DatabaseName + '] to ' + REPLACE(@BackupFileNames, 'DISK=', '') + '';
----------
PRINT N'';
----------
-- start with the backup header
SET @SqlCmd = N'BACKUP DATABASE [' + @DatabaseName + N'] TO '
-- append the backup file names/paths
SET @SqlCmd = @SqlCmd + @BackupFileNames;
-- append the footer
SET @SqlCmd = @SqlCmd + CHAR(13) + CHAR(10) + N'WITH INIT, NOUNLOAD, COPY_ONLY, COMPRESSION, CHECKSUM, 
    BUFFERCOUNT=900, BLOCKSIZE=65536, MAXTRANSFERSIZE=4194304, STATS=$(StatsValue);';
IF (@DebugMode = 1) PRINT @SqlCmd;
ELSE EXEC sp_executesql @SqlCmd;
----------
PRINT N'';
----------
IF (@VerifyBackup = 1)
BEGIN
    -- start with the restore header
    SET @SqlCmd = N'RESTORE VERIFYONLY FROM '
    -- append the backup file names/paths
    SET @SqlCmd = @SqlCmd + @BackupFileNames;
    -- append the footer
    SET @SqlCmd = @SqlCmd + CHAR(13) + CHAR(10) + N'WITH CHECKSUM, STATS=$(StatsValue);'
    IF (@DebugMode = 1) PRINT @SqlCmd;
    ELSE EXEC sp_executesql @SqlCmd;
END
GO
