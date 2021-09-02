/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/ServerAudit.sql */

USE [master]
GO
SET NOCOUNT ON;
/*
NOTES:
1.  When a server audit is created, it is in a disabled state.
2.  The minimum size that you can specify for max_size is 2 MB and the maximum is 2,147,483,647 TB. When UNLIMITED is specified, the file grows until the disk is full. 
    (0 also indicates UNLIMITED.) Specifying a value lower than 2 MB will raise the error MSG_MAXSIZE_TOO_SMALL. The default value is UNLIMITED.
3.  Check that enough storage is available with the configuration parameters defined for the audit.
*/

-- define Audit params
DECLARE @OrganisationName nvarchar(50);	-- The Organisation Name which will be used to define the Audit name property. NOTE: All UPPERCASE and do not use spaces
DECLARE @AuditFolder nvarchar(1000);    -- The path of the audit log. The file name is generated based on the audit name and audit GUID.
DECLARE @AuditMaxSizeMB int;            -- The maximum size to which the audit file can grow. The max_size value must be an integer followed by MB, GB, TB, or UNLIMITED.
                                        -- The minimum size that you can specify for max_size is 2 MB and the maximum is 2,147,483,647 TB. When UNLIMITED is specified, the file grows until the disk is full.
                                        -- (0 also indicates UNLIMITED.) Specifying a value lower than 2 MB will raise the error MSG_MAXSIZE_TOO_SMALL. The default value is UNLIMITED.
DECLARE @AuditMaxRolloverFileCount int; -- The maximum number of files to retain in the file system in addition to the current file. The MAX_ROLLOVER_FILES value must be an integer or UNLIMITED.
DECLARE @AuditReserverDiskSpace bit;    -- This option pre-allocates the file on the disk to the MAXSIZE value.

SET @OrganisationName = 'CONTOSO';      -- keep it short; use an acronym if possible
SET @AuditMaxSizeMB = 5;
SET @AuditMaxRolloverFileCount = 400;
SET @AuditReserverDiskSpace = 0;

DECLARE @SqlCmd nvarchar(max);

DECLARE @EngineEdition nvarchar(128);
SET @EngineEdition = CAST(SERVERPROPERTY('Edition') AS nvarchar(128));

-- check if the OS is Windows or Linux
DECLARE @HostPlatform nvarchar(256); -- Windows or Linux
SET @HostPlatform = (SELECT TOP(1) host_platform FROM sys.dm_os_host_info);
DECLARE @FolderSeparator nchar(1); -- "\" or "/"
SET @FolderSeparator = CASE @HostPlatform WHEN 'Windows' THEN N'\' WHEN 'Linux' THEN N'/' END;

IF (@HostPlatform != 'Windows')
BEGIN
    RAISERROR('This script is not yet supported on non-Windows platforms', 16, 1);
    RETURN
END

-- check Engine Edition
IF  (@EngineEdition LIKE 'Developer%') OR
    (@EngineEdition LIKE 'Enterprise%') OR
    (@EngineEdition LIKE 'Business Intelligence%') OR
    (@EngineEdition LIKE 'Standard%')
BEGIN

    IF (@AuditMaxSizeMB < 2)
        SET @AuditMaxSizeMB = 5;

    SET @AuditFolder = (
        SELECT SUBSTRING([physical_name], 1, CHARINDEX(@FolderSeparator + 'DATA' + @FolderSeparator + 'master.mdf', [physical_name])) + 'AUDIT\' + @OrganisationName + N'_STANDARD_AUDIT'
        FROM sys.master_files WHERE [database_id] = 1 AND [file_id] = 1
    );

    -- create the folder structure
    IF @HostPlatform = 'Windows'
        EXEC dbo.xp_create_subdir @AuditFolder;

    -- create the Server Audit
    SET @OrganisationName = UPPER(REPLACE(@OrganisationName, ' ', ''));

-- PART 1: create the Server Audit and set the properties
-- https://docs.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine
    IF NOT EXISTS(SELECT 1 FROM sys.server_audits WHERE [name] = @OrganisationName + N'_STANDARD_AUDIT')
    BEGIN
        SET @SqlCmd = N'USE [master];
