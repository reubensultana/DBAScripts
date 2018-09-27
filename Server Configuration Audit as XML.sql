USE [master]
GO

SET NOCOUNT ON;

SELECT 
    UPPER(ISNULL(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)))) AS [server_name],
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS [product_version],
    CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS [engine_edition],
    CAST(SERVERPROPERTY('Collation') AS nvarchar(128)) AS [collation],
    CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(128)) AS [host_machinename],
    CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(128)) AS [default_datapath],
    CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS nvarchar(128)) AS [default_logpath],
    CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS bit) AS [is_integratedsecurityonly],
    CAST(SERVERPROPERTY('IsFullTextInstalled') AS bit) AS [is_fulltextinstalled],
    CAST(SERVERPROPERTY('IsClustered') AS bit) AS [is_clustered],
    CAST(SERVERPROPERTY('BuildClrVersion') AS nvarchar(128)) AS [build_clrversion], 
    -- NOTE: See "CAST and CONVERT (Transact-SQL)" document at https://docs.microsoft.com/en-us/sql/t-sql/functions/cast-and-convert-transact-sql#xml-styles
    -- sys configurations
    CONVERT(xml, (
        SELECT * FROM sys.configurations
        ORDER BY configuration_id ASC
        FOR XML PATH, ROOT('configurations'), ELEMENTS XSINIL
    ), 2),
    -- databases
    CONVERT(xml, (
        SELECT * FROM sys.databases
        ORDER BY database_id ASC
        FOR XML PATH, ROOT('databases'), ELEMENTS XSINIL
    ), 2),
    -- database files
    CONVERT(xml, (
        SELECT * FROM sys.master_files
        ORDER BY database_id, file_id
        FOR XML PATH, ROOT('database_files'), ELEMENTS XSINIL
    ), 2),
    -- server_principals
    CONVERT(xml, (
        SELECT * FROM sys.server_principals
        ORDER BY type ASC, principal_id ASC
        FOR XML PATH, ROOT('server_principals'), ELEMENTS XSINIL
    ), 2),
    -- credentials
    CONVERT(xml, (
        SELECT * FROM sys.credentials
        ORDER BY credential_id
        FOR XML PATH, ROOT('credentials'), ELEMENTS XSINIL
    ), 2),
    -- audits
    CONVERT(xml, (
        SELECT * FROM sys.server_audits
        ORDER BY audit_id
        FOR XML PATH, ROOT('audits'), ELEMENTS XSINIL
    ), 2),
    -- audit specifications
    CONVERT(xml, (
        SELECT * FROM sys.server_audit_specifications
        ORDER BY server_specification_id
        FOR XML PATH, ROOT('audit_specifications'), ELEMENTS XSINIL
    ), 2),
    -- audit specification details
    CONVERT(xml, (
        SELECT * FROM sys.server_audit_specification_details
        ORDER BY server_specification_id
        FOR XML PATH, ROOT('audit_specification_details'), ELEMENTS XSINIL
    ), 2),
    -- mail profiles
    CONVERT(xml, (
        SELECT * FROM msdb.dbo.sysmail_profile 
        ORDER BY profile_id ASC
        FOR XML PATH, ROOT('sysmail_profile'), ELEMENTS XSINIL
    ), 2),
    -- mail accounts
    CONVERT(xml, (
        SELECT * FROM msdb.dbo.sysmail_account 
        ORDER BY account_id ASC
        FOR XML PATH, ROOT('sysmail_account'), ELEMENTS XSINIL
    ), 2),
    -- jobs
    CONVERT(xml, (
        SELECT * FROM msdb.dbo.sysjobs
        ORDER BY job_id ASC
        FOR XML PATH, ROOT('sysjobs'), ELEMENTS XSINIL
    ), 2),
    -- job steps
    CONVERT(xml, (
        SELECT * FROM msdb.dbo.sysjobsteps
        ORDER BY job_id ASC, step_id ASC
        FOR XML PATH, ROOT('sysjobsteps'), ELEMENTS XSINIL
    ), 2),
    -- operators
    CONVERT(xml, (
        SELECT * FROM msdb.dbo.sysoperators
        ORDER BY id ASC
        FOR XML PATH, ROOT('operators'), ELEMENTS XSINIL
    ), 2),
    -- alerts
    CONVERT(xml, (
        SELECT * FROM msdb.dbo.sysalerts
        ORDER BY id ASC
        FOR XML PATH, ROOT('alerts'), ELEMENTS XSINIL
    ), 2),
    -- endpoints
    CONVERT(xml, (
        SELECT * FROM sys.endpoints WHERE endpoint_id > 5
        ORDER BY endpoint_id
        FOR XML PATH, ROOT('endpoints'), ELEMENTS XSINIL
    ), 2),
    -- linked servers
    CONVERT(xml, (
        SELECT * FROM sys.servers WHERE server_id > 0
        ORDER BY server_id
        FOR XML PATH, ROOT('servers'), ELEMENTS XSINIL
    ), 2),
    -- availability_databases_cluster
    CONVERT(xml, (
        SELECT * FROM sys.availability_databases_cluster
        ORDER BY group_id
        FOR XML PATH, ROOT('availability_databases_cluster'), ELEMENTS XSINIL
    ), 2),
    -- availability_group_listener_ip_addresses
    CONVERT(xml, (
        SELECT * FROM sys.availability_group_listener_ip_addresses
        ORDER BY listener_id ASC
        FOR XML PATH, ROOT('availability_group_listener_ip_addresses'), ELEMENTS XSINIL
    ), 2),
    -- availability_group_listeners
    CONVERT(xml, (
        SELECT * FROM sys.availability_group_listeners
        ORDER BY group_id
        FOR XML PATH, ROOT('availability_group_listeners'), ELEMENTS XSINIL
    ), 2),
    -- availability_groups
    CONVERT(xml, (
        SELECT * FROM sys.availability_groups
        ORDER BY group_id ASC
        FOR XML PATH, ROOT('availability_groups'), ELEMENTS XSINIL
    ), 2),
    -- availability_groups_cluster
    CONVERT(xml, (
        SELECT * FROM sys.availability_groups_cluster
        ORDER BY group_id ASC
        FOR XML PATH, ROOT('availability_groups_cluster'), ELEMENTS XSINIL
    ), 2),
    -- availability_read_only_routing_lists
    CONVERT(xml, (
        SELECT * FROM sys.availability_read_only_routing_lists
        ORDER BY replica_id
        FOR XML PATH, ROOT('availability_read_only_routing_lists'), ELEMENTS XSINIL
    ), 2),
    -- availability_replicas
    CONVERT(xml, (
        SELECT * FROM sys.availability_replicas
        ORDER BY replica_id ASC
        FOR XML PATH, ROOT('availability_replicas'), ELEMENTS XSINIL
    ), 2),

    -- when this audit was run
    CURRENT_TIMESTAMP AS [current_timestamp]

FOR XML PATH('server'), ROOT('serverinfo'), ELEMENTS XSINIL;
