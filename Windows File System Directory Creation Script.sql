/*
Brief Code Overview

The core functionality in this script is based on two extended system stored procedures:  
master.sys.xp_dirtree and master.sys.xp_create_subdir.  Let's take a look at each, individually:

    * master.sys.xp_dirtree - This extended stored procedure returns all the folders within the folder 
      that is passed into it as a parameter.  It also returns the nested level of each folder found.  By 
      inserting the values returned from xp_dirtree into the temp table you can then query against it to 
      test the existence of the folder you are attempting to create.
    * master.sys.xp_create_subdir - Use this stored procedure to create a folder on either a local 
      server or network share.

*/

USE Master;
GO

SET NOCOUNT ON

-- 1 - Variable declaration
DECLARE @DBName sysname
DECLARE @DataPath nvarchar(500)
DECLARE @LogPath nvarchar(500)
DECLARE @DirTree TABLE (subdirectory nvarchar(255), depth INT)

-- 2 - Initialize variables
SET @DBName = 'Foo'
SET @DataPath = 'C:\zTest1\' + @DBName
SET @LogPath = 'C:\zTest2\' + @DBName

-- 3 - @DataPath values
INSERT INTO @DirTree(subdirectory, depth)
EXEC master.sys.xp_dirtree @DataPath

-- 4 - Create the @DataPath directory
IF NOT EXISTS (SELECT 1 FROM @DirTree WHERE subdirectory = @DBName)
EXEC master.dbo.xp_create_subdir @DataPath

-- 5 - Remove all records from @DirTree
DELETE FROM @DirTree

-- 6 - @LogPath values
INSERT INTO @DirTree(subdirectory, depth)
EXEC master.sys.xp_dirtree @LogPath

-- 7 - Create the @LogPath directory
IF NOT EXISTS (SELECT 1 FROM @DirTree WHERE subdirectory = @DBName)
EXEC master.dbo.xp_create_subdir @LogPath

SET NOCOUNT OFF

GO