CREATE SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT]
TO FILE (
	FILEPATH = ''' + @AuditFolder + N'''
	, MAXSIZE = ' + CAST(@AuditMaxSizeMB AS nvarchar(10)) + ' MB
	, MAX_ROLLOVER_FILES = ' + CAST(@AuditMaxRolloverFileCount AS nvarchar(10)) + N'
	, RESERVE_DISK_SPACE = ' + CASE @AuditReserverDiskSpace WHEN 0 THEN N'OFF' ELSE N'ON' END + N'
)
WITH (
	QUEUE_DELAY = 1000' +       -- Determines the time, in milliseconds, that can elapse before audit actions are forced to be processed. A value of 0 indicates synchronous delivery.
N'	, ON_FAILURE = CONTINUE' +  -- Indicates whether the instance writing to the target should fail, continue, or stop SQL Server if the target cannot write to the audit log.
N')';
        EXEC sp_executesql @SqlCmd;

        -- add filters to the Audit
        SET @SqlCmd = N'USE [master];
ALTER SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT]
WHERE
--  The following line is used solely to ensure that the WHERE statement begins with a clause 
--  that is guaranteed true.  This allows us to begin each subsequent line with AND, making
--  editing easier.  If you wish, you may remove this line (and the first AND).
([Statement] <> ''BBF5B619-D44A-4616-A259-CDD9D426D794'')

-- exclude "tempdb" (i.e. temporary tables) from capture
AND ([database_name] <> N''tempdb'')

--  The following filters out system-generated statements accessing SQL Server internal tables
--  that are not directly visible to or accessible by user processes, but which do appear among 
--  log records if not suppressed.
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syspalnames'')
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''objects$'')
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syspalvalues'')
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''configurations$'')
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''system_columns$'')
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''server_audits$'')
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''parameters$'')

--  The following suppresses audit trail messages about the execution of statements within procedures 
--  and functions.  This is done because it is generally not useful to trace internal operations 
--  of a function or procedure, and this is a simple way to detect them.
--  However, this opens an opportunity for an adversary to obscure actions on the database,
--  so make sure that the creation and modification of functions and procedures is tracked.
--  Further, details of your application architecture may be incompatible with this technique.
--  Use with care.
AND NOT ([Additional_Information] LIKE ''<tsql_stack>%'')

--  The following statements filter out audit records for certain system-generated actions that 
--  frequently occur, and which do not aid in tracking the activities of a user or process.
AND NOT([Schema_Name] = ''sys'' AND [Statement] LIKE 
        ''SELECT%clmns.name%FROM%sys.all_views%sys.all_columns%sys.indexes%sys.index_columns%sys.computed_columns%sys.identity_columns%sys.objects%sys.types%sys.schemas%sys.types%''
        )
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] <> ''databases'' AND [Statement] LIKE 
        ''SELECT%dtb.name%AS%dtb.state%A%FROM%master.sys.databases%dtb''
        )
AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] <> ''databases'' AND [Statement] LIKE 
        ''%SELECT%clmns.column_id%,%clmns.name%,%clmns.is_nullable%,%CAST%ISNULL%FROM%sys.all_views%AS%v%INNER%JOIN%sys.all_columns%AS%clmns%ON%clmns.object_id%v.object_id%LEFT%OUTER%JOIN%sys.indexes%AS%ik%ON%ik.object_id%clmns.object_id%and%1%ik.is_primary_key%''
        )
 
--  Numerous log records are generated when the SQL Server Management Studio Log Viewer itself is 
--  populated or refreshed.  The following filters out the less useful of these, while not hiding the
--  fact that metadata about the log was accessed.
AND NOT ([Schema_Name] = ''sys'' AND [Statement] LIKE 
        ''SELECT%dtb.name AS%,%dtb.database_id AS%,%CAST(has_dbaccess(dtb.name) AS bit) AS%FROM%master.sys.databases AS dtb%ORDER BY%ASC''
        )
AND NOT ([Schema_Name] = ''sys'' AND [Statement] LIKE 
        ''SELECT%dtb.collation_name AS%,%dtb.name AS%FROM%master.sys.databases AS dtb%WHERE%''
        )

