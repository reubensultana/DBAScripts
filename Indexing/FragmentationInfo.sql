-- Source: https://github.com/reubensultana/DBAScripts/blob/master/Indexing/FragmentationInfo.sql

-- variables
declare @dbid int;
declare @MaxFragmentation float;        -- Maximum acceptable fragmentation level
SET @MaxFragmentation = 5.0;

declare @SQLcmd nvarchar(4000);         -- holds dynamic SQL used within loop to retrieve index information

declare @DatabaseNames CURSOR;          -- Databases to be checked
declare @IndexNames CURSOR;             -- Data returned by query from DMV's

declare @DatabaseName sysname,          -- Name of the database containing the affected table or view
        @SchemaName sysname,            -- Name of the schema that the object is contained in
        @ObjectID int,                  -- Object ID of the table or view that the index is on
        @TableName sysname,             -- Object (table) name
        @IndexID int,                   -- Index ID of an index. 0 = Heap; 1 = Clustered index; > 1 = Nonclustered index
        @IndexName sysname,             -- Name of the index. name is unique only within the object. NULL = Heap
        @IndexType nvarchar(60),        -- Description of the index type: HEAP, CLUSTERED, NONCLUSTERED, XML
        @PercentFragmentation float,    -- Logical fragmentation for indexes, or extent fragmentation for heaps in the IN_ROW_DATA allocation unit. 
                                        -- The value is measured as a percentage and takes into account multiple files. For definitions of logical and extent fragmentation, see Remarks. 
                                        -- 0 for LOB_DATA and ROW_OVERFLOW_DATA allocation units.
                                        -- NULL for heaps when mode = SAMPLED.
        @FragmentationCount int,        -- Number of fragments in the leaf level of an IN_ROW_DATA allocation unit. For more information about fragments, see Remarks.
                                        -- NULL for nonleaf levels of an index, and LOB_DATA or ROW_OVERFLOW_DATA allocation units. 
                                        -- NULL for heaps when mode = SAMPLED.
        @PageFragmentation float,       -- Average number of pages in one fragment in the leaf level of an IN_ROW_DATA allocation unit. 
                                        -- NULL for nonleaf levels of an index, and LOB_DATA or ROW_OVERFLOW_DATA allocation units. 
                                        -- NULL for heaps when mode = SAMPLED.
        @AllowPageLocks bit,            -- 1 = Index allows row locks; 0 = Index does not allow row locks.
        @AllowRowLocks bit,             -- 1 = Index allows page locks; 0 = Index does not allow page locks.
        @StatsName sysname;             -- name of the statistics object for an index

SET @dbid = DB_ID(DB_NAME())

CREATE TABLE #FragmentationInfo (
    [DatabaseID]            smallint,
	[DatabaseName]          nvarchar(128),
    [SchemaName]            nvarchar(128),
    [ObjectID]              int,
    [TableName]             nvarchar(128),
    -- index properties
    [IndexID]               int,
    [IndexName]             nvarchar(128),
    [IndexType]             nvarchar(60),
    [PercentFragmentation]  numeric(5,2),
    [PageCount]             bigint,
    [RecordCount]           bigint,
    [AllowPageLocks]        bit NULL,
    [AllowRowLocks]         bit NULL,
	-- statistics properties
    [StatsName]             nvarchar(128) NULL,
    [StatsLastUpdated]      datetime NULL,
    [RowsInTable]           bigint NULL,
    [RowsSampled]           bigint NULL,
    [RowModifications]      bigint NULL,
    [SamplePercent]         numeric(18,2) NULL
);

