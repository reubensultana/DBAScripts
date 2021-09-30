/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/Report Server-level and Database-level permissions for a User.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,1433"

:CONNECT $(SQLServerInstance)
USE [master]
GO

SET NOCOUNT ON;

DECLARE @UserName nvarchar(128) = '%';      -- limit scope to a single login; uses pattern matching privided by the LIKE statement
DECLARE @DatabaseName nvarchar(128) = NULL; -- limit scope to a single database (NOTE: no wildcards allowed); default is all
DECLARE @ExcludeSystemDatabases bit = 0;    -- if value is "1" exclude system databases; default is to include them
DECLARE @XMLOutput bit = 0;                 -- output results as a XML structure; default is multiple result sets
DECLARE @ExcludedAccounts TABLE ([name] nvarchar(128)); -- -- list of accounts to exclude from the final queries and results
DECLARE @ExcludedDatabases TABLE ([database_id] int, [name] nvarchar(128)); -- -- list of databases to exclude
DECLARE @SQLcmd nvarchar(4000);

-- add account names that you want excluded here:
INSERT INTO @ExcludedAccounts VALUES (NULL);

-- add database names that you want excluded here:
INSERT INTO @ExcludedDatabases VALUES (NULL, NULL);

/* -------------------------------------------------- */
-- get the name for the SA login (security practices recommend that this should be renamed)
DECLARE @SALogin nvarchar(128) = N'';
SET @SALogin = (SELECT name FROM sys.server_principals WHERE sid = 0x01);

-- default accounts that will be excluded from the queries and results
INSERT INTO @ExcludedAccounts 
VALUES 
    ('dbo'), (@SALogin), ('guest'), ('NT AUTHORITY\SYSTEM'), ('NT SERVICE\MSSQLSERVER'), ('NT SERVICE\SQLSERVERAGENT'),
    ('##MS_PolicyEventProcessingLogin##'), ('##MS_PolicyTsqlExecutionLogin##'), ('##MS_AgentSigningCertificate##'),
    ('##MS_SSISServerCleanupJobLogin##'), ('##MS_SSISServerCleanupJobUser##'), ('MS_DataCollectorInternalUser'), 
    ('AllSchemaOwner'), ('ModuleSigner'),
    ('dc_admin'), ('dc_operator'), ('dc_proxy'), ('mds_email_user'), ('MS_DataCollectorInternalUser'), 
    ('DatabaseMailUser'), ('PolicyAdministratorRole'), 
    ('SQLAgentOperatorRole'), ('SQLAgentReaderRole'), ('SQLAgentUserRole'), 
    ('ServerGroupAdministratorRole'), ('ServerGroupReaderRole'), 
    ('RSExecRole'), ('TargetServersRole'), 
    ('UtilityCMRReader'), ('UtilityIMRReader'), ('UtilityIMRWriter'),
    ('dqs_administrator'), ('dqs_kb_editor'), ('MDS_ServiceAccounts'),
    ('ssis_admin'), ('ssis_logreader'), ('db_ssisadmin'), ('db_ssisltduser'), ('db_ssisoperator')
    ;

-- exclude Service Accounts
IF (OBJECT_ID('sys.dm_server_services') IS NOT NULL)
BEGIN
    SET @SQLcmd = N'SELECT [service_account] FROM sys.dm_server_services'
    INSERT INTO @ExcludedAccounts 
    EXEC sp_executesql @SQLcmd;
END

CREATE TABLE #msver (
	[Index] int,
	[Name] nvarchar(128),
	[Internal_Value] sql_variant,
	[Character_Value] nvarchar(4000)
);
-- populate the table
INSERT INTO #msver EXEC xp_msver;

DECLARE @ProductVersion nvarchar(128);
SET @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128));

-- exclude inaccessibile databases
-- exclude LOCAL databases in that are in SECONDARY role of an AG
SET @SQLcmd = N'
SELECT d.[database_id], d.[name]
FROM sys.dm_hadr_database_replica_states hdrs
    INNER JOIN sys.databases d ON hdrs.[database_id] = d.[database_id]
WHERE hdrs.[is_local]=1
';
  -- SQL Server 2014 (12.x) and later
 IF (@ProductVersion > '12.0')
    SET @SQLcmd = @SQLcmd + N'AND hdrs.[is_primary_replica]=0'

INSERT INTO @ExcludedDatabases
EXEC sp_executesql @SQLcmd;

