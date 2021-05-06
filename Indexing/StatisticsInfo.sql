/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Indexing/StatisticsInfo.sql */

SET NOCOUNT ON;
SELECT
    [ServerName]        = @@SERVERNAME,
    [DatabaseName]      = DB_NAME(),
    [SchemaName]        = [sch].[name],
    [TableName]         = [so].[name],
    [StatsName]         = [ss].[name],
    [StatsLastUpdated]  = CAST([sp].[last_updated] AS datetime),
    [RowsInTable]       = [sp].[rows],
    [RowsSampled]       = [sp].[rows_sampled],
    [RowModifications]  = [sp].[modification_counter],
    [SamplePercent]     = CAST(([sp].[rows_sampled] * 100.0) / [sp].[rows] AS numeric(18,2)),
    [CurrentTimestamp]  = CURRENT_TIMESTAMP
FROM [sys].[stats] [ss]
    INNER JOIN [sys].[objects] [so] ON [ss].[object_id] = [so].[object_id]
    INNER JOIN [sys].[schemas] [sch] ON [so].[schema_id] = [sch].[schema_id]
    OUTER APPLY [sys].[dm_db_stats_properties] ([so].[object_id], [ss].[stats_id])
WHERE 1=1
AND [sch].[name] !=  N'sys'
AND [so].[type] = 'U'
AND [sp].[modification_counter] > 0
AND [ss].[name] NOT LIKE N'_WA_Sys_%'
AND CAST(([sp].[rows_sampled] * 100.0) / [sp].[rows] AS numeric(18,2)) < 100
ORDER BY [sp].[rows] DESC, [sp].[last_updated] DESC, [TableName] ASC;
