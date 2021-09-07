/* Source: https://github.com/reubensultana/DBAScripts/blob/master/DatabaseMail/Configure-DatabaseMail.sql */

USE [master]
GO
SET NOCOUNT ON;

-- Database Mail Profile variables
DECLARE @DBMailProfileName nvarchar(128);
DECLARE @DBMailProfileDesc nvarchar(256);

-- Database Mail Account variables
DECLARE @AccountName nvarchar(128);     -- the "From" account name when email is sent from the default profile
DECLARE @AccountEmail nvarchar(128);    -- the "From" email address when email is sent from the default profile
DECLARE @MailServer nvarchar(128);      -- the Company mail server DNS alias
DECLARE @MailServerPort int;            -- the Company mail server TCP Port
DECLARE @SendTestEmail bit;             -- send a test email or not on creation of the Mail Profile

DECLARE @InstanceName nvarchar(128);
SET @InstanceName = UPPER(ISNULL(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS nvarchar(128))));

SET @DBMailProfileName = 'SQL Server Email Notifications - ' + @InstanceName;
SET @DBMailProfileDesc = 'Email notification service for SQL Server ' + @InstanceName;

SET @AccountName = 'DBA Team';
SET @AccountEmail = 'dba.team@mycompany.com';
SET @MailServer = 'mailserver.mycompany.com';
SET @MailServerPort = 25;
SET @SendTestEmail = 0;

DECLARE @SqlCmd nvarchar(4000);

-- check if Service Broker is enabled on the MSDB database and prompt user
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE [name] = 'msdb' AND [is_broker_enabled] = 1)
BEGIN
    SET @SqlCmd = 'USE [master];ALTER DATABASE [msdb] SET ENABLE_BROKER;';
    EXEC sp_executesql @SqlCmd;
END

-- check if the 'Database Mail XPs' configuration option is enabled and enable if not
IF NOT EXISTS(SELECT 1 FROM sys.configurations WHERE [name] = 'Database Mail XPs' AND [value] = 1)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.configurations WHERE [name] = 'show advanced options' AND [value] = 1)
    BEGIN
        EXEC sp_configure 'show advanced options', 1;
        RECONFIGURE WITH OVERRIDE;
    END
    EXEC sp_configure 'Database Mail XPs', 1;
    RECONFIGURE WITH OVERRIDE;
END

-- Create a Database Mail profile
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysmail_profile WHERE [name] = @DBMailProfileName AND [description] = @DBMailProfileDesc)
BEGIN
    EXECUTE [msdb].[dbo].sysmail_add_profile_sp
        @profile_name = @DBMailProfileName,
        @description = @DBMailProfileDesc;
END

-- Create a Database Mail account
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.sysmail_account WHERE [name] = @AccountName AND [description] = @AccountName AND [email_address] = @AccountEmail)
BEGIN
    EXECUTE [msdb].[dbo].sysmail_add_account_sp
        @account_name = @AccountName,
        @description = @AccountName,
        @email_address = @AccountEmail,
        @replyto_address = @AccountEmail,
        @display_name = @DBMailProfileName,
        @mailserver_name = @MailServer,
        @port = @MailServerPort;
END

-- Add the account to the profile
IF NOT EXISTS(
    SELECT * FROM [msdb].[dbo].sysmail_profileaccount pa
        INNER JOIN [msdb].[dbo].sysmail_profile p ON pa.profile_id = p.profile_id
        INNER JOIN [msdb].[dbo].sysmail_account a ON pa.account_id = a.account_id
    WHERE p.name = @DBMailProfileName AND a.name = @AccountName)
BEGIN
    EXECUTE [msdb].[dbo].sysmail_add_profileaccount_sp
        @profile_name = @DBMailProfileName,
        @account_name = @AccountName,
        @sequence_number =1;
END

-- Grant access to the profile to the DBMailUsers role
IF NOT EXISTS(
    SELECT * FROM [msdb].[dbo].sysmail_principalprofile pp
        INNER JOIN [msdb].[dbo].sysmail_profile p ON pp.profile_id = p.profile_id
    WHERE p.[name] = @DBMailProfileName AND pp.[is_default] = 1)
BEGIN
    EXECUTE [msdb].[dbo].sysmail_add_principalprofile_sp
        @profile_name = @DBMailProfileName,
        @principal_id = 0,
        @is_default = 1;
END

/*
SELECT * FROM msdb.dbo.sysmail_profile
SELECT * FROM msdb.dbo.sysmail_account
*/

-- Send test email notification
IF (@SendTestEmail = 1)
BEGIN
    DECLARE @TestMailSubject nvarchar(128);
    DECLARE @TestMailMessage nvarchar(2000);
    SET @TestMailSubject = 'Testing a Database Mail Profile from ' + @InstanceName;
    SET @TestMailMessage = @DBMailProfileDesc + N'
    This is a test email sent from ' + @InstanceName + N' using Database Mail';

    EXEC [msdb].[dbo].sp_send_dbmail 
        @profile_name = @DBMailProfileName,
        @recipients = @AccountEmail,
        @subject = @TestMailSubject,
        @body = @TestMailMessage,
        @body_format = 'TEXT';
END
GO