-- exclude LOCAL databases in that are in SECONDARY role of Database Mirroring Configuration
SET @SQLcmd = N'
SELECT d.[database_id], d.[name]
FROM sys.databases d
    INNER JOIN sys.database_mirroring dm ON d.[database_id] = dm.[database_id]
WHERE dm.[mirroring_guid] IS NOT NULL AND dm.[mirroring_role] <> 1
';
INSERT INTO @ExcludedDatabases
EXEC sp_executesql @SQLcmd;


-- 1. server permissions
SELECT 
  [srvprin].[name] AS [server_principal],
  [srvprin].[type_desc] AS [principal_type],
  [srvperm].[permission_name] + N' (' + [srvperm].[class_desc] + (
    CASE [srvperm].[class_desc] 
        WHEN N'SERVER' THEN N''
        WHEN N'ENDPOINT' THEN N' ' + (SELECT CONVERT(nvarchar(10), port) FROM sys.tcp_endpoints WHERE endpoint_id >= 65536 AND endpoint_id = srvperm.major_id)
        ELSE N''
    END
    ) + N')' AS [permission_name],
  [srvperm].[state_desc],
  -- grant
    CASE 
    WHEN [srvperm].[permission_name] LIKE 'CONNECT SQL%' THEN '-- N/A' 
    ELSE 'USE [master];IF NOT EXISTS(SELECT * FROM sys.server_principals WHERE [name]=''' + [srvprin].[name] COLLATE DATABASE_DEFAULT + ''') GRANT ' + [srvperm].[permission_name] + ' TO ' + QUOTENAME([srvprin].[name], '[') + ';' 
    -- ELSE '--'
  END AS [grant_command],
  -- revoke
  CASE 
    WHEN [srvperm].[permission_name] LIKE 'CONNECT SQL%' THEN '-- USE [master];IF EXISTS(SELECT * FROM sys.server_principals WHERE [name]=''' + [srvprin].[name] COLLATE DATABASE_DEFAULT + ''') DROP LOGIN ' + QUOTENAME([srvprin].[name] COLLATE DATABASE_DEFAULT, '[') + ';' 
    ELSE 'USE [master];IF EXISTS(SELECT * FROM sys.server_principals WHERE [name]=''' + [srvprin].[name] COLLATE DATABASE_DEFAULT + ''') REVOKE ' + [srvperm].[permission_name] + ' TO ' + QUOTENAME([srvprin].[name], '[') + ';' 
    -- ELSE '--'
  END AS [revoke_command]
INTO #x_ServerPermissions
FROM [sys].[server_permissions] srvperm
    INNER JOIN [sys].[server_principals] srvprin ON [srvperm].[grantee_principal_id] = [srvprin].[principal_id] 
WHERE [srvprin].[type] IN ('S', 'U', 'G')
AND [srvprin].[name] LIKE COALESCE(@UserName, '%')
AND [srvprin].[name] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL);

-- 2. membership in server roles
SELECT 
    [lgn].[name] AS [member_name], 
    SUSER_NAME([rm].[role_principal_id]) AS [server_role],
    -- grant
    (CASE 
        WHEN ((@ProductVersion LIKE '9.%') OR (@ProductVersion LIKE '10.%')) THEN 'EXEC sp_addsrvrolemember ' + QUOTENAME([lgn].[name], '[') + ', ' + QUOTENAME(SUSER_NAME([rm].[role_principal_id]), '[') + ';'
        ELSE 'ALTER SERVER ROLE ' + QUOTENAME(SUSER_NAME([rm].[role_principal_id]), '[') + ' ADD MEMBER ' + QUOTENAME([lgn].[name], '[') + ';' 
    END) AS [grant_command],
    -- revoke
    (CASE 
        WHEN ((@ProductVersion LIKE '9.%') OR (@ProductVersion LIKE '10.%')) THEN 'EXEC sp_dropsrvrolemember ' + QUOTENAME([lgn].[name], '[') + ', ' + QUOTENAME(SUSER_NAME([rm].[role_principal_id]), '[') + ';'
        ELSE 'ALTER SERVER ROLE ' + QUOTENAME(SUSER_NAME([rm].[role_principal_id]), '[') + ' DROP MEMBER ' + QUOTENAME([lgn].[name], '[') + ';' 
    END) AS [revoke_command]
INTO #x_ServerRoleMembership
FROM [sys].[server_role_members] [rm]
    INNER JOIN [sys].[server_principals] [lgn] ON [rm].[member_principal_id] = [lgn].[principal_id]
WHERE [rm].[role_principal_id] BETWEEN 3 AND 10
AND [lgn].[name] LIKE COALESCE(@UserName, '%')
AND [lgn].[name] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL);


--DECLARE @DatabaseName nvarchar(128);
DECLARE @DatabaseList CURSOR;

CREATE TABLE #DatabasePermissions (
    [database_name] nvarchar(128),
    [database_principal] nvarchar(128),
    [permission_name] nvarchar(200),
    [object_name] nvarchar(250),
    [object_type] nvarchar(100)
);

CREATE TABLE #DatabaseRoleMembership (
    [database_name] nvarchar(128),
    [member_name] nvarchar(128),
    [database_role] nvarchar(128)
);
CREATE TABLE #DatabaseRolePermissions (
    [database_name] nvarchar(128),
    [database_principal] nvarchar(128),
    [permission_name] nvarchar(200),
    [object_name] nvarchar(250),
    [object_type] nvarchar(100)
);

CREATE TABLE #x_SsisdbPermissions (
    [database_name] nvarchar(128),
    [database_principal] nvarchar(128),
    [object_type] nvarchar(100),
    [object_name] nvarchar(250),
    [permission_type] nvarchar(100),
    [grant_command] nvarchar(max),
    [revoke_command] nvarchar(max)
);

SET @DatabaseList = CURSOR READ_ONLY FOR
    SELECT [name] FROM sys.databases
    WHERE state = 0
    AND database_id > (CASE WHEN @ExcludeSystemDatabases = 0 THEN 0 ELSE 4 END)
    AND database_id = (CASE WHEN NULLIF(@DatabaseName, '') IS NOT NULL THEN DB_ID(@DatabaseName) ELSE database_id END)
    -- exclude these databases
    AND [database_id] NOT IN (
        SELECT [database_id] FROM @ExcludedDatabases WHERE [name] IS NOT NULL
    )
OPEN @DatabaseList
FETCH NEXT FROM @DatabaseList INTO @DatabaseName
WHILE (@@FETCH_STATUS = 0)
BEGIN
    SET @SQLcmd = N'';
    -- 3. database permissions
    SET @SQLcmd = N'
USE ' + QUOTENAME(@DatabaseName, '[') + ';
SELECT 
    DB_NAME() AS [database_name],
    [prin].[name] [database_principal], 
    [sec].[state_desc] + '' '' + [sec].[permission_name] [permission_name],
    COALESCE(QUOTENAME([sch].[name], ''['') + ''.'' + QUOTENAME([obj].[name], ''[''), ''N/A'') [object_name],
    COALESCE([obj].[type_desc], ''N/A'') [object_type]
FROM [sys].[database_permissions] [sec]
    INNER JOIN [sys].[database_principals] [prin]
        INNER JOIN [sys].[server_principals] sp ON sp.[sid] = [prin].[sid]
    ON [sec].[grantee_principal_id] = [prin].[principal_id]
    LEFT OUTER JOIN [sys].[objects] [obj] 
        INNER JOIN [sys].[schemas] [sch] ON [sch].[schema_id] = [obj].[schema_id]
    ON [obj].[object_id] = [sec].[major_id]
WHERE [sp].[name] LIKE ''' + COALESCE(@UserName, '%') + '''
AND [sec].[class] IN (0, 1);
';
    INSERT INTO #DatabasePermissions
        EXEC sp_executesql @SQLcmd;

    SET @SQLcmd = N'';
    -- 4.1 membership in and permissions of database roles
    SET @SQLcmd = N'
USE ' + QUOTENAME(@DatabaseName, '[') + ';
IF EXISTS(
    SELECT 1
    FROM [sys].[database_role_members] [m]
        INNER JOIN [sys].[database_principals] [u] ON [u].[principal_id] = [m].[member_principal_id]
        INNER JOIN [sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
    WHERE [u].[name] LIKE ''' + COALESCE(@UserName, '%') + '''
    )
BEGIN
    WITH cteRoles ( [member_name], [database_role] )
    AS (
        -- get anchor member
        SELECT 
            [u].[name] [member_name],
            [g].[name] [database_role]
        FROM [sys].[database_role_members] [m]
            INNER JOIN [sys].[database_principals] [u] ON [u].[principal_id] = [m].[member_principal_id]
            INNER JOIN [sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
            INNER JOIN [sys].[server_principals] sp ON sp.[sid] = [u].[sid]
        WHERE [sp].[name] LIKE ''' + COALESCE(@UserName, '%') + '''

        UNION ALL
        -- get nested roles
        SELECT 
            [u].[name],
            [g].[name]
        FROM [sys].[database_role_members] [m]
            INNER JOIN [sys].[database_principals] [u] ON [u].[principal_id] = [m].[member_principal_id]
            INNER JOIN [sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
    )
    SELECT DISTINCT
        DB_NAME() AS [database_name],
        [member_name],
        [database_role]
    FROM cteRoles;
END
';
    INSERT INTO #DatabaseRoleMembership
        EXEC sp_executesql @SQLcmd;

    -- 5. database role permissions
    SET @SQLcmd = N'
USE ' + QUOTENAME(@DatabaseName, '[') + ';
-- check if a member of a role
IF EXISTS(
    SELECT 1
    FROM [sys].[database_role_members] [m]
        INNER JOIN [sys].[database_principals] [u] 
            INNER JOIN [sys].[server_principals] sp ON sp.[sid] = [u].[sid]
        ON [u].[principal_id] = [m].[member_principal_id]
        INNER JOIN [sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
    WHERE [sp].[name] LIKE ''' + COALESCE(@UserName, '%') + '''
    )
BEGIN
    -- get the role name/s
    WITH cteRoles ( [database_role] )
    AS (
        -- get anchor member
        SELECT 
            [g].[name] [database_role]
        FROM [sys].[database_role_members] [m]
            INNER JOIN [sys].[database_principals] [u] ON [u].[principal_id] = [m].[member_principal_id]
            INNER JOIN [sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
            INNER JOIN [sys].[server_principals] sp ON sp.[sid] = [u].[sid]
        WHERE [sp].[name] LIKE ''' + COALESCE(@UserName, '%') + '''

        UNION ALL
        -- get nested roles
        SELECT 
            [g].[name]
        FROM [sys].[database_role_members] [m]
            INNER JOIN [sys].[database_principals] [u] ON [u].[principal_id] = [m].[member_principal_id]
            INNER JOIN [sys].[database_principals] [g] ON [g].[principal_id] = [m].[role_principal_id]
    )
    SELECT DISTINCT
        DB_NAME() AS [database_name],
        [prin].[name] [database_principal], 
        [sec].[state_desc] + '' '' + [sec].[permission_name] [permission_name],
        COALESCE(QUOTENAME([sch].[name], ''['') + ''.'' + QUOTENAME([obj].[name], ''[''), ''N/A'') [object_name],
        COALESCE([obj].[type_desc], ''N/A'') [object_type]
    FROM [sys].[database_permissions] [sec]
        INNER JOIN [sys].[database_principals] [prin] 
            --INNER JOIN [sys].[server_principals] sp ON sp.[sid] = [prin].[sid]
        ON [sec].[grantee_principal_id] = [prin].[principal_id]
        LEFT OUTER JOIN [sys].[objects] [obj] 
            INNER JOIN [sys].[schemas] [sch] ON [sch].[schema_id] = [obj].[schema_id]
        ON [obj].[object_id] = [sec].[major_id]
    WHERE [prin].[name] IN ( SELECT [database_role] FROM cteRoles )
    AND [sec].[class] IN (0, 1);
END
';
    INSERT INTO #DatabaseRolePermissions
        EXEC sp_executesql @SQLcmd;

-- 4.2. orphaned database users
/*
SELECT 
    DB_NAME() AS [database_name],
    dp.[name] AS [database_principal]
FROM sys.database_principals dp
    LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
WHERE dp.principal_id > 4
AND dp.type LIKE '[GSU]'
AND sp.sid IS NULL
*/
    SET @SQLcmd = N'
USE ' + QUOTENAME(@DatabaseName, '[') + ';
SELECT 
    DB_NAME() AS [database_name],
    dp.[name] AS [database_principal],
    ''GRANT CONNECT'' AS [permission_name],
    ''N/A'' AS [object_name],
    ''N/A'' AS [object_type]
FROM sys.database_principals dp
    LEFT JOIN sys.server_principals sp ON sp.sid = dp.sid
WHERE dp.principal_id > 4
AND dp.type LIKE ''[GSU]''
AND sp.sid IS NULL
AND dp.[name] LIKE ''' + COALESCE(@UserName, '%') + ''';
';
    INSERT INTO #DatabasePermissions
        EXEC sp_executesql @SQLcmd;

    FETCH NEXT FROM @DatabaseList INTO @DatabaseName
END
CLOSE @DatabaseList;
DEALLOCATE @DatabaseList;

-- 3. database and object permissions
SELECT DISTINCT
    dp.[database_name],
    dp.[database_principal],
    dp.[permission_name],
    dp.[object_name],
    dp.[object_type],
    -- grant
    'USE ' + QUOTENAME(dp.database_name, '[') + ';' + 
    dp.[permission_name] + 
        CASE dp.[object_name] WHEN 'N/A' THEN '' ELSE ' ON ' + dp.[object_name] END + 
        ' TO ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [grant_command],
    -- revoke
    'USE ' + QUOTENAME(dp.database_name, '[') + ';' + 
    REPLACE(REPLACE(dp.[permission_name], 'GRANT', 'REVOKE'), 'DENY', 'REVOKE') + 
        CASE dp.[object_name] WHEN 'N/A' THEN '' ELSE ' ON ' + dp.[object_name] END + 
        ' TO ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [revoke_command]
INTO #x_DatabaseObjectPermissions
FROM #DatabasePermissions dp
WHERE dp.[database_principal] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL);

-- 3. user accounts and schemas
with cteDatabasePermissions 
AS (
    SELECT DISTINCT
        dp.[database_name],
        dp.[database_principal],
        -- grant
        'USE ' + QUOTENAME(dp.database_name, '[') + ';' + 
        'IF NOT EXISTS(SELECT 1 FROM sys.schemas WHERE [name] = ''' + dp.[database_principal] + ''') CREATE SCHEMA ' + QUOTENAME(dp.[database_principal], '[') + ' AUTHORIZATION [dbo];' AS [grant_command],
        -- revoke
        'USE ' + QUOTENAME(dp.database_name, '[') + ';' + 
        'IF EXISTS(SELECT 1 FROM sys.schemas WHERE [name] = ''' + dp.[database_principal] + ''') DROP SCHEMA ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [revoke_command],
        0 AS [ordering_column]
    FROM #DatabasePermissions dp
    WHERE dp.[permission_name] = 'GRANT CONNECT'
    AND dp.[database_principal] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL)
    UNION ALL
    SELECT DISTINCT
        dp.[database_name],
        dp.[database_principal],
        -- grant
        'USE ' + QUOTENAME(dp.database_name, '[') + ';' + 
        'IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE [name]=''' + dp.[database_principal] + ''') CREATE USER ' + QUOTENAME(dp.[database_principal], '[') + ' FOR LOGIN ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [grant_command],
        -- revoke
        'USE ' + QUOTENAME(dp.database_name, '[') + ';' + 
        'IF EXISTS(SELECT * FROM sys.database_principals WHERE [name]=''' + dp.[database_principal] + ''') DROP USER ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [revoke_command],
        1 AS [ordering_column]
    FROM #DatabasePermissions dp
    WHERE dp.[permission_name] = 'GRANT CONNECT'
    AND dp.[database_principal] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL)
)
SELECT [database_name], [database_principal], [grant_command], [revoke_command]
INTO #x_UsersAndSchemas
FROM cteDatabasePermissions;

-- 4. role membership
SELECT
    drm.database_name, drm.member_name, drm.database_role,
    -- grant
    'USE ' + QUOTENAME(drm.database_name, '[') + ';' + (
    CASE 
        WHEN ((@ProductVersion LIKE '9.%') OR (@ProductVersion LIKE '10.%')) THEN 'EXEC sp_addrolemember ' + QUOTENAME([database_role], '[') + ', ' + QUOTENAME([member_name], '[') + ';'
        ELSE 'ALTER ROLE ' + QUOTENAME([database_role], '[') + ' ADD MEMBER ' + QUOTENAME([member_name], '[') + ';' 
    END) AS [grant_command],
    -- revoke
    'USE ' + QUOTENAME(drm.database_name, '[') + ';' + (
    CASE 
        WHEN ((@ProductVersion LIKE '9.%') OR (@ProductVersion LIKE '10.%')) THEN 'EXEC sp_droprolemember ' + QUOTENAME([database_role], '[') + ', ' + QUOTENAME([member_name], '[') + ';'
        ELSE 'ALTER ROLE ' + QUOTENAME([database_role], '[') + ' DROP MEMBER ' + QUOTENAME([member_name], '[') + ';' 
    END) AS [revoke_command]
INTO #x_DatabaseRoleMembership
FROM #DatabaseRoleMembership drm
WHERE drm.member_name NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL)
AND drm.member_name LIKE COALESCE(@UserName, '%');

-- 5. permissions inherited through database roles
SELECT *, 
    'USE ' + QUOTENAME(dp.[database_name], '[') + ';' + 
    dp.[permission_name] + 
        CASE dp.[object_name] WHEN 'N/A' THEN '' ELSE ' ON ' + dp.[object_name] END + 
        ' TO ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [grant_command],
    -- revoke
    'USE ' + QUOTENAME(dp.[database_name], '[') + ';' + 
    REPLACE(REPLACE(dp.[permission_name], 'GRANT', 'REVOKE'), 'DENY', 'REVOKE') + 
        CASE dp.[object_name] WHEN 'N/A' THEN '' ELSE ' ON ' + dp.[object_name] END + 
        ' TO ' + QUOTENAME(dp.[database_principal], '[') + ';' AS [revoke_command]
INTO #x_InheritedPermissions
FROM #DatabaseRolePermissions dp
WHERE dp.[database_principal] IN (
    SELECT DISTINCT [database_role] FROM #x_DatabaseRoleMembership
    EXCEPT
    SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL
);

-- 6. get SSISDB permissions
IF EXISTS(SELECT 1 FROM sys.databases WHERE [name] = 'SSISDB')
BEGIN
    -- using Dynamic SQL as Parsing will erro if the database does not exist
    SET @SQLcmd = N'
USE [SSISDB];
SELECT 
    DB_NAME() AS [database_name],
    dp.[name] AS [database_principal],

    (CASE eop.[object_type] 
        WHEN 1 THEN ''Folder'' 
        WHEN 2 THEN ''Project'' 
        WHEN 3 THEN ''Environment'' 
        WHEN 4 THEN ''Operation'' 
        ELSE '''' 
    END) AS [object_type],

    (CASE eop.[object_type] 
        WHEN 1 THEN (SELECT [name] FROM [catalog].[folders] WHERE [folder_id] = eop.[object_id])
        WHEN 2 THEN (SELECT [name] FROM [catalog].[projects] WHERE [project_id] = eop.[object_id])
        WHEN 3 THEN (SELECT [name] FROM [catalog].[environments] WHERE [environment_id] = eop.[object_id])
        WHEN 4 THEN ''Operation '' + CAST(eop.[object_id] AS varchar(10)) + '' - see help for [SSISDB].[catalog].[operations]''
        ELSE ''''
    END) AS [object_name],
        
    (CASE eop.[permission_type] 
        WHEN 1 THEN ''Read''
        WHEN 2 THEN ''Modify''
        WHEN 3 THEN ''Execute''
        WHEN 4 THEN ''Manage Permissions''
        WHEN 100 THEN ''Create Objects''
        WHEN 101 THEN ''Read Objects''
        WHEN 102 THEN ''Modify Objects''
        WHEN 103 THEN ''Execute Objects''
        WHEN 104 THEN ''Manage Object Permissions''
        ELSE ''''
    END) AS [permission_type],

    -- grant
    ''EXEC [SSISDB].[catalog].[grant_permission] @object_type = '' + 
        CAST(eop.[object_type] AS varchar(10)) + '', @object_id = '' + 
        CAST(eop.[object_id] AS varchar(10)) + '', @principal_id = '' + 
        CAST(eop.[principal_id] AS varchar(10)) + '', @permission_type = '' + 
        CAST(eop.[permission_type] AS varchar(10)) + '';'' AS [grant_command],
    
    -- revoke
    ''EXEC [SSISDB].[catalog].[revoke_permission] @object_type = '' + 
        CAST(eop.[object_type] AS varchar(10)) + '', @object_id = '' + 
        CAST(eop.[object_id] AS varchar(10)) + '', @principal_id = '' + 
        CAST(eop.[principal_id] AS varchar(10)) + '', @permission_type = '' + 
        CAST(eop.[permission_type] AS varchar(10)) + '';'' AS [revoke_command]

