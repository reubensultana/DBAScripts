USE [master]
GO
CREATE TABLE [dbo].[sqlfirewall_allowlist] (
	[sfw_pk] int IDENTITY(1,1) NOT NULL,
	[sfw_net_address] varchar(48) NOT NULL,
	[sfw_status] char(1) NOT NULL
)
GO

-- clustered index on [sfw_pk]
IF NOT EXISTS (SELECT 1 FROM [sys].[indexes] WHERE [object_id] = OBJECT_ID(N'[dbo].[sqlfirewall_allowlist]') AND [name] = N'PK_SQLFirewallallowlist')
ALTER TABLE [dbo].[sqlfirewall_allowlist]
ADD  CONSTRAINT [PK_SQLFirewallallowlist] PRIMARY KEY CLUSTERED ([sfw_pk] ASC)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF, ONLINE = OFF,
    ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100)
GO

-- unique constraint on [sfw_net_address]
IF NOT EXISTS (SELECT 1 FROM [sys].[indexes] WHERE [object_id] = OBJECT_ID(N'[dbo].[sqlfirewall_allowlist]') AND [name] = N'IX_SQLfirewallallowlist_NetAddress')
CREATE UNIQUE NONCLUSTERED INDEX [IX_SQLfirewallallowlist_NetAddress]
ON [dbo].[sqlfirewall_allowlist] ([sfw_net_address] ASC)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = ON, DROP_EXISTING = OFF, ONLINE = OFF,
    ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90)
GO

-- default constraint on [sfw_status] = "A"
ALTER TABLE [dbo].[sqlfirewall_allowlist] ADD CONSTRAINT [DF_SQLfirewallallowlist_Status] DEFAULT 'A' FOR [sfw_status]
GO
-- check constraint on [sfw_status] - allowed values "A", "D", "H"
ALTER TABLE [dbo].[sqlfirewall_allowlist] ADD CONSTRAINT [CK_SQLfirewallallowlist_Status] CHECK ([sfw_status] LIKE '[ADH]')
GO


-- default data
USE [master]
GO
SET NOCOUNT ON;
INSERT INTO [dbo].[sqlfirewall_allowlist] ([sfw_net_address], [sfw_status])
VALUES('<local machine>', 'A'),	-- allow local connections
      ('127.0.0.1',   'A'),		-- allow local connections
	  ('10.20.30.40', 'A'),	    -- allow connections from 10.20.30.40
	  ('10.20.30.41', 'A');		-- allow connections from 10.20.30.41
GO


USE [master];
GO
ALTER TRIGGER [sqlfirewall_allowlist_trigger]
ON ALL SERVER --WITH EXECUTE AS 'sa'
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
		-- check if connections from this IP Address are allowed
        IF NOT EXISTS (
            SELECT * FROM [sys].[dm_exec_connections] ec
                INNER JOIN [dbo].[sqlfirewall_allowlist] sfw ON ec.[client_net_address] = sfw.[sfw_net_address]
			WHERE sfw.[sfw_status] = 'A' AND ec.[session_id] = @@SPID
        )
        BEGIN
            -- log the failure
            SET @LoginName = COALESCE(ORIGINAL_LOGIN(), SYSTEM_USER, '');
            SET @SourceNetAddress = (SELECT DISTINCT [client_net_address] FROM [sys].[dm_exec_connections] WHERE [session_id] = @@SPID);
            SET @Message = 'Failed connection attempt from ' + COALESCE(@SourceNetAddress, HOST_NAME(), '') + ' by ' + @LoginName;
            EXEC [master]..[xp_logevent] 60000, @Message, informational;
            -- notify the caller
            RAISERROR('Connection from the source machine is not allowed. Kindly contact the DBA Team to obtain access.', 16, 1);
            ROLLBACK;
        END
		ELSE
		BEGIN
			-- log the failure
            SET @LoginName = ORIGINAL_LOGIN();
            SET @SourceNetAddress = (SELECT [client_net_address] FROM [sys].[dm_exec_connections] WHERE [session_id] = @@SPID);
            SET @Message = 'Successful connection from ' + @SourceNetAddress + ' by ' + @LoginName;
            EXEC [master]..[xp_logevent] 60000, @Message, informational;
		END
    END
END;
GO

ENABLE TRIGGER sqlfirewall_allowlist_trigger ON ALL SERVER
GO


-- TEST
/*
UPDATE [dbo].[sqlfirewall_allowlist] SET [sfw_status] = 'D' WHERE [sfw_net_address] = '10.20.30.41';
GO
*/

