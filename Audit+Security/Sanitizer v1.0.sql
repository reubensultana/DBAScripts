USE [master]
GO

IF OBJECT_ID('[dbo].[sp_DataSanitization]') IS NULL
    EXEC sp_executesql N'CREATE PROCEDURE [dbo].[sp_DataSanitization] AS SELECT CURRENT_TIMESTAMP;';
GO

ALTER PROCEDURE [dbo].[sp_DataSanitization]
    @TableName nvarchar(128),
    @PKColumn nvarchar(128),
    @ColumnName nvarchar(128),
    @DebugMode bit = 0,
    @Execute bit = 0
AS
/*
--------------------------------------------------------------------------------------
-- MIT License
-- 
-- Copyright (c) 2018 Reuben Sultana
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
----------------------------------------------------------------------------
-- Object Name:             N/A
-- Project:                 N/A
-- Business Process:        Dynamic Data Shuffling
-- Purpose:                 Used to anonymize data for security purposes and as required by various certification bodies (e.g. ISO27001)
-- Detailed Description:    *** USE WITH CAUTION!! THIS WILL CHANGE THE DATA. REVERTING CAN ONLY BE POSSIBLE FROM A RECENT VALID BACKUP ***
--                          Creates "buckets" of unique identifiers and occurances of each, then processes each "bucket" to update data in the 
--                          specified column ensuring that:
--                              a) different records are updated to use the current bucket value, and 
--                              b) once the process is complete the table will contain the same number of occurances of each item.
-- Database:                master - This will allow for the stored procedure to be called from any database - USE WITH CAUTION!!
-- Dependent Objects:       User-defined - Ensure that the correct table and column names are entered.
-- Called By:               Account authorised to read and modify data in the specified table columns.
--
--------------------------------------------------------------------------------------
-- Rev   | CMR      | Date Modified  | Developer             | Change Summary
--------------------------------------------------------------------------------------
--   0.1 |          | 23/08/2016     | Reuben Sultana        | First implementation
--   1.0 |          | 10/05/2018     | Reuben Sultana        | Rewrote as a stored procedure
--   1.1 |          | 19/06/2018     | Reuben Sultana        | Added license; Exclude NULL values from Bucket List and Updates
--       |          |                |                       |
--
*/
BEGIN
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    SET NOCOUNT ON;

    -- start sanitization
    DECLARE @sqlcmd nvarchar(4000);
    DECLARE @ParmDefinition nvarchar(500);
    DECLARE @DatabaseName nvarchar(128);

    DECLARE @BucketsValue sql_variant,
            @BucketCount int;

    DECLARE @TotalRecords int;
    DECLARE @AffectedRecords int;
    DECLARE @RunningTotal int;
    
    -- set data types dynamically - covers: character, integer, numeric and datetime types
    DECLARE @PKColumnType nvarchar(128);
    DECLARE @ColumnType nvarchar(128);

    DECLARE @ExitLoop bit;
    SET @ExitLoop = 0;

    DECLARE @IterationNumber int;
    DECLARE @IterationsTotal int;

    SET @DatabaseName = QUOTENAME(DB_NAME(), N'[');

    PRINT '--------------------------------------------------';
    IF @DebugMode = 1 PRINT N'Script parameters used:'
    IF @DebugMode = 1 PRINT N'@DebugMode:       ' + CAST(@DebugMode AS nvarchar(10));
    IF @DebugMode = 1 PRINT N'@Execute:         ' + CAST(@Execute AS nvarchar(10));
    IF @DebugMode = 1 PRINT N'@DatabaseName:    ' + @DatabaseName;
/*
    SET @PKColumnType = (
        SELECT ifc.DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS ifc
        WHERE (QUOTENAME(ifc.TABLE_SCHEMA, '[') + N'.' + QUOTENAME(ifc.TABLE_NAME, '[')) = @TableName
        AND QUOTENAME(ifc.COLUMN_NAME, '[') = @PKColumn
        AND (ifc.DATA_TYPE IN (
            'tinyint', 'smallint', 'int', 'bigint')
        )
    );
*/
    SET @sqlcmd = N'