-- get fragmentation info
-- also see https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql
INSERT INTO #FragmentationInfo
    SELECT 
        d.database_id,          -- DatabaseID
        QUOTENAME(d.name, '['), -- DatabaseName
        '',                     -- SchemaName
        s.object_id,            -- ObjectID
        '',                     -- TableName
        s.index_id,             -- IndexID
        '',                     -- IndexName
        '',                     -- IndexType
        s.avg_fragmentation_in_percent, -- PercentFragmentation
        s.page_count,           -- PageCount
        NULL,                   -- RecordCount
        NULL,                   -- AllowPageLocks
        NULL,                   -- AllowRowLocks
        NULL,                   -- StatsName
        NULL,                   -- StatsLastUpdated
        NULL,                   -- RowsInTable
        NULL,                   -- RowsSampled
        NULL,                   -- RowModifications
        NULL                    -- SamplePercent
    FROM sys.dm_db_index_physical_stats(@dbid, NULL, NULL, NULL, 'LIMITED') s
        INNER JOIN sys.databases d ON s.database_id = d.database_id
    WHERE d.database_id > 4 -- exclude master, tempdb, model, msdb
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsReadOnly'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsOffline'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsSuspect'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsShutDown'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsNotRecovered'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsInStandBy'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsInRecovery'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsInLoad'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsEmergencyMode'), 0) = 0
    AND ISNULL(DATABASEPROPERTY(d.[name], 'IsDetached'), 0) = 0
    AND s.index_id > 0 -- exclude heap (table without a clustered index)
    AND s.page_count > 1000 -- as per Microsoft recommendation
    AND s.avg_fragmentation_in_percent > @MaxFragmentation -- maximum index fragmentation level allowed
    AND s.alloc_unit_type_desc = 'IN_ROW_DATA' -- avoid index maintenance rebuilds - v4.3 fix - 16/01/2012
    ORDER BY s.database_id, s.object_id, s.index_id;

-- retrieve missing object names; sys.dm_db_index_physical_stats returns object ids
    SET @DatabaseNames = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT QUOTENAME([name], '[') FROM sys.databases
        WHERE database_id = @dbid;

OPEN @DatabaseNames
FETCH NEXT FROM @DatabaseNames INTO @DatabaseName
WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @SQLcmd = N'';
    SET @SQLcmd = N'USE ' + @DatabaseName + N'; ';
    -- get index names and exclude disabled clustered index
    -- v4.6 fix - 24/09/2012
    -- If SCHEMA_NAME or OBJECT_NAME functions or Index Name are NULL save an empty string
    SET @SQLcmd = @SQLcmd + N'
UPDATE f
SET [SchemaName]        = ISNULL(QUOTENAME(SCHEMA_NAME(o.schema_id), ''[''), ''''),
    [TableName]         = ISNULL(QUOTENAME(OBJECT_NAME(f.objectid), ''[''), ''''),
    [IndexName]         = ISNULL(QUOTENAME(i.[name], ''[''), ''''),
    [IndexType]         = i.type_desc,
    [RecordCount]       = p.rows,
    [AllowPageLocks]    = i.allow_page_locks,
    [AllowRowLocks]     = i.allow_row_locks,
    [StatsName]         = QUOTENAME(s.[name], ''[''),
    [StatsLastUpdated]  = CAST([sp].[last_updated] AS datetime),
    [RowsInTable]       = [sp].[rows],
    [RowsSampled]       = [sp].[rows_sampled],
    [RowModifications]  = [sp].[modification_counter],
    [SamplePercent]     = CAST(([sp].[rows_sampled] * 100.0) / [sp].[rows] AS numeric(18,2))
FROM #FragmentationInfo f
    INNER JOIN ' + @DatabaseName + N'.sys.objects o ON o.object_id = f.ObjectID
    INNER JOIN ' + @DatabaseName + N'.sys.indexes i ON i.object_id = f.ObjectID AND i.index_id = f.IndexID
	LEFT OUTER JOIN ' + @DatabaseName + N'.sys.stats s ON s.object_id = i.object_id AND s.name = i.name
    LEFT OUTER JOIN ' + @DatabaseName + N'.sys.partitions p ON p.object_id = f.ObjectID AND p.index_id = f.IndexID
    OUTER APPLY [sys].[dm_db_stats_properties]([o].[object_id], [s].[stats_id]) sp
WHERE [f].[DatabaseName] = ''' + @DatabaseName + '''
AND [i].[is_disabled] = 0
AND [i].[type_desc] IN (''CLUSTERED'', ''NONCLUSTERED'')
AND [s].[name] NOT LIKE ''_WA_Sys_%''
;';

    EXEC sp_executesql @SQLcmd;

    FETCH NEXT FROM @DatabaseNames INTO @DatabaseName
END
CLOSE @DatabaseNames
DEALLOCATE @DatabaseNames

SELECT @@SERVERNAME AS [ServerName], *, CURRENT_TIMESTAMP AS [CurrentTimestamp]
FROM #FragmentationInfo 
ORDER BY [SchemaName], [TableName], [IndexID] ASC;

DROP TABLE #FragmentationInfo;