FROM [catalog].[explicit_object_permissions] eop
    INNER JOIN sys.database_principals dp 
        INNER JOIN [sys].[server_principals] sp ON sp.[sid] = [dp].[sid]
    ON eop.[principal_id] = dp.principal_id
AND sp.[name] LIKE ''' + COALESCE(@UserName, '%') + '''';

    INSERT INTO #x_SsisdbPermissions
    EXEC sp_executesql @SQLcmd;
END

-- 7. get SQL Agent job ownership
SELECT 
    sj.[name] AS [job_name],
    sj.[enabled] AS [is_enabled],
    sp.[name] AS [owner_name],
    'EXEC msdb.dbo.sp_update_job @job_id=N''' + CAST(sj.[job_id] AS nvarchar(128)) + ''', @owner_login_name=N''' + @SALogin + ''';' AS [change_ownership_command]
INTO #x_SQLAgentJobOwnership
FROM msdb.dbo.sysjobs sj
    INNER JOIN sys.server_principals sp ON sj.[owner_sid] = sp.[sid]
WHERE sp.[name] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL)
AND sp.[name] LIKE '' + COALESCE(@UserName, '%') + '';

-- 8. get database ownership
SELECT 
    d.[name] AS [database_name],
    sp.[name] AS [owner_name],
    'ALTER AUTHORIZATION ON DATABASE::' + QUOTENAME(d.[name], '[') + ' TO [' + @SALogin + '];' AS [change_ownership_command]
INTO #x_DatabaseOwnership
FROM sys.databases d
    INNER JOIN sys.server_principals sp ON d.[owner_sid] = sp.[sid]
WHERE sp.[name] NOT IN (SELECT [name] FROM @ExcludedAccounts WHERE [name] IS NOT NULL)
AND sp.[name] LIKE '' + COALESCE(@UserName, '%') + '';

-- 9. get endpoint ownership
SELECT 
    ep.[name] AS [endpoint_name],
    sp.[name] AS [owner_name],
    'ALTER AUTHORIZATION ON ENDPOINT::' + QUOTENAME(d.[name], '[') + ' TO [' + @SALogin + '];' AS [change_ownership_command]
INTO #x_EndpointOwnership
FROM sys.endpoints ep
    INNER JOIN sys.server_principals sp ON ep.[principal_id] = sp.[principal_id]
WHERE principal_id > 1;

-- 10. get ag ownership
SELECT
    ag.[name] AS [availability_group_name],
    sp.[name] AS [owner_name],
    'ALTER AUTHORIZATION ON AVAILABILITY GROUP::' + QUOTENAME(ag.[name], '[') + ' TO [' + @SALogin + '];' AS [change_ownership_command]
INTO #x_AvailabilityGroupOwnership
FROM sys.availability_groups ag
    INNER JOIN sys.availability_replicas ar ON ag.[group_id] = ar.[group_id]
    INNER JOIN sys.server_principals sp ON ar.[owner_sid] = sp.[sid]
WHERE ar.[replica_server_name] = @@SERVERNAME
AND ar.[owner_sid] <> 0x01;

-- return data collected
IF (@XMLOutput = 0)
BEGIN
    -- return multiple results sets
    SELECT UPPER(COALESCE(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)), '')) AS [server_name];
    -- server_permissions
    SELECT * FROM #x_ServerPermissions ORDER BY [server_principal], [principal_type];
    -- server_role_membership
    SELECT * FROM #x_ServerRoleMembership ORDER BY [member_name], [server_role];
    -- database_object_permissions
    SELECT * FROM #x_DatabaseObjectPermissions ORDER BY [database_name], [database_principal];
    -- users_and_schemas
    SELECT * FROM #x_UsersAndSchemas ORDER BY [database_name], [database_principal];
    -- database_role_membership
    SELECT * FROM #x_DatabaseRoleMembership ORDER BY [database_name], [member_name], [database_role];
    -- inherited_permissions
    SELECT * FROM #x_InheritedPermissions ORDER BY [database_name], [database_principal], [permission_name], [object_name];
    -- ssisdb_permissions
    SELECT * FROM #x_SsisdbPermissions ORDER BY [database_name], [database_principal], [object_type], [object_name], [permission_type];
    -- sql_agent_job_ownership
    SELECT * FROM #x_SQLAgentJobOwnership ORDER BY [job_name], [is_enabled], [owner_name];
    -- database_ownership
    SELECT * FROM #x_DatabaseOwnership ORDER BY [database_name], [owner_name];
    -- endpoint_ownership
    SELECT * FROM #x_EndpointOwnership ORDER BY [endpoint_name], [owner_name]
    -- ag_ownership
    SELECT * FROM #x_AvailabilityGroupOwnership ORDER BY [availability_group_name], [owner_name]
    -- when this report was run
    SELECT CURRENT_TIMESTAMP AS [current_timestamp];
END
ELSE IF (@XMLOutput = 1)
BEGIN
    -- return XML structure
    SELECT 
        UPPER(COALESCE(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)), '')) AS [server_name],
        -- server_permissions
        CONVERT(xml, (
            SELECT * FROM #x_ServerPermissions ORDER BY [server_principal], [principal_type]
            FOR XML PATH, ROOT('server_permissions'), ELEMENTS XSINIL
        ), 2),
        -- server_role_membership
        CONVERT(xml, (
            SELECT * FROM #x_ServerRoleMembership ORDER BY [member_name], [server_role]
            FOR XML PATH, ROOT('server_role_membership'), ELEMENTS XSINIL
        ), 2),
        -- database_object_permissions
        CONVERT(xml, (
            SELECT * FROM #x_DatabaseObjectPermissions ORDER BY [database_name], [database_principal]
            FOR XML PATH, ROOT('database_object_permissions'), ELEMENTS XSINIL
        ), 2),
        -- users_and_schemas
        CONVERT(xml, (
            SELECT * FROM #x_UsersAndSchemas ORDER BY [database_name], [database_principal]
            FOR XML PATH, ROOT('users_and_schemas'), ELEMENTS XSINIL
        ), 2),
        -- database_role_membership
        CONVERT(xml, (
            SELECT * FROM #x_DatabaseRoleMembership ORDER BY [database_name], [member_name], [database_role]
            FOR XML PATH, ROOT('database_role_membership'), ELEMENTS XSINIL
        ), 2),
        -- inherited_permissions
        CONVERT(xml, (
            SELECT * FROM #x_InheritedPermissions ORDER BY [database_name], [database_principal], [permission_name], [object_name]
            FOR XML PATH, ROOT('inherited_permissions'), ELEMENTS XSINIL
        ), 2),
        -- ssisdb_permissions
        CONVERT(xml, (
            SELECT * FROM #x_SsisdbPermissions ORDER BY [database_name], [database_principal], [object_type], [object_name], [permission_type]
            FOR XML PATH, ROOT('ssisdb_permissions'), ELEMENTS XSINIL
        ), 2),
        -- sql_agent_job_ownership
        CONVERT(xml, (
            SELECT * FROM #x_SQLAgentJobOwnership ORDER BY [job_name], [is_enabled], [owner_name]
            FOR XML PATH, ROOT('sql_agent_job_ownership'), ELEMENTS XSINIL
        ), 2),
        -- database_ownership
        CONVERT(xml, (
            SELECT * FROM #x_DatabaseOwnership ORDER BY [database_name], [owner_name]
            FOR XML PATH, ROOT('database_ownership'), ELEMENTS XSINIL
        ), 2),
        -- endpoint_ownership
        CONVERT(xml, (
            SELECT * FROM #x_EndpointOwnership ORDER BY [endpoint_name], [owner_name]
            FOR XML PATH, ROOT('endpoint_ownership'), ELEMENTS XSINIL
        ), 2),
        -- ag_ownership
        CONVERT(xml, (
            SELECT * FROM #x_AvailabilityGroupOwnership ORDER BY [availability_group_name], [owner_name]
            FOR XML PATH, ROOT('ag_ownership'), ELEMENTS XSINIL
        ), 2),
        -- when this report was run
        CURRENT_TIMESTAMP AS [current_timestamp]

    FOR XML PATH('server'), ROOT('permissions'), ELEMENTS XSINIL;
END

-- clean up
DROP TABLE #x_ServerPermissions;
DROP TABLE #x_ServerRoleMembership;
DROP TABLE #x_DatabaseObjectPermissions;
DROP TABLE #x_UsersAndSchemas;
DROP TABLE #x_DatabaseRoleMembership;
DROP TABLE #x_InheritedPermissions;
DROP TABLE #x_SsisdbPermissions;
DROP TABLE #x_SQLAgentJobOwnership;
DROP TABLE #x_DatabaseOwnership;
DROP TABLE #x_EndpointOwnership;
DROP TABLE #x_AvailabilityGroupOwnership;

DROP TABLE #DatabasePermissions;
DROP TABLE #DatabaseRoleMembership;
DROP TABLE #DatabaseRolePermissions;

DROP TABLE #msver;
