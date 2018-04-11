SET NOCOUNT ON;

DECLARE @SourceSQLServer nvarchar(128);
DECLARE @DestinationSQLServer nvarchar(128);
DECLARE @BCPParams varchar(500);
DECLARE @CurrentDB nvarchar(128);
DECLARE @BulkLoadPath nvarchar(128);
DECLARE @rowterminator nvarchar(10);
DECLARE @colterminator nvarchar(10);
DECLARE @BCPorBULK bit;
DECLARE @CheckData bit;
DECLARE @ExcludedTables TABLE (
    table_schema nvarchar(128) COLLATE DATABASE_DEFAULT, 
    table_name nvarchar(128) COLLATE DATABASE_DEFAULT
    );

-- source server
SET @SourceSQLServer = ISNULL(@@SERVERNAME, CAST(SERVERPROPERTY('ServerName') AS nvarchar(128)));
SET @SourceSQLServer = UPPER(@SourceSQLServer);

-- destination server
SET @DestinationSQLServer = 'SQLSERVER\INSTANCE';
SET @BulkLoadPath = 'D:\TEMP\';  -- '

SET @rowterminator = '\n'; -- carriage return
--SET @rowterminator = '/n'; -- custom symbol

SET @colterminator = '|';
--SET @colterminator = '\0'; -- NULL terminator

SET @BCPorBULK = 0; -- 0 = BCP; 1 = BULK INSERT
SET @CheckData = 1; -- 0 = Don't check; 1 = Check

INSERT INTO @ExcludedTables
    SELECT 'dbo', '' UNION ALL
    SELECT 'dbo', '';

-- BCP parameters
/*
  [-m maxerrors]            [-f formatfile]          [-e errfile]
  [-F firstrow]             [-L lastrow]             [-b batchsize]
  [-n native type]          [-c character type]      [-w wide character type]
  [-N keep non-text native] [-V file format version] [-q quoted identifier]
  [-C code page specifier]  [-t field terminator]    [-r row terminator]
  [-i inputfile]            [-o outfile]             [-a packetsize]
  [-S server name]          [-U username]            [-P password]
  [-T trusted connection]   [-v version]             [-R regional enable]
  [-k keep null values]     [-E keep identity values]
  [-h "load hints"]         [-x generate xml format file]
*/
SET @BCPParams = '-t"' + @colterminator + '" -r"' + @colterminator + @rowterminator + '" -c -q -T -S ';

IF (@SourceSQLServer = @DestinationSQLServer)
BEGIN
    RAISERROR('Source and Destination servers are the same. This will result in data corruption if output is executed!', 16, 1);
    RETURN;
END;

-- check database context
SET @CurrentDB = DB_NAME();

IF (@CurrentDB IN ('master', 'model', 'msdb', 'tempdb'))
BEGIN
    RAISERROR('Current database context is "%s". Please select a user database to generate export & import scripts.', 16, 1, @CurrentDB);
    RETURN;
END;