--  If activated, the following filters out system-generated statements, should they occur, accessing
--  additional SQL Server internal tables that are not directly visible to or accessible by user processes
--  (even by administrators).  Enable each line, as needed, to add it to the filter.
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysschobjs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysbinobjs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysclsobjs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysnsobjs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syscolpars'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''systypedsubobjs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysidxstats'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysiscols'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysscalartypes'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysdbreg'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxsrvs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysrmtlgns'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syslnklgns'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxlgns'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysdbfiles'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysusermsg'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysprivs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysowners'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysobjkeycrypts'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syscerts'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysasymkeys'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''ftinds'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxprops'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysallocunits'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysrowsets'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysrowsetrefs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syslogshippers'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysremsvcbinds'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysconvgroup'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxmitqueue'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysdesend'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysdercv'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysendpts'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syswebmethods'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysqnames'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxmlcomponent'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxmlfacet'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysxmlplacement'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''syssingleobjrefs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysmultiobjrefs'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysobjvalues'')
--  AND NOT ([Schema_Name] = ''sys'' AND [Object_Name] = ''sysguidrefs'')
;';
        EXEC sp_executesql @SqlCmd;
    END -- check audit exists

-- PART 2: specify Audit Action Groups and Actions
-- https://docs.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-action-groups-and-actions
    IF NOT EXISTS(SELECT 1 FROM sys.server_audit_specifications WHERE [name] = @OrganisationName + N'_STANDARD_AUDIT_SPECS')
    BEGIN
        SET @SqlCmd = N'USE [master];
CREATE SERVER AUDIT SPECIFICATION [' + @OrganisationName + N'_STANDARD_AUDIT_SPECS]
	FOR SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT]
	WITH (STATE = OFF);
';
        EXEC sp_executesql @SqlCmd;

/*
APPLICATION_ROLE_CHANGE_PASSWORD_GROUP      Raised whenever a password is changed for an application role.
AUDIT_CHANGE_GROUP                          Raised whenever any audit is created, modified or deleted.
BACKUP_RESTORE_GROUP                        Raised whenever a backup or restore command is issued.
DATABASE_CHANGE_GROUP                       Raised when a database is created, altered, or dropped.
DATABASE_OBJECT_CHANGE_GROUP                Raised when a CREATE, ALTER, or DROP statement is executed on database objects, such as schemas.
DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP      Raised when a change of owner for objects within database scope.
DATABASE_OBJECT_PERMISSION_CHANGE_GROUP     Raised when a GRANT, REVOKE, or DENY has been issued for database objects, such as assemblies and schemas.
DATABASE_OWNERSHIP_CHANGE_GROUP             Raised when you use the ALTER AUTHORIZATION statement to change the owner of a database, and the permissions that are required to do that are checked.
DATABASE_PERMISSION_CHANGE_GROUP            Raised whenever a GRANT, REVOKE, or DENY is issued for a statement permission by any principal in SQL Server (This applies to database-only events, such as granting permissions on a database). 
DATABASE_PRINCIPAL_CHANGE_GROUP             Raised when principals, such as users, are created, altered, or dropped from a database.
DATABASE_PRINCIPAL_IMPERSONATION_GROUP      Raised when there is an impersonation operation in the database scope such as EXECUTE AS <principal> or SETPRINCIPAL.
DATABASE_ROLE_MEMBER_CHANGE_GROUP           Raised whenever a login is added to or removed from a database role.
LOGIN_CHANGE_PASSWORD_GROUP                 Raised whenever a login password is changed by way of ALTER LOGIN statement or sp_password stored procedure.
SCHEMA_OBJECT_CHANGE_GROUP                  Raised when a CREATE, ALTER, or DROP operation is performed on a schema.
SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP        Raised when the permissions to change the owner of schema object (such as a table, procedure, or function) is checked. This occurs when the ALTER AUTHORIZATION statement is used to assign an owner to an object.
SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP       Raised whenever a grant, deny, revoke is performed against a schema object.
SERVER_OBJECT_CHANGE_GROUP                  Raised for CREATE, ALTER, or DROP operations on server objects.
SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP        Raised when the owner is changed for objects in server scope.
SERVER_OBJECT_PERMISSION_CHANGE_GROUP       Raised whenever a GRANT, REVOKE, or DENY is issued for a server object permission by any principal in SQL Server.
SERVER_OPERATION_GROUP                      Raised when Security Audit operations such as altering settings, resources, external access, or authorization are used.
SERVER_PERMISSION_CHANGE_GROUP              Raised when a GRANT, REVOKE, or DENY is issued for permissions in the server scope, such as creating a login.
SERVER_PRINCIPAL_CHANGE_GROUP               Raised when server principals are created, altered, or dropped.
SERVER_PRINCIPAL_IMPERSONATION_GROUP        Raised when there is an impersonation within server scope, such as EXECUTE AS <login>.
SERVER_ROLE_MEMBER_CHANGE_GROUP             Raised whenever a login is added or removed from a fixed server role. Raised for the sp_addsrvrolemember and sp_dropsrvrolemember stored procedures.
SERVER_STATE_CHANGE_GROUP                   Raised when the SQL Server service state is modified.
TRACE_CHANGE_GROUP                          Raised for all statements that check for the ALTER TRACE permission.
USER_CHANGE_PASSWORD_GROUP                  Raised whenever the password of a contained database user is changed by using the ALTER USER statement.

-- NOTE: Explicitly excluded:
DATABASE_OBJECT_ACCESS_GROUP                Raised whenever database objects such as message type, assembly, contract are accessed. This could potentially lead to large audit records.
SCHEMA_OBJECT_ACCESS_GROUP                  Raised whenever an object permission has been used in the schema. This could potentially lead to large audit records.
*/
        SET @SqlCmd = N'USE [master];
