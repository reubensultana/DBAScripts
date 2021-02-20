use master
GO

set nocount on
set quoted_identifier off

declare @sql varchar(8000);

create table #UserGroup (
    UserName sysname NULL,
    GroupName sysname NULL,
    LoginName sysname NULL,
    DefDBName sysname NULL,
--    DefSchemaName sysname NULL, -- uncomment for SQL Server 2005
    UID smallint,
    SID varbinary(85) );

create table #MissingUser (
    DBName sysname NULL,
    UserName sysname NULL,
    GroupName sysname NULL );

set @sql = "
insert into #UserGroup
    exec [?]..sp_helpuser;

insert into #MissingUser
    select '?', UserName, GroupName
    from #UserGroup
    where UserName not in ('dbo', 'guest')
    and LoginName is null;

truncate table #UserGroup;";

exec sp_msforeachdb @sql;

select --*
    DISTINCT 'EXEC ' + QUOTENAME(dbname, '[') + '..sp_revokedbaccess ''' + UserName + ''';'
from #MissingUser
where UserName not in ('INFORMATION_SCHEMA', 'sys');

drop table #UserGroup;
drop table #MissingUser;