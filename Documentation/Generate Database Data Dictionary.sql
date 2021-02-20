SET NOCOUNT ON

-- database name
SELECT DB_NAME() AS database_name;


-- tables
SELECT table_catalog, table_schema, table_name
FROM INFORMATION_SCHEMA.TABLES
WHERE table_name NOT IN ('dtproperties', 'sysconstraints', 'syssegments')
AND TABLE_TYPE = 'BASE TABLE'
ORDER BY table_catalog, table_schema, table_name;


-- views
SELECT table_catalog, table_schema, table_name AS view_name, is_updatable
FROM INFORMATION_SCHEMA.VIEWS
WHERE table_name NOT IN ('dtproperties', 'sysconstraints', 'syssegments')
ORDER BY table_catalog, table_schema, table_name;


-- table columns
SELECT     
    table_catalog, table_schema, table_name, column_name, ordinal_position,    
    data_type,     
    [length/precision] =
         Case data_type
             WHEN 'char' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'nchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'varchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'nvarchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'numeric'  THEN (CASE ISNULL(numeric_precision, 0) WHEN 0 THEN '' ELSE convert(varchar(10), numeric_precision) + ', ' + convert(varchar(10), numeric_scale) END)
             WHEN 'decimal'  THEN (CASE ISNULL(numeric_precision, 0) WHEN 0 THEN '' ELSE convert(varchar(10), numeric_precision) + ', ' + convert(varchar(10), numeric_scale) END)
             Else ''
         End 
FROM INFORMATION_SCHEMA.Columns
WHERE table_name NOT IN ('dtproperties', 'sysconstraints', 'syssegments')
ORDER BY table_catalog, table_schema, table_name, ordinal_position;


-- stored procedures and functions
SELECT
     routine_catalog, routine_schema, routine_name, routine_type,
     [return_data_type] =
         CASE ISNULL(data_type, '')
             WHEN 'char' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN data_type + ' (MAX)' ELSE data_type + ' (' + convert(varchar(10), character_maximum_length) + ')' END)
             WHEN 'nchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN data_type + ' (MAX)' ELSE data_type + ' (' + convert(varchar(10), character_maximum_length) + ')' END)
             WHEN 'varchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN data_type + ' (MAX)' ELSE data_type + ' (' + convert(varchar(10), character_maximum_length) + ')' END)
             WHEN 'nvarchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN data_type + ' (MAX)' ELSE data_type + ' (' + convert(varchar(10), character_maximum_length) + ')' END)
             ELSE ISNULL(data_type, '')
         End 
FROM INFORMATION_SCHEMA.routines 
WHERE routine_name NOT IN (
'dt_addtosourcecontrol', 'dt_addtosourcecontrol_u', 'dt_adduserobject', 'dt_adduserobject_vcs', 
'dt_checkinobject', 'dt_checkinobject_u', 'dt_checkoutobject', 'dt_checkoutobject_u', 
'dt_displayoaerror', 'dt_displayoaerror_u', 'dt_droppropertiesbyid', 'dt_dropuserobjectbyid', 
'dt_generateansiname', 'dt_getobjwithprop', 'dt_getobjwithprop_u', 'dt_getpropertiesbyid', 
'dt_getpropertiesbyid_u', 'dt_getpropertiesbyid_vcs', 'dt_getpropertiesbyid_vcs_u', 'dt_isundersourcecontrol', 
'dt_isundersourcecontrol_u', 'dt_removefromsourcecontrol', 'dt_setpropertybyid', 'dt_setpropertybyid_u', 
'dt_validateloginparams', 'dt_validateloginparams_u', 'dt_vcsenabled', 'dt_verstamp006', 'dt_whocheckedout', 
'dt_whocheckedout_u')
ORDER BY routine_catalog, routine_schema, routine_name;


-- stored procedure and function parameters
SELECT 
    specific_catalog, specific_schema, specific_name, 
    parameter_name, 
    [length/precision] =
         Case data_type
             WHEN 'char' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'nchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'varchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'nvarchar' THEN (CASE ISNULL(character_maximum_length, 0) WHEN 0 THEN '' WHEN -1 THEN 'MAX' ELSE convert(varchar(10), character_maximum_length) END)
             WHEN 'numeric'  THEN (CASE ISNULL(numeric_precision, 0) WHEN 0 THEN '' ELSE convert(varchar(10), numeric_precision) + ', ' + convert(varchar(10), numeric_scale) END)
             WHEN 'decimal'  THEN (CASE ISNULL(numeric_precision, 0) WHEN 0 THEN '' ELSE convert(varchar(10), numeric_precision) + ', ' + convert(varchar(10), numeric_scale) END)
             Else ''
         End,
    ordinal_position, parameter_mode, is_result
FROM INFORMATION_SCHEMA.parameters
WHERE specific_name NOT IN (
'dt_addtosourcecontrol', 'dt_addtosourcecontrol_u', 'dt_adduserobject', 'dt_adduserobject_vcs', 
'dt_checkinobject', 'dt_checkinobject_u', 'dt_checkoutobject', 'dt_checkoutobject_u', 
'dt_displayoaerror', 'dt_displayoaerror_u', 'dt_droppropertiesbyid', 'dt_dropuserobjectbyid', 
'dt_generateansiname', 'dt_getobjwithprop', 'dt_getobjwithprop_u', 'dt_getpropertiesbyid', 
'dt_getpropertiesbyid_u', 'dt_getpropertiesbyid_vcs', 'dt_getpropertiesbyid_vcs_u', 'dt_isundersourcecontrol', 
'dt_isundersourcecontrol_u', 'dt_removefromsourcecontrol', 'dt_setpropertybyid', 'dt_setpropertybyid_u', 
'dt_validateloginparams', 'dt_validateloginparams_u', 'dt_vcsenabled', 'dt_verstamp006', 'dt_whocheckedout', 
'dt_whocheckedout_u')
ORDER BY specific_catalog, specific_schema, specific_name, ordinal_position;