IF (@CheckData = 1)
BEGIN
    -- check if any of the character-type columns contain the seleted delimiter
    PRINT '***** CHECKING DATA FOR INSTANCES OF THE SELECTED COLUMN DELIMITER *****';
    DECLARE @searchstr nvarchar(100);

    CREATE TABLE #Results (
        ColumnName nvarchar(370) COLLATE DATABASE_DEFAULT, 
        ColumnValue nvarchar(3630) COLLATE DATABASE_DEFAULT);

    DECLARE @TableName nvarchar(256), 
            @ColumnName nvarchar(128), 
            @searchstr2 nvarchar(110);

    SET @searchstr = @colterminator;
    SET @TableName = '';
    SET @searchstr2 = QUOTENAME('%' + @searchstr + '%','''');

    WHILE (@TableName IS NOT NULL)
    BEGIN
        SET @ColumnName = '';
        SET @TableName = (
            SELECT  MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
            FROM    INFORMATION_SCHEMA.TABLES
            WHERE     TABLE_TYPE = 'BASE TABLE'
            AND ((TABLE_SCHEMA + '.' + TABLE_NAME) NOT IN (
                SELECT DISTINCT table_schema + '.' + table_name FROM @ExcludedTables))
            AND    QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
            AND    OBJECTPROPERTY(
                    OBJECT_ID(
                        QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)
                            ), 'IsMSShipped'
                                ) = 0
            );

        WHILE ((@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL))
        BEGIN
            SET @ColumnName = (
                SELECT  MIN(QUOTENAME(COLUMN_NAME))
                FROM    INFORMATION_SCHEMA.COLUMNS
                WHERE   TABLE_SCHEMA    = PARSENAME(@TableName, 2)
                AND        TABLE_NAME    = PARSENAME(@TableName, 1)
                AND        DATA_TYPE IN ('char', 'varchar', 'nchar', 'nvarchar')
                AND        QUOTENAME(COLUMN_NAME) > @ColumnName
                );

            IF (@ColumnName IS NOT NULL)
            BEGIN
                INSERT INTO #Results
                EXEC(
                    'SELECT ''' + @TableName + '.' + @ColumnName + ''', LEFT(' + @ColumnName + ', 3630) 
                     FROM ' + @TableName + ' (NOLOCK) ' +
                    'WHERE ' + @ColumnName + ' LIKE ' + @searchstr2
                    )
            END;
        END;    
    END;

    IF EXISTS(SELECT * FROM #Results)
    BEGIN
        PRINT '***** POSSIBLE DATA ERRORS *****'
        PRINT 'The following records contain the chosen column delimiter and will cause errors performing a data import. 
    Please choose another column delimiter OR update the data to remove the chosen column delimiter to comtinue.';
        PRINT '';
        SELECT ColumnName, ColumnValue FROM #Results;
        DROP TABLE #Results;
        RETURN;
    END
    ELSE
    BEGIN
        PRINT 'Data DOES NOT contain the column delimiter.';
        PRINT '';
        DROP TABLE #Results;
    END;
END;


-- generate code to CREATE FOLDER STRUCTURE
PRINT '';
PRINT '--------------------------------------------------';
PRINT '***** CREATE FOLDER STRUCTURE *****';
PRINT '';
PRINT 'mkdir ' + @BulkLoadPath + DB_NAME();
PRINT 'pushd ' + @BulkLoadPath + DB_NAME();
PRINT 'mkdir .\data';
PRINT 'mkdir .\format';
PRINT 'mkdir .\logs\export';
PRINT 'mkdir .\logs\import';
PRINT '';


-- generate code to CREATE FORMAT FILES
PRINT '';
PRINT '--------------------------------------------------';
PRINT '***** CREATE FORMAT FILES *****';
SELECT 'bcp ' + TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME + ' format nul -f .\format\' + TABLE_NAME +  '.fmt ' +
    @BCPParams + @SourceSQLServer
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND ((TABLE_SCHEMA + '.' + TABLE_NAME) NOT IN (
    SELECT DISTINCT table_schema + '.' + table_name FROM @ExcludedTables));


-- generate EXPORT code
PRINT '';
PRINT '--------------------------------------------------';
PRINT '***** EXPORT CODE *****';
SELECT 'bcp ' + TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME + ' out .\data\' + TABLE_NAME + '.out ' +
    @BCPParams + @SourceSQLServer + ' >> .\logs\export\' + TABLE_NAME + '.log'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND ((TABLE_SCHEMA + '.' + TABLE_NAME) NOT IN (
    SELECT DISTINCT table_schema + '.' + table_name FROM @ExcludedTables));
PRINT '';


-- generate IMPORT code
IF (@BCPorBULK = 0)
BEGIN
    PRINT '';
    PRINT '--------------------------------------------------';
    PRINT '***** IMPORT CODE USING "BCP" *****';
    SELECT 'bcp ' + TABLE_CATALOG + '.' + TABLE_SCHEMA + '.' + TABLE_NAME + ' in .\data\' + TABLE_NAME +  '.out ' +
        @BCPParams + @DestinationSQLServer + ' -E -k -f .\format\' + TABLE_NAME + '.fmt >> .\logs\import\' + TABLE_NAME + '.log'
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
    AND ((TABLE_SCHEMA + '.' + TABLE_NAME) NOT IN (
        SELECT DISTINCT table_schema + '.' + table_name FROM @ExcludedTables));
END
ELSE IF (@BCPorBULK = 1)
BEGIN
    PRINT '';
    PRINT '--------------------------------------------------';
    PRINT '-- ***** IMPORT CODE USING "BULK INSERT" *****';
    PRINT 'USE ' + QUOTENAME(DB_NAME(), '[');
    PRINT 'GO'
    PRINT ''
    PRINT 'ALTER DATABASE ' + QUOTENAME(DB_NAME(), '[') + ' SET RECOVERY BULK_LOGGED';
    PRINT 'GO'
    PRINT ''
    PRINT 'SET NOCOUNT ON;';
    PRINT ''
    PRINT '/*
BATCHSIZE       -- Specifies the number of rows in a batch
FIELDTERMINATOR -- Specifies the field terminator to be used for char and widechar data files
FIRSTROW        -- Specifies the number of the first row to load
DATAFILETYPE    -- char | native | widechar | widenative
FORMATFILE      -- Describes the data file that contains stored responses created by using the bcp utility on the same table or view
KEEPIDENTITY    -- Specifies that identity value or values in the imported data file are to be used for the identity column
KEEPNULLS       -- Specifies that empty columns should retain a null value during the bulk-import operation
MAXERRORS       -- Specifies the maximum number of syntax errors allowed in the data before the bulk-import operation is canceled
ROWS_PER_BATCH  -- Indicates the approximate number of rows of data in the data file
ROWTERMINATOR   -- Specifies the row terminator to be used for char and widechar data files
TABLOCK         -- Specifies that a table-level lock is acquired for the duration of the bulk-import operation
*/';
    SELECT '
PRINT ''Loading ' + CAST(rowcnt AS nvarchar(10)) + ' rows to table [' + TABLE_CATALOG + '].[' + TABLE_SCHEMA + '].[' + TABLE_NAME + ']'';
BULK INSERT [' + TABLE_CATALOG + '].[' + TABLE_SCHEMA + '].[' + TABLE_NAME + '] FROM ''' + @BulkLoadPath + DB_NAME() + '\data\' + TABLE_NAME +  '.out''' + 
    '
WITH ( 
    --BATCHSIZE = 1000,
    FIELDTERMINATOR = ''' + @colterminator + ''',
    FIRSTROW = 1,
    DATAFILETYPE = ''char'', -- char | native | widechar | widenative
    FORMATFILE = ''' + @BulkLoadPath + DB_NAME() + '\format\' + TABLE_NAME + '.fmt''
    KEEPIDENTITY,
    KEEPNULLS,
    MAXERRORS = 1,
    --ROWS_PER_BATCH = ' + CAST(rowcnt AS nvarchar(10)) + ',
    ROWTERMINATOR = ''' + @rowterminator + ''',
    TABLOCK
);
'
    FROM INFORMATION_SCHEMA.TABLES
        JOIN sysindexes si ON OBJECT_ID('[' + TABLE_SCHEMA + '].[' + TABLE_NAME + ']') = si.id
    WHERE TABLE_TYPE = 'BASE TABLE'
    AND ((TABLE_SCHEMA + '.' + TABLE_NAME) NOT IN (
        SELECT DISTINCT table_schema + '.' + table_name FROM @ExcludedTables))
    AND si.indid = 0;
    PRINT ''
    PRINT 'ALTER DATABASE ' + QUOTENAME(DB_NAME(), '[') + ' SET RECOVERY FULL';
    PRINT 'GO'
END
GO