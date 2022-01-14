/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Backup+Restore/BackupDatabase-Simple.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,14331"
:SETVAR DatabaseName "Adventureworks"
:SETVAR BackupLocation "D:\DatabaseBackups\"
:SETVAR StatsValue "10"

:CONNECT $(SQLServerInstance)
USE [master]
GO
DECLARE @BackupLocation nvarchar(2000) = N'$(BackupLocation)';
DECLARE @DateSuffix nvarchar(19) = REPLACE(REPLACE(REPLACE(CONVERT(varchar(19), CURRENT_TIMESTAMP, 121, '-', ''), ':', ''), ' ', '_');
DECLARE @ServerName nvarchar(128) = REPLACE(@@SERVERNAME, '\', '$');
DECLARE @DatabaseName nvarchar(128) = '$(DatabaseName)';
DECLARE @BackupFileName nvarchar(1000) = (CASE WHEN @BackupLocation = 'NUL' THEN @BackupLocation ELSE (@BackupLocation + @ServerName + '_' + @DatabaseName + '_' + @DateSuffix + '.BAK') END);
IF (@BackupLocation != 'NUL')
    EXEC xp_create_subdir @BackupLocation;
----------
PRINT 'Backing up [' + @DatabaseName + '] to "' + @BackupFileName + '"';
----------
BACKUP DATABASE @DatabaseName TO DISK=@BackupFileName
WITH INIT, NOUNLOAD, COPY_ONLY, COMPRESSION, CHECKSUM, 
    BUFFERCOUNT=900, BLOCKSIZE=65536, MAXTRANSFERSIZE=4194304, STATS=$(StatsValue);
----------
IF (@BackupLocation != 'NUL')
    RESTORE VERIFYONLY FROM DISK=@BackupFileName WITH CHECKSUM, STATS=$(StatsValue);
GO