ALTER SERVER AUDIT SPECIFICATION [' + @OrganisationName + N'_STANDARD_AUDIT_SPECS]
	ADD (APPLICATION_ROLE_CHANGE_PASSWORD_GROUP), ' +
N'	ADD (AUDIT_CHANGE_GROUP), ' +
N'	ADD (BACKUP_RESTORE_GROUP), ' +
N'	ADD (DATABASE_CHANGE_GROUP), ' +
--N'	ADD (DATABASE_OBJECT_ACCESS_GROUP), ' +
N'	ADD (DATABASE_OBJECT_CHANGE_GROUP), ' +
N'	ADD (DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP), ' +
N'	ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP), ' +
N'	ADD (DATABASE_OWNERSHIP_CHANGE_GROUP), ' +
N'	ADD (DATABASE_PERMISSION_CHANGE_GROUP), ' +
N'	ADD (DATABASE_PRINCIPAL_CHANGE_GROUP), ' +
N'	ADD (DATABASE_PRINCIPAL_IMPERSONATION_GROUP), ' +
N'	ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP), ' +
N'	ADD (LOGIN_CHANGE_PASSWORD_GROUP), ' +
--N'	ADD (SCHEMA_OBJECT_ACCESS_GROUP), ' +
N'	ADD (SCHEMA_OBJECT_CHANGE_GROUP), ' +
N'	ADD (SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP), ' +
N'	ADD (SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP), ' +
N'	ADD (SERVER_OBJECT_CHANGE_GROUP), ' +
N'	ADD (SERVER_OBJECT_OWNERSHIP_CHANGE_GROUP), ' +
N'	ADD (SERVER_OBJECT_PERMISSION_CHANGE_GROUP), ' +
N'	ADD (SERVER_OPERATION_GROUP), ' +
N'	ADD (SERVER_PERMISSION_CHANGE_GROUP), ' +
N'	ADD (SERVER_PRINCIPAL_CHANGE_GROUP), ' +
N'	ADD (SERVER_PRINCIPAL_IMPERSONATION_GROUP), ' +
N'	ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP), ' +
N'	ADD (SERVER_STATE_CHANGE_GROUP), ' +
N'	ADD (TRACE_CHANGE_GROUP), ' +
N'	ADD (USER_CHANGE_PASSWORD_GROUP) ' +
N';';
        EXEC sp_executesql @SqlCmd;
    END

    -- PART 3: enable audit
    IF (((SELECT TOP(1) 1 FROM sys.server_audit_specifications WHERE [name] = @OrganisationName + N'_STANDARD_AUDIT_SPECS') = 1) AND 
        ((SELECT TOP(1) 1 FROM sys.server_audit_specifications WHERE [name] = @OrganisationName + N'_STANDARD_AUDIT_SPECS' AND [is_state_enabled] = 0) = 1)
        )
    BEGIN
        SET @SqlCmd = N'USE [master];ALTER SERVER AUDIT SPECIFICATION [' + @OrganisationName + N'_STANDARD_AUDIT_SPECS] WITH (STATE = ON);';
        EXEC sp_executesql @SqlCmd;
    END
    
    IF (((SELECT 1 FROM sys.server_audits WHERE [name] = @OrganisationName + N'_STANDARD_AUDIT') = 1) AND 
        ((SELECT 1 FROM sys.server_audits WHERE [name] = @OrganisationName + N'_STANDARD_AUDIT' AND [is_state_enabled] = 0) = 1)
        )
    BEGIN
        SET @SqlCmd = N'USE [master];ALTER SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT] WITH (STATE = ON);';
        EXEC sp_executesql @SqlCmd;
    END
