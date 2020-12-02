SET NOCOUNT ON

DECLARE @objectID int;
DECLARE @SQLServerVersion INT;
DECLARE @NonClusteredIndexFileGroup nvarchar(128);

--SET @objectID = 41207347;
SET @SQLServerVersion = CAST(DATABASEPROPERTYEX('master', 'Version') AS int);
SET @NonClusteredIndexFileGroup = N'INDEXES'; -- if commented the same FILEGROUP as the parent table will be used

SELECT 'USE ' + QUOTENAME(DB_NAME(), '[') + '
GO';

-- CLUSTERED INDEXES
SELECT 
    CASE WHEN ix.[is_primary_key]=1 THEN '
IF EXISTS(SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(''[' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + ']'') AND [index_id] = 1 AND [name] = N''' + ISNULL(ix.[name], '') + ''')
    ALTER TABLE [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + '] DROP CONSTRAINT [' + ISNULL(ix.[name], '') + '];
GO
' 
        ELSE '
IF EXISTS(SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(''[' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + ']'') AND [index_id] = 1 AND [name] = N''' + ISNULL(ix.[name], '') + ''')
    DROP INDEX [' + ISNULL(ix.[name], '') + '] ON [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + ']; 
GO
'
    END

FROM sys.indexes AS ix
    INNER JOIN sys.tables AS st ON ix.[object_id] = st.[object_id]
    INNER JOIN sys.data_spaces d ON d.data_space_id = ix.data_space_id 

WHERE ix.[index_id] = 1 -- clustered indexes only
AND ix.[object_id] = ISNULL(@objectID, ix.[object_id])
AND st.[name] NOT IN ('dtproperties')

GROUP BY 
    st.name
    , ISNULL(ix.[name], '')
    , ix.[object_id]
    , ix.[index_id]
    , ix.[is_primary_key]
    , ix.[is_unique]
    , ix.[type]
    , ix.[type_desc]
    , ix.[is_padded]
    , ix.[ignore_dup_key]
    , ix.[allow_row_locks]
    , ix.[allow_page_locks]
    , d.[name]
    ,ix.[filter_definition]
    
ORDER BY 
    st.[name]
    , ix.[index_id];


-- NONCLUSTERED INDEXES
SELECT 
    CASE WHEN ix.[is_primary_key]=1 THEN '
IF EXISTS(SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(''[' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + ']'') AND [index_id] > 1 AND [name] = N''' + ISNULL(ix.[name], '') + ''')
    ALTER TABLE [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + '] DROP CONSTRAINT [' + ISNULL(ix.[name], '') + '];
GO
'
        ELSE '
IF EXISTS(SELECT 1 FROM sys.indexes WHERE [object_id] = OBJECT_ID(''[' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + ']'') AND [index_id] > 1 AND [name] = N''' + ISNULL(ix.[name], '') + ''')
    DROP INDEX [' + ISNULL(ix.[name], '') + '] ON [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + ']; 
GO
'
    END

FROM sys.indexes AS ix
    INNER JOIN sys.tables AS st ON ix.[object_id] = st.[object_id]
    INNER JOIN sys.data_spaces d ON d.data_space_id = ix.data_space_id 

WHERE ix.[index_id] > 1 -- nonclustered indexes only
AND ix.[object_id] = ISNULL(@objectID, ix.[object_id])
AND st.[name] NOT IN ('dtproperties')

GROUP BY 
    st.name
    , ISNULL(ix.[name], '')
    , ix.[object_id]
    , ix.[index_id]
    , ix.[is_primary_key]
    , ix.[is_unique]
    , ix.[type]
    , ix.[type_desc]
    , ix.[is_padded]
    , ix.[ignore_dup_key]
    , ix.[allow_row_locks]
    , ix.[allow_page_locks]
    , d.[name]
    , ix.[filter_definition]
    
ORDER BY 
    st.[name]
    , ix.[index_id];

