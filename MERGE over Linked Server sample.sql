USE [master]
GO

CREATE DATABASE [Sample];
GO

CREATE LOGIN [SampleTest001] WITH PASSWORD='P@ssw0rd', CHECK_POLICY=OFF, CHECK_EXPIRATION=OFF, DEFAULT_DATABASE=[Sample];
GO

EXEC sp_addlinkedserver 
    @server = N'localhost', 
    @srvproduct=N'SQL Server';
GO

EXEC sp_addlinkedsrvlogin 
    @rmtsrvname = N'localhost', 
    @locallogin = NULL , 
    @useself = N'False', 
    @rmtuser = N'SampleTest001', 
    @rmtpassword = N'P@ssw0rd'
GO

EXEC sp_serveroption 
    @server=N'localhost', 
    @optname=N'rpc out', 
    @optvalue=N'true'
GO


USE [Sample]
GO

CREATE USER [SampleTest001] FOR LOGIN [SampleTest001]
GO

CREATE TABLE dbo.SourceTable (
    ID INT IDENTITY(1,1) NOT NULL,
    [Name] varchar(10) NOT NULL,
    [Date] datetime not NULL DEFAULT CURRENT_TIMESTAMP
);
GO

CREATE TABLE dbo.DestinationTable (
    ID INT IDENTITY(1,1) NOT NULL,
    [Name] varchar(10) NOT NULL,
    [Date] datetime not NULL DEFAULT CURRENT_TIMESTAMP
);
GO

GRANT SELECT, INSERT, UPDATE, DELETE TO [SampleTest001]
GO


-- sample data
INSERT INTO dbo.SourceTable ([Name], [Date])
VALUES  ('Name001', '2009-01-15'),
        ('Name002', '2010-02-16'),
        ('Name003', '2011-03-17'),
        ('Name004', '2012-04-18'),
        ('Name005', '2013-05-19')
GO

INSERT INTO dbo.DestinationTable ([Name], [Date])
VALUES  ('BadName001', '1999-12-28')
GO

-- check
SELECT * FROM dbo.SourceTable;
SELECT * FROM dbo.DestinationTable
GO



-- test 1
MERGE INTO dbo.DestinationTable AS Target
USING (SELECT [ID], [Name], [Date] FROM dbo.SourceTable) 
    AS Source ([ID], [NewName], [NewDate])
ON Target.[ID] = Source.[ID]
WHEN MATCHED THEN
	UPDATE SET [Name] = Source.[NewName], [Date] = Source.[NewDate]
WHEN NOT MATCHED BY TARGET THEN
	INSERT ([Name], [Date]) VALUES ([NewName], [NewDate]);
GO

-- verify test 1
SELECT * FROM dbo.SourceTable;
SELECT * FROM dbo.DestinationTable;
-- verify linked server
SELECT * FROM [localhost].[Sample].dbo.DestinationTable;
GO



-- clear table
TRUNCATE TABLE dbo.DestinationTable;
GO

-- sample data
INSERT INTO dbo.DestinationTable ([Name], [Date])
VALUES  ('BadName001', '1999-12-28')
GO

-- test 2
MERGE INTO [localhost].[Sample].dbo.DestinationTable AS Target
USING (SELECT [ID], [Name], [Date] FROM dbo.SourceTable) 
    AS Source ([ID], [NewName], [NewDate])
ON Target.[ID] = Source.[ID]
WHEN MATCHED THEN
	UPDATE SET [Name] = Source.[NewName], [Date] = Source.[NewDate]
WHEN NOT MATCHED BY TARGET THEN
	INSERT ([Name], [Date]) VALUES ([NewName], [NewDate]);
GO
/*
Msg 5315, Level 16, State 1, Line 1
The target of a MERGE statement cannot be a remote table, a remote view, or a view over remote tables.
*/



-- clear table
TRUNCATE TABLE dbo.DestinationTable;
GO

-- sample data
INSERT INTO dbo.DestinationTable ([Name], [Date])
VALUES  ('BadName001', '1999-12-28')
GO

-- procedure to PULL data
CREATE PROCEDURE dbo.usp_MergeData
AS
SET NOCOUNT ON;

MERGE INTO dbo.DestinationTable AS Target
USING (SELECT [ID], [Name], [Date] FROM [localhost].[Sample].dbo.SourceTable) 
    AS Source ([ID], [NewName], [NewDate])
ON Target.[ID] = Source.[ID]
WHEN MATCHED THEN
	UPDATE SET [Name] = Source.[NewName], [Date] = Source.[NewDate]
WHEN NOT MATCHED BY TARGET THEN
	INSERT ([Name], [Date]) VALUES ([NewName], [NewDate]);
GO

GRANT EXECUTE ON dbo.usp_MergeData TO [SampleTest001]
GO

-- test 3
EXEC [localhost].[Sample].dbo.usp_MergeData
GO

-- verify test 3
SELECT * FROM dbo.SourceTable;
SELECT * FROM dbo.DestinationTable;
GO



-- clean-up
/*
USE [master]
GO

DROP DATABASE [Sample];
GO

DROP LOGIN [SampleTest001]
GO

EXEC master.dbo.sp_dropserver @server=N'localhost', @droplogins='droplogins'
GO
*/
