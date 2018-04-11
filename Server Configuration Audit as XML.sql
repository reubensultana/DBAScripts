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
    -- sys configurations
    CAST((
        SELECT * FROM sys.configurations
        ORDER BY configuration_id ASC
        FOR XML PATH, ROOT('configurations'), ELEMENTS XSINIL
    ) AS xml),
    -- databases
    CAST((
        SELECT * FROM sys.databases
        ORDER BY database_id ASC
        FOR XML PATH, ROOT('databases'), ELEMENTS XSINIL
    ) AS xml),
    -- database files
    CAST((
        SELECT * FROM sys.master_files
        ORDER BY database_id, file_id
        FOR XML PATH, ROOT('database_files'), ELEMENTS XSINIL
    ) AS xml),
    -- server_principals
    CAST((
        SELECT * FROM sys.server_principals
        ORDER BY type ASC, principal_id ASC
        FOR XML PATH, ROOT('server_principals'), ELEMENTS XSINIL
    ) AS xml),
    -- credentials
    CAST((
        SELECT * FROM sys.credentials
        ORDER BY credential_id
        FOR XML PATH, ROOT('credentials'), ELEMENTS XSINIL
    ) AS xml),
    -- audits
    CAST((
        SELECT * FROM sys.server_audits
        ORDER BY audit_id
        FOR XML PATH, ROOT('audits'), ELEMENTS XSINIL
    ) AS xml),
    -- audit specifications
    CAST((
        SELECT * FROM sys.server_audit_specifications
        ORDER BY server_specification_id
        FOR XML PATH, ROOT('audit_specifications'), ELEMENTS XSINIL
    ) AS xml),
    -- audit specification details
    CAST((
        SELECT * FROM sys.server_audit_specification_details
        ORDER BY server_specification_id
        FOR XML PATH, ROOT('audit_specification_details'), ELEMENTS XSINIL
    ) AS xml),
    -- mail profiles
    CAST((
        SELECT * FROM msdb.dbo.sysmail_profile 
        ORDER BY profile_id ASC
        FOR XML PATH, ROOT('sysmail_profile'), ELEMENTS XSINIL
    ) AS xml),
    -- mail accounts
    CAST((
        SELECT * FROM msdb.dbo.sysmail_account 
        ORDER BY account_id ASC
        FOR XML PATH, ROOT('sysmail_account'), ELEMENTS XSINIL
    ) AS xml),
    -- jobs
    CAST((
        SELECT * FROM msdb.dbo.sysjobs
        ORDER BY job_id ASC
        FOR XML PATH, ROOT('sysjobs'), ELEMENTS XSINIL
    ) AS xml),
    -- job steps
    CAST((
        SELECT * FROM msdb.dbo.sysjobsteps
        ORDER BY job_id ASC, step_id ASC
        FOR XML PATH, ROOT('sysjobsteps'), ELEMENTS XSINIL
    ) AS xml),
    -- operators
    CAST((
        SELECT * FROM msdb.dbo.sysoperators
        ORDER BY id ASC
        FOR XML PATH, ROOT('operators'), ELEMENTS XSINIL
    ) AS xml),
    -- alerts
    CAST((
        SELECT * FROM msdb.dbo.sysalerts
        ORDER BY id ASC
        FOR XML PATH, ROOT('alerts'), ELEMENTS XSINIL
    ) AS xml),
    -- endpoints
    CAST((
        SELECT * FROM sys.endpoints WHERE endpoint_id > 5
        ORDER BY endpoint_id
        FOR XML PATH, ROOT('endpoints'), ELEMENTS XSINIL
    ) AS xml),
    -- linked servers
    CAST((
        SELECT * FROM sys.servers WHERE server_id > 0
        ORDER BY server_id
        FOR XML PATH, ROOT('servers'), ELEMENTS XSINIL
    ) AS xml),
    
    -- when this audit was run
    CURRENT_TIMESTAMP AS [current_timestamp]

FOR XML PATH('server'), ROOT('serverinfo'), ELEMENTS XSINIL