USE ' + @DatabaseName + N';
SET @PKColumnTypeOUT = (
    SELECT ifc.DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS ifc
    WHERE (QUOTENAME(ifc.TABLE_SCHEMA, ''['') + N''.'' + QUOTENAME(ifc.TABLE_NAME, ''['')) = @TableNameIN
    AND QUOTENAME(ifc.COLUMN_NAME, ''['') = @PKColumnIN
    AND (ifc.DATA_TYPE IN (
        ''tinyint'', ''smallint'', ''int'', ''bigint'')
    )
);
';
    SET @ParmDefinition = N'@TableNameIN nvarchar(128), @PKColumnIN nvarchar(128), @PKColumnTypeOUT nvarchar(128) OUTPUT';
    EXECUTE sp_executesql @sqlcmd, @ParmDefinition, @TableNameIN=@TableName, @PKColumnIN=@PKColumn, @PKColumnTypeOUT=@PKColumnType OUTPUT;  
/*
    SET @ColumnType = (
        SELECT ifc.DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS ifc
        WHERE (QUOTENAME(ifc.TABLE_SCHEMA, '[') + N'.' + QUOTENAME(ifc.TABLE_NAME, '[')) = @TableName
        AND QUOTENAME(ifc.COLUMN_NAME, '[') = @ColumnName
        AND (ifc.DATA_TYPE IN (
            'date', 'time', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime', 
            'varchar', 'char', 'nvarchar', 'nchar',
            'tinyint', 'smallint', 'int', 'bigint',
            'bit', 'decimal', 'numeric', 'smallmoney', 'money', 'float', 'real'
            )
        )
    );
*/
    SET @sqlcmd = N'
USE ' + @DatabaseName + N';
SET @ColumnTypeOUT = (
    SELECT ifc.DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS ifc
    WHERE (QUOTENAME(ifc.TABLE_SCHEMA, ''['') + N''.'' + QUOTENAME(ifc.TABLE_NAME, ''['')) = @TableNameIN
    AND QUOTENAME(ifc.COLUMN_NAME, ''['') = @ColumnNameIN
    AND (ifc.DATA_TYPE IN (
        ''date'', ''time'', ''datetime'', ''datetime2'', ''datetimeoffset'', ''smalldatetime'', 
        ''varchar'', ''char'', ''nvarchar'', ''nchar'',
        ''tinyint'', ''smallint'', ''int'', ''bigint'',
        ''bit'', ''decimal'', ''numeric'', ''smallmoney'', ''money'', ''float'', ''real''
        )
    )
);
';
    SET @ParmDefinition = N'@TableNameIN nvarchar(128), @ColumnNameIN nvarchar(128), @ColumnTypeOUT nvarchar(128) OUTPUT';
    EXECUTE sp_executesql @sqlcmd, @ParmDefinition, @TableNameIN=@TableName, @ColumnNameIN=@ColumnName, @ColumnTypeOUT=@ColumnType OUTPUT;

    -- check...
    IF (@PKColumnType IS NULL)
    BEGIN
        RAISERROR('The PK column data type is not supported.', 16, 1);
        RETURN
    END
    ELSE
    BEGIN
        IF @DebugMode = 1 PRINT N'@PKColumn:        ' + @PKColumn;
        IF @DebugMode = 1 PRINT N'@PKColumnType:    ' + @PKColumnType;
    END
    -- check...
    IF (@ColumnType IS NULL)
    BEGIN
        RAISERROR('The column data type is not supported.', 16, 1);
        RETURN
    END
    ELSE
    BEGIN
        IF @DebugMode = 1 PRINT N'@ColumnName:      ' + @ColumnName;
        IF @DebugMode = 1 PRINT N'@ColumnType:      ' + @ColumnType;
    END
    PRINT '--------------------------------------------------';
    -- looks OK...

    -- add record identifier, using a bit-type column
    SET @sqlcmd = N'USE ' + @DatabaseName + N';ALTER TABLE ' + @TableName + N' ADD [UpdateFlag] bit NULL;';
    IF @DebugMode = 1 PRINT @sqlcmd;
    IF @Execute = 1 EXEC sp_executesql @sqlcmd;

    -- set default values
    SET @sqlcmd = N'USE ' + @DatabaseName + N';UPDATE ' + @TableName + N' SET [UpdateFlag] = 0;';
    IF @DebugMode = 1 PRINT @sqlcmd;
    IF @Execute = 1 EXEC sp_executesql @sqlcmd;

    -- show total number of records to process
    SET @AffectedRecords = @@ROWCOUNT;
    -- Next part is executed only if @Execute=0
    IF @Execute=0
    BEGIN
        SET @sqlcmd = N'
USE ' + @DatabaseName + N';
SET @AffectedRecordsOUT = (SELECT COUNT(*) FROM ' + @TableName + N' WHERE ' + @ColumnName + N' IS NOT NULL);';

        SET @ParmDefinition = N'@AffectedRecordsOUT int OUTPUT';
        IF @DebugMode = 1 PRINT @sqlcmd;
        IF @DebugMode = 1 PRINT @ParmDefinition;
        EXEC sp_executesql @sqlcmd, @ParmDefinition, @AffectedRecordsOUT=@AffectedRecords OUTPUT;
    END
    SET @TotalRecords = @AffectedRecords;
    PRINT 'Table ' + @TableName + ' contains ' + CAST(@AffectedRecords as varchar(10)) + ' records which' + (CASE @Execute WHEN 1 THEN ' will be' ELSE ' would have been' END) + ' affected.';
    PRINT '--------------------------------------------------';

    -- generate "buckets" of data
    SET @sqlcmd = 'USE ' + @DatabaseName + N';
DECLARE BucketList CURSOR FOR
    SELECT CAST(' + @ColumnName + N' AS sql_variant) AS [ColumnName], COUNT(*) AS [RowCount]
    FROM ' + @TableName + N'
    WHERE ' + @ColumnName + N' IS NOT NULL
    GROUP BY ' + @ColumnName + N'
    ORDER BY [RowCount] DESC, [ColumnName] ASC;';
    IF @DebugMode = 1 PRINT @sqlcmd;
    -- this will generate the cursor, but the UPDATE statements will not be executed if @Execute=0
    /*IF @DebugMode = 1*/ EXEC sp_executesql @sqlcmd;

    SET @IterationNumber = 0;
    SET @IterationsTotal = @@CURSOR_ROWS;
    SET @sqlcmd = N'';
    IF @DebugMode = 1 PRINT @sqlcmd;

    OPEN BucketList;
    FETCH NEXT FROM BucketList INTO @BucketsValue, @BucketCount
    WHILE ((@@FETCH_STATUS=0) AND (@ExitLoop = 0))
    BEGIN
        SET @IterationNumber = @IterationNumber + 1;
        -- check that the current Bucket does not contain the majority of table records
        -- i.e. it should contain less than 50% of the total
        IF (@BucketCount >= (@TotalRecords/2))
        BEGIN
            -- throw an error and exit the loop
            SET @ExitLoop = 1;
            RAISERROR('The number of items in this Bucket (%d) is more than half the Total Records (%d).', 16, 1, @BucketCount, @TotalRecords);
            --RETURN;
        END
        ELSE
        BEGIN -- START: Bucket Value < Affected Records
            -- write to console
            PRINT (CASE @Execute WHEN 1 THEN 'W' ELSE 'Potentially w' END) + 'riting ' + CAST(@BucketCount as varchar(10)) + ' value' + CASE WHEN @BucketCount>1 THEN 's' ELSE '' END + ' for "' + 
                CASE WHEN @BucketsValue IS NULL THEN N'NULL'
                     WHEN @ColumnType IN ('date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime', 'time') THEN CONVERT(varchar(50), @BucketsValue, 126)
                     WHEN @ColumnType IN ('bit', 'decimal', 'numeric', 'smallmoney', 'money', 'float', 'real') THEN CONVERT(varchar(50), @BucketsValue, 2)
                     ELSE CONVERT(nvarchar(MAX), @BucketsValue) -- 'varchar', 'char', 'nvarchar', 'nchar'
                END + '"';
        
            SET @sqlcmd = 'USE ' + @DatabaseName + N';
UPDATE ' + @TableName + N'
SET ' + @ColumnName + 
            -- append value of @BucketsValue according to data type (1/3)
            CASE WHEN @BucketsValue IS NULL THEN N' = NULL'
                 WHEN @ColumnType IN ('date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime', 'time') THEN N' = ''' + CONVERT(varchar(50), @BucketsValue, 126) + N''''
                 WHEN @ColumnType IN ('bit', 'decimal', 'numeric', 'smallmoney', 'money', 'float', 'real') THEN N' = ' + CONVERT(varchar(50), @BucketsValue, 2) + N''
                 ELSE N' = N''' + REPLACE(CONVERT(nvarchar(MAX), @BucketsValue), '''', '''''') + N'''' -- 'varchar', 'char', 'nvarchar', 'nchar'
            END + ', [UpdateFlag] = 1
WHERE ' + @PKColumn + N' IN (
    SELECT TOP(' + CAST(@BucketCount AS nvarchar(10)) + N') ' + @PKColumn + N' 
    FROM ' + @TableName + N'
    WHERE ([UpdateFlag] = 0) 
    AND ' + @ColumnName + N' IS NOT NULL ' + 
            -- check if the current iteration is the last one
            CASE WHEN (@IterationNumber < @IterationsTotal) THEN '
    AND (' + @ColumnName + 
                -- append value of @BucketsValue according to data type (2/3)
                CASE WHEN @BucketsValue IS NULL THEN N' IS NOT NULL'
                     WHEN @ColumnType IN ('date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime', 'time') THEN N' <> ''' + CONVERT(varchar(50), @BucketsValue, 126) + N''''
                     WHEN @ColumnType IN ('bit', 'decimal', 'numeric', 'smallmoney', 'money', 'float', 'real') THEN N' <> ' + CONVERT(varchar(50), @BucketsValue, 2) + N''
                     ELSE N' <> N''' + REPLACE(CONVERT(nvarchar(MAX), @BucketsValue), '''', '''''') + N'''' -- 'varchar', 'char', 'nvarchar', 'nchar'
                END + N')' 
            ELSE '' END + '
    ORDER BY (1 + ABS(CHECKSUM(NEWID())) % ' + @PKColumn + N')
)
AND ' + @ColumnName + N' IS NOT NULL 
AND ([UpdateFlag] = 0)' + 
            -- check if the current iteration is the last one
            CASE WHEN (@IterationNumber < @IterationsTotal) THEN '
AND (' + @ColumnName +
                -- append value of @BucketsValue according to data type (3/3)
                CASE WHEN @BucketsValue IS NULL THEN N' IS NOT NULL'
                     WHEN @ColumnType IN ('date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime', 'time') THEN N' <> ''' + CONVERT(varchar(50), @BucketsValue, 126) + N''''
                     WHEN @ColumnType IN ('bit', 'decimal', 'numeric', 'smallmoney', 'money', 'float', 'real') THEN N' <> ' + CONVERT(varchar(50), @BucketsValue, 2) + N''
                     ELSE N' <> N''' + REPLACE(CONVERT(nvarchar(MAX), @BucketsValue), '''', '''''') + N'''' -- 'varchar', 'char', 'nvarchar', 'nchar'
                END + N')' 
            ELSE '' END + ';';

            IF @DebugMode = 1 PRINT @sqlcmd;
            IF @Execute = 1 EXEC sp_executesql @sqlcmd;

            SET @AffectedRecords = @@ROWCOUNT;
            -- set the value of @AffectedRecords equal to the @BucketCount for testing purposes
            IF @Execute = 0 SET @AffectedRecords = @BucketCount;
            PRINT CAST(@AffectedRecords AS varchar(10)) + ' record' + CASE WHEN @AffectedRecords>1 THEN 's' ELSE '' END + (CASE @Execute WHEN 1 THEN '' ELSE ' would' END) + ' have been affected';

            -- stop the process if something is wrong
            -- NOTE: NULL values are excluded from the checks
            IF ((@BucketsValue IS NOT NULL) AND (@AffectedRecords <> @BucketCount))
            BEGIN
                -- throw an error and exit the loop
                SET @ExitLoop = 1;
                RAISERROR('The number of Records Affected (%d) by this iteration does not match the current Bucket Count (%d).', 16, 1, @AffectedRecords, @BucketCount);
                --RETURN;
            END
            ELSE
                SET @RunningTotal = @RunningTotal + @AffectedRecords;
        
        END -- END: Bucket Value < Affected Records
        
        SET @sqlcmd = N'';
        IF @DebugMode = 1 PRINT @sqlcmd;

        FETCH NEXT FROM BucketList INTO @BucketsValue, @BucketCount
    END
    CLOSE BucketList;
    DEALLOCATE BucketList;

    -- remove record identifier
    SET @sqlcmd = N'USE ' + @DatabaseName + N';ALTER TABLE ' + @TableName + N' DROP COLUMN [UpdateFlag];';
    IF @DebugMode = 1 PRINT @sqlcmd;
    IF @Execute = 1 EXEC sp_executesql @sqlcmd;

    PRINT '--------------------------------------------------';
    PRINT 'A total of ' + CAST(@RunningTotal as varchar(10)) + ' records' + (CASE @Execute WHEN 1 THEN '' ELSE ' would' END) + ' have been processed for table ' + @TableName + '.';
    -- end sanitization
END
GO


USE [master]
GO

/* ********** TESTING ********** */
-- NOTE: Qualify object name values in square brackets
/*
USE [AdventureWorks2014]
GO
EXEC [dbo].[sp_DataSanitization] 
    @TableName  = '[Person].[Person]',
    @PKColumn   = '[BusinessEntityID]',
    @ColumnName = '[FirstName]',
    @DebugMode  = 1,
    @Execute    = 1;
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[Person].[Person]',
    @PKColumn   = '[BusinessEntityID]',
    @ColumnName = '[LastName]',
    @DebugMode  = 1,
    @Execute    = 1;
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[Person].[Person]',
    @PKColumn   = '[BusinessEntityID]',
    @ColumnName = '[ModifiedDate]';
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[Person].[EmailAddress]',
    @PKColumn   = '[EmailAddressID]',
    @ColumnName = '[EmailAddress]';
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[HumanResources].[Employee]',
    @PKColumn   = '[BusinessEntityID]',
    @ColumnName = '[BirthDate]';
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[HumanResources].[Employee]',
    @PKColumn   = '[BusinessEntityID]',
    @ColumnName = '[VacationHours]';
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[HumanResources].[Employee]',
    @PKColumn   = '[BusinessEntityID]',
    @ColumnName = '[MaritalStatus]';
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[Sales].[CurrencyRate]',
    @PKColumn   = '[CurrencyRateID]',
    @ColumnName = '[EndOfDayRate]';
GO

-----
USE [AdventureWorks2014];
ALTER INDEX [AK_CreditCard_CardNumber] ON [Sales].[CreditCard] DISABLE;
USE [master];
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[Sales].[CreditCard]',
    @PKColumn   = '[CreditCardID]',
    @ColumnName = '[CardNumber]';
GO

USE [AdventureWorks2014];
ALTER INDEX [AK_CreditCard_CardNumber] ON [Sales].[CreditCard] REBUILD;
USE [master];
GO
-----

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '[Sales].[CreditCard]',
    @PKColumn   = '[CreditCardID]',
    @ColumnName = '[ExpYear]',
    @DebugMode  = 1;
GO

EXEC [AdventureWorks2014].[dbo].[sp_DataSanitization] 
    @TableName  = '',
    @PKColumn   = '',
    @ColumnName = '';
GO

*/
