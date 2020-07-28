USE [master]
GO

CREATE DATABASE [SampleDatabase]
GO

USE [SampleDatabase]
GO

-- remove solution objects if present
IF EXISTS (SELECT * FROM sys.triggers WHERE parent_class_desc = 'DATABASE' AND name = N'ddl_databaselog')
BEGIN
    DISABLE TRIGGER [ddl_databaselog] ON DATABASE
    DROP TRIGGER [ddl_databaselog] ON DATABASE
END
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.tb_databaselog') AND type in (N'U'))
    DROP TABLE dbo.tb_databaselog
GO

-- log table
CREATE TABLE dbo.tb_databaselog (
	log_pk          int IDENTITY(1,1) NOT NULL,
	log_eventtype   nvarchar(128),
	log_eventtime   datetime NOT NULL,
	log_dbuser      nvarchar(128),
	log_hostname    nvarchar(128),
	log_ipaddress   varchar(48),
	log_application nvarchar(128),
	log_schema      nvarchar(128),
	log_object      nvarchar(128),
	log_tsql        nvarchar(max),
	log_xmlevent    xml NOT NULL,
CONSTRAINT pk_databaselog_logid PRIMARY KEY CLUSTERED ( log_pk ASC )
    WITH (IGNORE_DUP_KEY = OFF) ON [OTHER_TABLES]
) ON [OTHER_TABLES]
GO

-- THE trigger
CREATE TRIGGER ddl_databaselog
ON DATABASE 
FOR DDL_DATABASE_LEVEL_EVENTS 
AS 
SET NOCOUNT ON;
BEGIN
    DECLARE @xmlevent       xml = EVENTDATA();
    DECLARE @eventtype      nvarchar(128) = @xmlevent.value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(128)');
	DECLARE @eventtime      datetime = CURRENT_TIMESTAMP;
	DECLARE @dbuser         nvarchar(128) = CONVERT(nvarchar(128), SYSTEM_USER);
	DECLARE @hostname       nvarchar(128) = (
	    SELECT [host_name] FROM sys.dm_exec_sessions WHERE [session_id] = @@SPID );
	DECLARE @ipaddress      varchar(48) = ( -- NOTE: Requires VIEW SERVER STATE permission on the server.
        SELECT [client_net_address] FROM sys.dm_exec_connections WHERE [session_id] = @@SPID ); 
	DECLARE @application    nvarchar(128) = (
	    SELECT [program_name] FROM sys.dm_exec_sessions WHERE [session_id] = @@SPID );
	DECLARE @schema         nvarchar(128) = @xmlevent.value('(/EVENT_INSTANCE/SchemaName)[1]', 'nvarchar(128)');
	DECLARE @object         nvarchar(128) = @xmlevent.value('(/EVENT_INSTANCE/ObjectName)[1]', 'nvarchar(128)');
	DECLARE @tsql           nvarchar(max) = @xmlevent.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'nvarchar(max)');

    SET @schema = ISNULL(@schema, '')
    SET @object = ISNULL(@object, '')

    IF (@schema NOT IN (N'INFORMATION_SCHEMA', N'sys'))
    BEGIN
        INSERT dbo.tb_databaselog (
            log_eventtype, log_eventtime, log_dbuser, log_hostname, log_ipaddress,
	        log_application, log_schema, log_object, log_tsql, log_xmlevent
            ) 
        VALUES (
            @eventtype, @eventtime, @dbuser, @hostname, @ipaddress,
	        @application, @schema, @object, @tsql, @xmlevent );
    END
END;

GO
