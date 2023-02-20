/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Databases/GetCurrent-IdentityValue.sql */

/* Get the latest IDENTITY value for all tables in the current database */
WITH cteColumns AS (
    SELECT OBJECT_SCHEMA_NAME(c.object_id) AS [SchemaName], OBJECT_NAME(c.object_id) AS [TableName]
    FROM sys.all_columns c
        INNER JOIN sys.types t ON c.system_type_id = t.system_type_id
    WHERE c.is_identity = 1
    AND t.name IN ('int', 'bigint', 'smallint', 'tinyint') /* that should cover it, however add more datatype names here */
)
SELECT [SchemaName], [TableName], IDENT_CURRENT([SchemaName] + '.' + [TableName]) AS [IdentityValue]
FROM cteColumns
ORDER BY [IdentutyValue] DESC
