/* Source: https://github.com/reubensultana/DBAScripts/blob/master/System/GetInfo-TempDbUsage.sql */

USE [master]
GO
WITH cteTempDbUsage
AS (
    SELECT 
        COALESCE(T1.session_id, T2.session_id) [session_id]
        ,T1.request_id
        ,COALESCE(T1.database_id, T2.database_id) [database_id]
        ,COALESCE(T1.total_alloc_user_objects_mb, 0) + T2.total_alloc_user_objects_mb total_alloc_user_objects_mb
        ,COALESCE(T1.net_alloc_user_objects_mb, 0) + T2.net_alloc_user_objects_mb net_alloc_user_objects_mb
        ,COALESCE(T1.total_alloc_internal_objects_mb, 0) + T2.total_alloc_internal_objects_mb total_alloc_internal_objects_mb
        ,COALESCE(T1.net_alloc_internal_objects_mb, 0) + T2.net_alloc_internal_objects_mb net_alloc_internal_objects_mb
        ,COALESCE(T1.total_allocation_mb, 0) + T2.total_allocation_mb total_allocation_mb
        ,COALESCE(T1.net_allocation_mb, 0) + T2.net_allocation_mb net_allocation_mb
        ,COALESCE(T1.query_text, T2.query_text) query_text
    FROM (
        SELECT 
            TS.session_id
            ,TS.request_id
            ,TS.database_id
            ,CAST(TS.user_objects_alloc_page_count / 128 AS DECIMAL(15, 2)) total_alloc_user_objects_mb
            ,CAST((TS.user_objects_alloc_page_count - TS.user_objects_dealloc_page_count) / 128 AS DECIMAL(15, 2)) net_alloc_user_objects_mb
            ,CAST(TS.internal_objects_alloc_page_count / 128 AS DECIMAL(15, 2)) total_alloc_internal_objects_mb
            ,CAST((TS.internal_objects_alloc_page_count - TS.internal_objects_dealloc_page_count) / 128 AS DECIMAL(15, 2)) net_alloc_internal_objects_mb
            ,CAST((TS.user_objects_alloc_page_count + internal_objects_alloc_page_count) / 128 AS DECIMAL(15, 2)) total_allocation_mb
            ,CAST((TS.user_objects_alloc_page_count + TS.internal_objects_alloc_page_count - TS.internal_objects_dealloc_page_count - TS.user_objects_dealloc_page_count) / 128 AS DECIMAL(15, 2)) net_allocation_mb
            ,T.TEXT query_text
        FROM sys.dm_db_task_space_usage TS
        INNER JOIN sys.dm_exec_requests ER ON ER.request_id = TS.request_id
            AND ER.session_id = TS.session_id
        OUTER APPLY sys.dm_exec_sql_text(ER.sql_handle) T
        WHERE TS.session_id > 50 
    ) T1
    RIGHT JOIN (
        SELECT 
            SS.session_id
            ,SS.database_id
            ,CAST(SS.user_objects_alloc_page_count / 128 AS DECIMAL(15, 2)) total_alloc_user_objects_mb
            ,CAST((SS.user_objects_alloc_page_count - SS.user_objects_dealloc_page_count) / 128 AS DECIMAL(15, 2)) net_alloc_user_objects_mb
            ,CAST(SS.internal_objects_alloc_page_count / 128 AS DECIMAL(15, 2)) total_alloc_internal_objects_mb
            ,CAST((SS.internal_objects_alloc_page_count - SS.internal_objects_dealloc_page_count) / 128 AS DECIMAL(15, 2)) net_alloc_internal_objects_mb
            ,CAST((SS.user_objects_alloc_page_count + internal_objects_alloc_page_count) / 128 AS DECIMAL(15, 2)) total_allocation_mb
            ,CAST((SS.user_objects_alloc_page_count + SS.internal_objects_alloc_page_count - SS.internal_objects_dealloc_page_count - SS.user_objects_dealloc_page_count) / 128 AS DECIMAL(15, 2)) net_allocation_mb
            ,T.TEXT query_text
        FROM sys.dm_db_session_space_usage SS
        LEFT JOIN sys.dm_exec_connections CN ON CN.session_id = SS.session_id
        OUTER APPLY sys.dm_exec_sql_text(CN.most_recent_sql_handle) T
        WHERE SS.session_id > 50 
    ) T2 ON T1.session_id = T2.session_id
)
SELECT 
    c.session_id AS [session_id]
	,es.login_name AS [login_name]
	,DB_NAME(es.database_id) AS [database_name]
	,ec.client_net_address AS [source_ip_address]
    ,c.total_alloc_user_objects_mb
    ,c.net_alloc_user_objects_mb
    ,c.total_alloc_internal_objects_mb
    ,c.net_alloc_internal_objects_mb
    ,c.total_allocation_mb
    ,c.net_allocation_mb
    ,c.query_text 
FROM cteTempDbUsage c
    INNER JOIN sys.dm_exec_sessions es ON c.session_id = es.session_id
    INNER JOIN sys.dm_exec_connections ec ON c.session_id = ec.session_id
WHERE total_alloc_user_objects_mb + net_alloc_user_objects_mb + total_alloc_internal_objects_mb + net_alloc_internal_objects_mb - total_allocation_mb - net_allocation_mb != 0
GO 


/*
Sample query to generate a decent-sized Temp Table:

SELECT a.*
INTO #all_objects
FROM sys.all_objects a
    CROSS APPLY sys.all_objects b;
*/
