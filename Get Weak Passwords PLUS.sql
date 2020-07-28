/*	check_weak_passwords.sql

	Description:	Check master.dbo.syslogins for weak passwords.
	Criteras:		Weak passwords are when password is:
						NULL
						<same as login>
						<login reversed>
						<one char>
*/
USE [master]
GO

set nocount on

declare @advancedmode bit;
declare @dbname nvarchar(128);
declare @loginname nvarchar(128);

declare @databases nvarchar(4000);
declare @apps varchar(8000);
declare @apps2 varchar(8000);
declare @SQLcmd nvarchar(4000);

DECLARE @AppName varchar(128);
DECLARE @ParmDefinition nvarchar(500);

set @advancedmode = 0;

create table #name (
		[name]		nvarchar(128) COLLATE DATABASE_DEFAULT not null,
        [databases] nvarchar(4000) COLLATE DATABASE_DEFAULT,
        [apps]      varchar(8000) COLLATE DATABASE_DEFAULT,
		[weak]		bit null,
		[null]		bit null,
		[same]		bit null,
		[reverse]	bit null,
		[onechar]	bit null )

-- get all logins that are not nt-logins
insert into #name (
		[name],
        [databases],
        [apps],
		[weak],
		[null],
		[same],
		[reverse],
		[onechar] )
select	[name],
        '',
        '',
		0,
		0,
		0,
		0,
		0
from	master.dbo.syslogins
where	isntname = 0
and     [name] NOT LIKE '##MS%'; -- exclude Microsoft accounts


-- check if password is null
update	n
set		[weak] = 1,
		[null] = 1
from	#name n,
		master.dbo.syslogins sl
where	n.[name] = sl.[name] and
		sl.[password] is null;

-- check if name is same as login
update	n
set		[weak] = 1,
		[same] = 1
from	#name n,
		master.dbo.syslogins sl
where	n.[name] = sl.[name] and
		pwdcompare(sl.[name], sl.[password]) = 1;

-- check if password is reversed
update	n
set		[weak] = 1,
		[reverse] = 1
from	#name n,
		master.dbo.syslogins sl
where	n.[name] = sl.[name] and
		pwdcompare(reverse(sl.[name]), sl.[password]) = 1;

-- check if password is one char long
if (@advancedmode = 1)
begin
    declare	@char	int,
		    @name	sysname
    select	@char = 0
    declare	MyC cursor for
		    select	[name]
		    from	#name
		    order by
				    [name]
    open MyC
    fetch next from MyC into @name
    while @@fetch_status >= 0
    begin
	    while @char < 256
	    begin
		    if ( select pwdcompare(char(@char), [password]) from master.dbo.syslogins where name = @name ) = 1
		    begin
			    update	#name
			    set		[weak] = 1,
					    [onechar] = 1
			    where	[name] = @name
		    end
		    select	@char = @char + 1
	    end
	    select @char = 0
	    fetch next from MyC into @name
    end
    close MyC
    deallocate MyC
end

-- find which of the databases each login can access
declare	curDatabases cursor for
    SELECT [name] from master.dbo.sysdatabases 
    WHERE [name] NOT IN ('db_dba', 'master', 'msdb', 'model', 'tempdb')
    AND [name] NOT LIKE 'AdventureWorks%'
    AND [name] NOT LIKE 'ReportServer%'
    AND [cmptlevel] >= 80
    AND (
        CAST(DATABASEPROPERTY([name], 'IsReadOnly') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsOffline') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsSuspect') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsShutDown') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsNotRecovered') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsInStandBy') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsInRecovery') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsInLoad') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsEmergencyMode') AS smallint) + 
	    CAST(DATABASEPROPERTY([name], 'IsDetached') AS smallint) = 0
        )
    ORDER BY [name] DESC;
open curDatabases
fetch next from curDatabases into @dbname
while (@@fetch_status >= 0)
begin
    -- get application name
    SET @ParmDefinition = N'@AppNameOUT varchar(128) OUTPUT';

    SET @SQLcmd = N'';
    SET @SQLcmd = @SQLcmd + N'USE ' + QUOTENAME(@dbname, '[') + ';
SELECT @AppNameOUT = COALESCE(CONVERT(nvarchar(1000), value), '''')
FROM ::fn_listextendedproperty(''Application Name'', default, default, default, default, default, default);';
    
    EXEC sp_executesql @SQLcmd, @ParmDefinition, @AppNameOUT = @AppName OUTPUT;


    -- check which logins have access to the current database
    -- update database name and application name
    SET @SQLcmd = N'';
    SET @SQLcmd = @SQLcmd + N'USE ' + QUOTENAME(@dbname, '[') + ';
update	n
set		[databases] = '','' + ''' + @dbname + ''' + [databases],
        [apps] = '','' + ''' + @AppName + ''' + [apps]
from	#name n, dbo.sysusers su
where	n.[name] = su.[name] COLLATE DATABASE_DEFAULT;';

    EXEC sp_executesql @SQLcmd;


    fetch next from curDatabases into @dbname    
end
close curDatabases
deallocate curDatabases


-- clean application names with unique values only
declare curResult cursor for
    SELECT [apps] FROM #name
open curResult
fetch next from curResult into @apps
while (@@fetch_status >= 0)
begin
    SET @apps2 = '';
    SELECT @apps2 = @apps2 + COALESCE(',' + [AppName], '') 
    FROM (
        SELECT DISTINCT ReturnCol AS [AppName]
        FROM [db_dba].[dbo].[fn_split] (@apps, ',')
    ) a
    WHERE LEN([AppName]) > 0
    ORDER BY [AppName] ASC;
    
    UPDATE #name SET [apps] = @apps2
    WHERE CURRENT OF curResult;

    SET @apps = '';
    SET @apps2 = '';

    fetch next from curResult into @apps
end
close curResult
deallocate curResult


-- remove leading comma from database names and application names
UPDATE #name
SET [databases] = SUBSTRING([databases], 2, LEN([databases])),
    [apps] = SUBSTRING([apps], 2, LEN([apps]));


-- return the result
select	[name] AS [Login Name],
        [databases] AS [Access to Databases],
        [apps] AS [Application Name/s],
        [null],
		[same],
		[reverse],
		[onechar]
from	#name
where	[weak] = 1
order by
		[name];

-- clean up
drop table #name;