END
GO

/*
SAMPLE: Querying the Audit records
https://docs.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-records

Also: sys.fn_get_audit_file (Transact-SQL)
https://docs.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-get-audit-file-transact-sql
--------------------------------------------------
USE [master]
GO
SET NOCOUNT ON;
-- check if the OS is Windows or Linux
DECLARE @HostPlatform nvarchar(256); -- Windows or Linux
SET @HostPlatform = (SELECT TOP(1) host_platform FROM sys.dm_os_host_info);
DECLARE @FolderSeparator nchar(1); -- "\" or "/"
SET @FolderSeparator = CASE @HostPlatform WHEN 'Windows' THEN N'\' WHEN 'Linux' THEN N'/' END;

DECLARE @OrganisationName nvarchar(50);
DECLARE @AuditFolder nvarchar(128);

SET @OrganisationName = 'CONTOSO';
SET @AuditFolder = (
    SELECT SUBSTRING([physical_name], 1, CHARINDEX(@FolderSeparator + 'DATA' + @FolderSeparator + 'master.mdf', [physical_name])) + 'AUDIT' + @FolderSeparator + @OrganisationName + N'_STANDARD_AUDIT'
    FROM sys.master_files WHERE [database_id] = 1 AND [file_id] = 1
);

DECLARE @AuditFilePath nvarchar(4000);
SET @AuditFilePath = @AuditFolder + @FolderSeparator + N'*.sqlaudit';

SELECT 
    [event_time]
    ,[action_id]
    ,[session_server_principal_name]
    ,[server_instance_name]
    ,[database_name]
    ,[schema_name]
    ,[object_name]
    ,[application_name] -- only available from SQL Server 2017 and Azure SQL Database
    ,[client_ip]        -- only available from SQL Server 2017 and Azure SQL Database
    ,[statement]
FROM sys.fn_get_audit_file(@AuditFilePath, DEFAULT, DEFAULT)
WHERE 1=1
-- today
AND [event_time] BETWEEN CAST(CURRENT_TIMESTAMP AS date) AND CURRENT_TIMESTAMP
-- filter for Users
AND [server_principal_name] LIKE 'CONTOSO\U[0-9][0-9][0-9][0-9]%'
-- remove SSMS queries
AND [action_id] NOT IN ('VSST', 'VW')
ORDER BY [event_time] DESC, [sequence_number] ASC;
GO
*/

/*
USE [master]
GO
SET NOCOUNT ON;
-- check if the OS is Windows or Linux
DECLARE @HostPlatform nvarchar(256); -- Windows or Linux
SET @HostPlatform = (SELECT TOP(1) host_platform FROM sys.dm_os_host_info);
DECLARE @FolderSeparator nchar(1); -- "\" or "/"
SET @FolderSeparator = CASE @HostPlatform WHEN 'Windows' THEN N'\' WHEN 'Linux' THEN N'/' END;

DECLARE @OrganisationName nvarchar(50);
DECLARE @SqlCmd nvarchar(max);
DECLARE @AuditFolder nvarchar(128);

SET @OrganisationName = 'CONTOSO';

-- disable the Server AUdit
SET @SqlCmd = N'USE [master];ALTER SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT] WITH (STATE = OFF);';
PRINT @SqlCmd;
EXEC sp_executesql @SqlCmd;

SET @AuditFolder = (
    SELECT SUBSTRING([physical_name], 1, CHARINDEX(@FolderSeparator + 'DATA' + @FolderSeparator + 'master.mdf', [physical_name])) + 'AUDIT' + @FolderSeparator + @OrganisationName + N'_STANDARD_AUDIT'
    FROM sys.master_files WHERE [database_id] = 1 AND [file_id] = 1
);

IF @HostPlatform = 'Windows'
    EXEC dbo.xp_create_subdir @AuditFolder;

-- modify the Server Audit property/properties
SET @SqlCmd = N'USE [master]; ALTER SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT] TO FILE ( FILEPATH = ''' + @AuditFolder + N''' );';
PRINT @SqlCmd;
EXEC sp_executesql @SqlCmd;

-- enable the Server AUdit
SET @SqlCmd = N'USE [master];ALTER SERVER AUDIT [' + @OrganisationName + N'_STANDARD_AUDIT] WITH (STATE = OFF);';
PRINT @SqlCmd;
EXEC sp_executesql @SqlCmd;
GO
*/