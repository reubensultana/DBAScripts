/* Source: https://github.com/reubensultana/DBAScripts/blob/master/System/ConfigureMemory.sql */

USE [master]
GO
SET NOCOUNT ON;

/*
NOTE: Based on the formula from https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/server-memory-server-configuration-options
*/

DECLARE @NumberofInstances int;
SET @NumberofInstances = 1;             -- set this to the number of instances the server will host

DECLARE @EngineEdition nvarchar(128);
SET @EngineEdition = CAST(SERVERPROPERTY('Edition') AS nvarchar(128));

CREATE TABLE #msver (
	[Index] int,
	[Name] nvarchar(128),
	[Internal_Value] sql_variant,
	[Character_Value] nvarchar(4000)
);

-- populate the temporary tables to be used later
INSERT INTO #msver EXEC xp_msver;

DECLARE @PhysicalMemoryAvailable int;
DECLARE @OSReservedMemory int;
DECLARE @MinServerMemory int;
DECLARE @MaxServerMemory int;

-- get values for Physical Memory available to the server
SET @PhysicalMemoryAvailable = (SELECT CAST([Internal_Value] AS int) FROM #msver WHERE [Name] = N'PhysicalMemory');

-- Reserve 1 GB of RAM for the OS, 
SET @OSReservedMemory = 1024;

-- 1 GB for each 4 GB of RAM installed from 4–16 GB, 
IF (@PhysicalMemoryAvailable BETWEEN 4096 AND 16384)
    SET @OSReservedMemory = @OSReservedMemory + (1024 * ((@PhysicalMemoryAvailable - 4096) / 4096))

-- and then 1 GB for every 8 GB RAM installed above 16 GB RAM.
IF (@PhysicalMemoryAvailable > 16384)
BEGIN
    SET @OSReservedMemory = @OSReservedMemory + (1024 * ((@PhysicalMemoryAvailable -  4096) / 4096))
    SET @OSReservedMemory = @OSReservedMemory + (1024 * ((@PhysicalMemoryAvailable - 16384) / 8192))
END

-- check Engine Edition
IF (@EngineEdition LIKE 'Express%')
    -- For Express Editions the @MaxServerMemory that can be allocated is 1024
    SET @MaxServerMemory = 1024;
ELSE
    SET @MaxServerMemory = FLOOR((((@PhysicalMemoryAvailable - @OSReservedMemory) / @NumberofInstances) / 1024)) * 1024;;

-- set the minumum to half the maximum allocation
SET @MinServerMemory = CASE WHEN @MaxServerMemory > 1024 THEN FLOOR(((@MaxServerMemory / 2) / 1024)) * 1024 ELSE 512 END;

-- check current and set parameter values
IF @MinServerMemory <> (
    SELECT CAST(value_in_use AS int) FROM sys.configurations 
    WHERE [name] = 'min server memory (MB)')
BEGIN
    EXEC sys.sp_configure 'min server memory', @MinServerMemory;
    RECONFIGURE WITH OVERRIDE;
END

IF @MaxServerMemory <> (
    SELECT CAST(value_in_use AS int) FROM sys.configurations 
    WHERE [name] = 'max server memory (MB)')
BEGIN
    EXEC sys.sp_configure 'max server memory (MB)', @MaxServerMemory;
    RECONFIGURE WITH OVERRIDE;
END

DROP TABLE #msver
GO
