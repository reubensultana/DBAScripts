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
ALTER TABLE [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + '] ADD 
CONSTRAINT [' + ISNULL(ix.[name], '') + '] PRIMARY KEY ' + ix.[type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS + ' ' 

        ELSE '        
CREATE ' + 
            CASE WHEN (ix.[is_unique]=1 AND ix.[type]>1) THEN 'UNIQUE ' + ix.[type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS -- [UNIQUE] CLUSTERED
                ELSE ix.[type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS -- NONCLUSTERED
            END + ' INDEX [' + ISNULL(ix.[name], '') + '] ON [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + '] '
    END +

        -- indexed_columns
        '(' + ISNULL(REPLACE( REPLACE( REPLACE(
        (   
            SELECT QUOTENAME(c.[name], '[') + (CASE WHEN sic.[is_descending_key]=0 THEN ' ASC' ELSE ' DESC' END) AS 'columnName'
            FROM sys.index_columns AS sic
                INNER JOIN sys.columns AS c ON c.[column_id] = sic.[column_id] AND c.[object_id] = sic.[object_id]
            WHERE sic.[object_id] = ix.[object_id]
            AND sic.[index_id] = ix.[index_id]
            AND sic.[is_included_column] = 0
            ORDER BY sic.[index_column_id]
            FOR XML RAW)
            , '"/><row columnName="', ', ') -- REPLACE 3
            , '<row columnName="', '') -- REPLACE 2
            , '"/>', ''), '') + -- REPLACE 1 & ISNULL
        ') ' +
        
        -- included columns
        ISNULL('INCLUDE (' + REPLACE( REPLACE( REPLACE(
        (   
            SELECT QUOTENAME(c.[name], '[') AS 'columnName'
            FROM sys.index_columns AS sic
                INNER JOIN sys.columns AS c ON c.[column_id] = sic.[column_id] AND c.[object_id] = sic.[object_id]
            WHERE sic.[object_id] = ix.[object_id]
            AND sic.[index_id] = ix.[index_id]
            AND sic.[is_included_column] = 1
            ORDER BY sic.[index_column_id]
            FOR XML RAW)
            , '"/><row columnName="', ', ') -- REPLACE 3
            , '<row columnName="', '') -- REPLACE 2
            , '"/>', '') + ') ' -- REPLACE 1 
        , '') + -- ISNULL
        
        -- filtered columns
        CASE @SQLServerVersion
            WHEN 611 THEN '' -- 2005
            ELSE ISNULL('WHERE ' + ix.[filter_definition], '') -- 2008 and later
        END +
		
'
WITH (
    PAD_INDEX = ' + CASE WHEN ix.[is_padded] = 0 THEN 'OFF' ELSE 'ON' END + ', STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = ' + CASE WHEN ix.[ignore_dup_key] = 0 THEN 'OFF' ELSE 'ON' END + ', 
    ONLINE = OFF, ALLOW_ROW_LOCKS = ' + CASE WHEN ix.[allow_row_locks] = 0 THEN 'OFF' ELSE 'ON' END + ', ALLOW_PAGE_LOCKS = ' + CASE WHEN ix.[allow_page_locks] = 0 THEN 'OFF' ELSE 'ON' END + ', FILLFACTOR = 90
    ) ON ' + QUOTENAME(d.[name], '[') + ';
GO
'

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
ALTER TABLE [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + '] ADD 
CONSTRAINT [' + ISNULL(ix.[name], '') + '] PRIMARY KEY ' + ix.[type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS + ' ' 

        ELSE '
CREATE ' + 
            CASE WHEN (ix.[is_unique]=1 AND ix.[type]>1) THEN 'UNIQUE ' + ix.[type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS -- [UNIQUE] CLUSTERED
                ELSE ix.[type_desc] COLLATE SQL_Latin1_General_CP1_CI_AS -- NONCLUSTERED
            END + ' INDEX [' + ISNULL(ix.[name], '') + '] ON [' + OBJECT_SCHEMA_NAME(ix.[object_id]) + '].[' + OBJECT_NAME(ix.[object_id]) + '] '
    END +

        -- indexed_columns
        '(' + ISNULL(REPLACE( REPLACE( REPLACE(
        (   
            SELECT QUOTENAME(c.[name], '[') + (CASE WHEN sic.[is_descending_key]=0 THEN ' ASC' ELSE ' DESC' END) AS 'columnName'
            FROM sys.index_columns AS sic
                INNER JOIN sys.columns AS c ON c.[column_id] = sic.[column_id] AND c.[object_id] = sic.[object_id]
            WHERE sic.[object_id] = ix.[object_id]
            AND sic.[index_id] = ix.[index_id]
            AND sic.[is_included_column] = 0
            ORDER BY sic.[index_column_id]
            FOR XML RAW)
            , '"/><row columnName="', ', ') -- REPLACE 3
            , '<row columnName="', '') -- REPLACE 2
            , '"/>', ''), '') + -- REPLACE 1 & ISNULL
        ') ' +
        
        -- included columns
        ISNULL('INCLUDE (' + REPLACE( REPLACE( REPLACE(
        (   
            SELECT QUOTENAME(c.[name], '[') AS 'columnName'
            FROM sys.index_columns AS sic
                INNER JOIN sys.columns AS c ON c.[column_id] = sic.[column_id] AND c.[object_id] = sic.[object_id]
            WHERE sic.[object_id] = ix.[object_id]
            AND sic.[index_id] = ix.[index_id]
            AND sic.[is_included_column] = 1
            ORDER BY sic.[index_column_id]
            FOR XML RAW)
            , '"/><row columnName="', ', ') -- REPLACE 3
            , '<row columnName="', '') -- REPLACE 2
            , '"/>', '') + ') ' -- REPLACE 1 
        , '') + -- ISNULL

        -- filtered columns
        CASE @SQLServerVersion
            WHEN 611 THEN '' -- 2005
            ELSE ISNULL('WHERE ' + ix.[filter_definition], '') -- 2008 and later
        END +

'
WITH (
    PAD_INDEX = ' + CASE WHEN ix.[is_padded] = 0 THEN 'OFF' ELSE 'ON' END + ', STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = ' + CASE WHEN ix.[ignore_dup_key] = 0 THEN 'OFF' ELSE 'ON' END + ', 
    ONLINE = OFF, ALLOW_ROW_LOCKS = ' + CASE WHEN ix.[allow_row_locks] = 0 THEN 'OFF' ELSE 'ON' END + ', ALLOW_PAGE_LOCKS = ' + CASE WHEN ix.[allow_page_locks] = 0 THEN 'OFF' ELSE 'ON' END + ', FILLFACTOR = 90
    ) ON ' + QUOTENAME(ISNULL(@NonClusteredIndexFileGroup, d.[name]), '[') + ';
GO
'

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

