/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/sql_firewall.sql */

USE [master]
GO
-- check and notify
IF EXISTS (SELECT * FROM sys.tables WHERE [name] = N'sqlfirewall_allowlist')
BEGIN
    RAISERROR('Base table already exists', 16, 1)
    RETURN
END

CREATE TABLE [dbo].[sqlfirewall_allowlist] (
	[al_pk] int IDENTITY(1,1) NOT NULL,
    [al_loginname] nvarchar(128) NOT NULL,
	[al_net_address] varchar(48) NOT NULL,
    [al_date_created] datetime NOT NULL,
    [al_created_by] nvarchar(128) NOT NULL
)
GO

-- clustered index on [al_pk]
IF NOT EXISTS (SELECT 1 FROM [sys].[indexes] WHERE [object_id] = OBJECT_ID(N'[dbo].[sqlfirewall_allowlist]') AND [name] = N'PK_SQLFirewallAllowList')
ALTER TABLE [dbo].[sqlfirewall_allowlist]
ADD CONSTRAINT [PK_SQLFirewallallowlist] PRIMARY KEY CLUSTERED ([al_pk] ASC)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, ONLINE = OFF,
    ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100)
GO

-- unique constraint on [al_loginname] and [al_net_address]
IF NOT EXISTS (SELECT 1 FROM [sys].[indexes] WHERE [object_id] = OBJECT_ID(N'[dbo].[sqlfirewall_allowlist]') AND [name] = N'IX_SQLfirewallAllowList_LoginNetAddress')
CREATE UNIQUE NONCLUSTERED INDEX [IX_SQLfirewallallowlist_NetAddress]
ON [dbo].[sqlfirewall_allowlist] ([al_loginname] ASC, [al_net_address] ASC)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, DROP_EXISTING = OFF, ONLINE = OFF,
    ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90)
GO

-- default constraint on [al_date_created] = CURRENT_TIMESTAMP
ALTER TABLE [dbo].[sqlfirewall_allowlist] ADD CONSTRAINT [DF_SQLfirewallallowlist_DateCreated] DEFAULT (CURRENT_TIMESTAMP) FOR [al_date_created]
GO
-- default constraint on [al_created_by] = COALESCE(ORIGINAL_LOGIN(), SYSTEM_USER, '')
ALTER TABLE [dbo].[sqlfirewall_allowlist] ADD CONSTRAINT [DF_SQLfirewallallowlist_CreatedBy] DEFAULT (COALESCE(ORIGINAL_LOGIN(), SYSTEM_USER, 'UNKNOWN')) FOR [al_created_by]
GO

-- permissions (important!)
GRANT SELECT ON [dbo].[sqlfirewall_allowlist] TO [public]
GO


-- create and enable the trigger
USE [master];
GO
IF EXISTS (SELECT * FROM sys.server_triggers WHERE [name] = N'sqlfirewall_allowlist_trigger')
    DROP TRIGGER [sqlfirewall_allowlist_trigger] ON ALL SERVER
GO

CREATE TRIGGER [sqlfirewall_allowlist_trigger]
ON ALL SERVER
FOR LOGON
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE @LoginName nvarchar(128);
    DECLARE @SourceNetAddress varchar(48);
    DECLARE @Message varchar(255);

    -- run checks for non-sysadmins only
    IF (IS_SRVROLEMEMBER(N'sysadmin') != 1)
    BEGIN
		-- check if connections for this Login are allowed
        SET @LoginName = COALESCE(ORIGINAL_LOGIN(), SYSTEM_USER, N'');
        IF EXISTS ( SELECT * FROM [dbo].[sqlfirewall_allowlist] WHERE [al_loginname] = @LoginName )
        BEGIN
            -- get IP address for the Client initiating the current connection
            --SET @SourceNetAddress = ( SELECT DISTINCT [client_net_address] FROM [sys].[dm_exec_connections] WHERE [session_id] = @@SPID);
            -- replaced by https://docs.microsoft.com/en-us/sql/relational-databases/triggers/capture-logon-trigger-event-data
            SET @SourceNetAddress = COALESCE( ( SELECT EVENTDATA().value('(/EVENT_INSTANCE/ClientHost/CommandText)[1]','varchar(48)') ), HOST_NAME(), '');
            IF NOT EXISTS ( SELECT * FROM [dbo].[sqlfirewall_allowlist] WHERE [al_net_address] = @SourceNetAddress )
            BEGIN
                -- log a message in the ERORLOG that the connection attempt was denied
                SET @Message = 'Failed connection attempt for ' + @LoginName + ' from ' + @SourceNetAddress;
                RAISERROR(@Message, 1, 1);
                ROLLBACK;
            END
        END
    END
END;
GO

ENABLE TRIGGER [sqlfirewall_allowlist_trigger] ON ALL SERVER
GO


-- default data
USE [master]
GO
SET NOCOUNT ON;
INSERT INTO [dbo].[sqlfirewall_allowlist] ([al_loginname], [al_net_address])
VALUES('SQLTest1', '<local machine>'),	-- allow local connections
      ('SQLTest1', '127.0.0.1'),		-- allow local connections
	  ('SQLTest1', '10.20.30.40'),	    -- allow connections from 10.20.30.40
	  ('SQLTest1', '10.20.30.41');		-- allow connections from 10.20.30.41
-- NOTE: any other connections for 'SQLTest1' will be denied
GO
