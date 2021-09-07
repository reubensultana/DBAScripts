/* Source: https://github.com/reubensultana/DBAScripts/blob/master/System/ExportTable-TopWaits.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,1433"
:SETVAR DatabaseName "master"

:CONNECT $(SQLServerInstance)
USE [$(DatabaseName)]
GO
SET NOCOUNT ON;
WITH cteThreads AS (
    SELECT
        s.[session_id], r.[command], r.[status], r.[wait_type], r.[scheduler_id], w.[worker_address],
        w.[is_preemptive], w.[state], t.[task_state], /*t.[session_id],*/ t.[exec_context_id], t.[request_id]
    FROM sys.dm_exec_sessions AS s
        INNER JOIN sys.dm_exec_requests AS r ON s.[session_id] = r.[session_id]
        INNER JOIN sys.dm_os_tasks t ON r.[task_address] = t.[task_address]
        INNER JOIN sys.dm_os_workers AS w ON t.[worker_address] = w.[worker_address]
    WHERE s.[is_user_process] = 0
)
SELECT [wait_type], COUNT(*) AS [wait_count]
FROM cteThreads
GROUP BY [wait_type]
ORDER BY [wait_count] DESC
GO
