SET NOCOUNT ON;

SELECT 
    UPPER(COALESCE(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)), '')) AS [server_name],
    CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(128)) AS [host_machinename],
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS [product_version],
    CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS [engine_edition],
    CAST(SERVERPROPERTY('Collation') AS nvarchar(128)) AS [collation],
    CONVERT(nvarchar(128), SERVERPROPERTY('SqlCharSetName')) AS SqlCharSetName, 
    CONVERT(nvarchar(128), SERVERPROPERTY('SqlSortOrderName')) AS SqlSortOrderName,
    CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(128)) AS [default_datapath],
    CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS nvarchar(128)) AS [default_logpath],
    CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS bit) AS [is_integratedsecurityonly],
    CAST(SERVERPROPERTY('IsFullTextInstalled') AS bit) AS [is_fulltextinstalled],
    CAST(SERVERPROPERTY('IsClustered') AS bit) AS [is_clustered],
    CAST(SERVERPROPERTY('BuildClrVersion') AS nvarchar(128)) AS [build_clrversion], 
    CASE CONVERT(int, SERVERPROPERTY('IsIntegratedSecurityOnly'))
        WHEN 0 THEN 'SQL Server and Windows' 
        WHEN 1 THEN 'Windows only'
        ELSE 'Error'
    END AS [server_authentication], 
    CONVERT(datetime, SERVERPROPERTY('ResourceLastUpdateDateTime')) AS [resource_last_update_datetime], 
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

    -- when this audit was run
    CURRENT_TIMESTAMP AS [current_timestamp]

FOR XML PATH('server'), ROOT('serverinfo'), ELEMENTS XSINIL;
