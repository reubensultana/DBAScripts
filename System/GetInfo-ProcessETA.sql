/* Source: https://github.com/reubensultana/DBAScripts/blob/master/System/Get-Info-PowerManagement.sql */

USE [master]
GO
SET NOCOUNT ON;
SELECT 
    er.[session_id] AS [SPID], 
    DB_NAME(er.[database_id]) AS [Database Name],
    er.[command] AS [Command],
    CONVERT(numeric(6,2), er.[percent_complete]) AS [Percent Complete],
    CONVERT(varechar(20), DATEADD(ms, er.[estimated_completion_time], CURRENT_TIMESTAMP), 20) AS [Estimated Completion Time],
    CONVERT(numeric(10,2), er.[total_elapsed_time]/1000.0/60.0) AS [Elapsed Min],
    CONVERT(numeric(10,2), er.[total_elapsed_time]/1000.0/60.0/60.0) AS [Elapsed Hours],
    CONVERT(numeric(10,2), er.[estimated_completion_time]/1000.0/60.0) AS [ETA Min],
    CONVERT(numeric(10,2), er.[estimated_completion_time]/1000.0/60.0/60.0) AS [ETA Hours],
    CONVERT(varchar(1000), (
        SELECT SUBSTRING(est.[text], er.[statement_start_offset]/2, 
            CASE WHEN er.[statemend_end_offset] = -1 THEN 1000 ELSE (er.[statement_emd_offset] - er.[statement_start_offset])/2 END)
            FROM sys.dm_exec_sql_text(er.[sql_handle]) est
        )) AS [SQL Text]
FROM sys.dm_exec_requests er
WHERE er.[session_id] > 50 AND er.[session_id] <> @@SPID
AND [command] IN (
    'BACKUP DATABASE', 'BACKUP LOG',
    'RESTORE DATABASE', 'RESTORE LOG',
    'RESTORE HEADERONLY', 'RESTORE FILELISTONLY', 'RESTORE LABELONLY',
    'DbccFilesCompact', 'DbccLOBCompact', 'DbccSpaceReclaim',
    'RECOVERY', 'ROLLBACK', 'KILLED/ROLLBACK', 
    'ALTER INDEX',
    'DBCC', 'DBCC TABLE CHECK',
    'DBCC CHECKDB', 'DBCC CHECKFILEGROUP', 'DBCC CHECKTABLE', 'DBCC INDEXDEFRAG', 
    'DBCC SHRINKDATABASE', 'DBCC SHRINKFILE', 
    'TDE ENCRYPTION'
)
OR er.[status] IN (
    'rollback'
)
GO
/* More Info: https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql */
