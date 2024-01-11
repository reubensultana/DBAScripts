/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Backup+Restore/CheckExistingBackups.sql */

USE [msdb]
GO
SET NOCOUNT ON;
DECLARE @DatabaseName nvarchar(128) = N'%';
DECLARE @BackupType nvarchar(10) = N'[DIL]';
DECLARE @BackupStartDate datetime = CURRENT_TIMESTAMP -10;
DECLARE @BackupEndDate datetime = CURRENT_TIMESTAMP;
DECLARE @BackupDuration int = -1; -- value in seconds

SELECT DISTINCT
    bs.[server_name]
    --,bs.[backup_set_id]
    ,bs.[database_name]
    ,bs.[type]
    ,bs.[user_name]
    ,bs.[backup_start_date]
    ,bs.[backup_finish_date]
    ,DATEDIFF(s, bs.[backup_start_date], bs.[backup_finish_date]) AS [backup_duration]
    ,CAST((((bs.[backup_size])/1024)/1024) AS numeric(20,1)) AS [backup_size_mb]
    ,CAST((((bs.[compressed_backup_size])/1024)/1024) AS numeric(20,1)) AS [compressed_backup_size_mb]
    ,SUM(bf.[backed_up_page_count]) AS [backed_up_page_count]
FROM dbo.backupset bs
    INNER JOIN dbo.backupfile bf ON bs.[backup_set_id] = bf.[backup_set_id]
WHERE 1=1
AND (NULLIF(@DatabaseName, N'') IS NULL OR bs.[database_name] LIKE @DatabaseName)
AND (NULLIF(@BackupType, N'') IS NULL OR bs.[type] LIKE @BackupType)
AND bs.[backup_start_date] BETWEEN @BackupStartDate AND @BackupEndDate
AND DATEDIFF(s, bs.[backup_start_date], bs.[backup_finish_date]) > @BackupDuration
GROUP BY
    bs.[server_name]
    --,bs.[backup_set_id]
    ,bs.[database_name]
    ,bs.[type]
    ,bs.[user_name]
    ,bs.[backup_start_date]
    ,bs.[backup_finish_date]
    ,bs.[backup_start_date]
    ,bs.[backup_size]
    ,bs.[compressed_backup_size]
ORDER BY bs.[backup_start_date] DESC, bs.[database_name] ASC, bs.[type] ASC;
GO
