/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Databases/GetInfo-DatabaseConfigAsXML.sql */

/* Get information about database propertied and database objects, principals, permisions, etc. */

SET NOCOUNT ON;

SELECT 
    DB_NAME() AS [database_name],
    -- databases
    CONVERT(xml, (
        SELECT * FROM sys.databases
        WHERE database_id = DB_ID()
        FOR XML PATH, ROOT('databases'), ELEMENTS XSINIL
    ), 2),
    -- database_files
    CONVERT(xml, (
        SELECT * FROM sys.database_files
        FOR XML PATH, ROOT('database_files'), ELEMENTS XSINIL
    ), 2),
    -- filegroups
    CONVERT(xml, (
        SELECT * FROM sys.data_spaces
        FOR XML PATH, ROOT('filegroups'), ELEMENTS XSINIL
    ), 2),
    -- database_principals
    CONVERT(xml, (
        SELECT * FROM sys.database_principals
        WHERE (principal_id > 4) AND (principal_id NOT BETWEEN 16384 AND 16393)
        FOR XML PATH, ROOT('database_principals'), ELEMENTS XSINIL
    ), 2),
    -- schemas
    CONVERT(xml, (
        SELECT * FROM sys.schemas
        WHERE (principal_id > 4) AND (principal_id NOT BETWEEN 16384 AND 16393)
        FOR XML PATH, ROOT('schemas'), ELEMENTS XSINIL
    ), 2),
    -- database_permissions
    CONVERT(xml, (
        SELECT * FROM sys.database_permissions
        WHERE (grantee_principal_id > 4) AND (grantee_principal_id NOT BETWEEN 16384 AND 16393)
        FOR XML PATH, ROOT('database_permissions'), ELEMENTS XSINIL
    ), 2),
    -- tables
    CONVERT(xml, (
        SELECT * FROM sys.tables
        WHERE object_id > 100
        FOR XML PATH, ROOT('tables'), ELEMENTS XSINIL
    ), 2),
    -- views
    CONVERT(xml, (
        SELECT * FROM sys.views
        WHERE object_id > 100
        FOR XML PATH, ROOT('views'), ELEMENTS XSINIL
    ), 2),
    -- columns
    CONVERT(xml, (
        SELECT * FROM sys.columns
        WHERE object_id > 100
        FOR XML PATH, ROOT('columns'), ELEMENTS XSINIL
    ), 2),
    -- identity_columns
    CONVERT(xml, (
        SELECT * FROM sys.identity_columns
        WHERE object_id > 100
        FOR XML PATH, ROOT('identity_columns'), ELEMENTS XSINIL
    ), 2),
    -- computed_columns
    CONVERT(xml, (
        SELECT * FROM sys.computed_columns
        WHERE object_id > 100
        FOR XML PATH, ROOT('computed_columns'), ELEMENTS XSINIL
    ), 2),
    -- default_constraints 
    CONVERT(xml, (
        SELECT * FROM sys.default_constraints 
        WHERE object_id > 100
        FOR XML PATH, ROOT('default_constraints'), ELEMENTS XSINIL
    ), 2),
    -- check_constraints 
    CONVERT(xml, (
        SELECT * FROM sys.check_constraints 
        WHERE object_id > 100
        FOR XML PATH, ROOT('check_constraints'), ELEMENTS XSINIL
    ), 2),
    -- key_constraints
    CONVERT(xml, (
        SELECT * FROM sys.key_constraints
        WHERE parent_object_id > 100
        FOR XML PATH, ROOT('key_constraints'), ELEMENTS XSINIL
    ), 2),
    -- foreign_keys
    CONVERT(xml, (
        SELECT * FROM sys.foreign_keys
        WHERE parent_object_id > 100
        FOR XML PATH, ROOT('foreign_keys'), ELEMENTS XSINIL
    ), 2),
    -- foreign_key_columns
    CONVERT(xml, (
        SELECT * FROM sys.foreign_key_columns
        WHERE parent_object_id > 100
        FOR XML PATH, ROOT('foreign_key_columns'), ELEMENTS XSINIL
    ), 2),
    -- sequences
    CONVERT(xml, (
        SELECT * FROM sys.sequences
        WHERE object_id > 100
        FOR XML PATH, ROOT('sequences'), ELEMENTS XSINIL
    ), 2),
    -- indexes
    CONVERT(xml, (
        SELECT * FROM sys.indexes
        WHERE object_id > 100
        FOR XML PATH, ROOT('indexes'), ELEMENTS XSINIL
    ), 2),
    -- index_columns
    CONVERT(xml, (
        SELECT * FROM sys.index_columns
        WHERE object_id > 100
        FOR XML PATH, ROOT('index_columns'), ELEMENTS XSINIL
    ), 2),
    -- stats
    CONVERT(xml, (
        SELECT * FROM sys.stats
        WHERE object_id > 100
        FOR XML PATH, ROOT('stats'), ELEMENTS XSINIL
    ), 2),
    -- synonyms
    CONVERT(xml, (
        SELECT * FROM sys.synonyms
        FOR XML PATH, ROOT('synonyms'), ELEMENTS XSINIL
    ), 2),
    -- procedures
    CONVERT(xml, (
        SELECT * FROM sys.procedures
        FOR XML PATH, ROOT('procedures'), ELEMENTS XSINIL
    ), 2),
    -- functions
    CONVERT(xml, (
        SELECT * FROM sys.objects
        WHERE object_id > 100
        AND type IN ('FN', 'TF', 'IF')
        FOR XML PATH, ROOT('functions'), ELEMENTS XSINIL
    ), 2),
    -- parameters
    CONVERT(xml, (
        SELECT * FROM sys.parameters
        FOR XML PATH, ROOT('parameters'), ELEMENTS XSINIL
    ), 2),
    -- triggers
    CONVERT(xml, (
        SELECT * FROM sys.triggers
        WHERE parent_id > 100
        FOR XML PATH, ROOT('triggers'), ELEMENTS XSINIL
    ), 2),
    -- table_types
    CONVERT(xml, (
        SELECT * FROM sys.table_types
        FOR XML PATH, ROOT('table_types'), ELEMENTS XSINIL
    ), 2),
    -- assembly_modules
    CONVERT(xml, (
        SELECT * FROM sys.assembly_modules
        FOR XML PATH, ROOT('assembly_modules'), ELEMENTS XSINIL
    ), 2),
    -- sql_modules
    CONVERT(xml, (
        SELECT * FROM sys.sql_modules
        FOR XML PATH, ROOT('sql_modules'), ELEMENTS XSINIL
    ), 2),
    -- partitions
    CONVERT(xml, (
        SELECT * FROM sys.partitions
        WHERE object_id > 100
        FOR XML PATH, ROOT('partitions'), ELEMENTS XSINIL
    ), 2),
    -- partition_functions
    CONVERT(xml, (
        SELECT * FROM sys.partition_functions
        FOR XML PATH, ROOT('partition_functions'), ELEMENTS XSINIL
    ), 2),
    -- partition_schemes
    CONVERT(xml, (
        SELECT * FROM sys.partition_schemes
        FOR XML PATH, ROOT('partition_schemes'), ELEMENTS XSINIL
    ), 2),

    -- when this audit was run
    CURRENT_TIMESTAMP AS [current_timestamp]
FOR XML PATH('database'), ROOT('databaseinfo'), ELEMENTS XSINIL;