SET NOCOUNT ON;

DECLARE	@startDate smalldatetime, 
        @endDate smalldatetime, 
        @i int;

SELECT @i = 1, 
       @startDate = 'Jan 01, 2007', 
       @endDate = DATEADD(yy, 1, @startDate);

IF EXISTS(SELECT * FROM sysobjects WHERE ID = (OBJECT_ID('dbo.sequence')) AND xtype = 'U') 
    DROP TABLE dbo.sequence;

CREATE TABLE dbo.sequence(
    num int NOT NULL
);

WHILE(@i <= (SELECT DATEDIFF(dd, @startDate, @endDate)))
BEGIN
    INSERT INTO dbo.sequence VALUES(@i);
    SET @i = @i + 1;		
END

SELECT * FROM
  (SELECT DatePart(mm, DATEADD(dd, num, 'Dec 31, 2006')) MonthNum,
          DateName(mm, DATEADD(dd, num, 'Dec 31, 2006')) MonthName,
          DatePart(wk, DATEADD(dd, num, 'Dec 31, 2006')) WeekOfYear,
          DATEPART(dd, DATEADD(dd, num, 'Dec 31, 2006')) YearDay,
          DateName(dw, DATEADD(dd, num, 'Dec 31, 2006')) weekDayName	 
    FROM sequence) sourceTable
PIVOT (
    MIN(YearDay) FOR weekDayName IN (
        Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
    )
) AS pivotTable
ORDER BY MonthNum, WeekOfYear;


/*
set nocount on

declare @selectedyear nchar(4),
        @selectedmonth smallint

set @selectedyear = '2005'
set @selectedmonth = 4

declare @annualdate table ( 
            yeardate datetime, 
            [weekday] smallint,
            [day] smallint,
            [month] smallint )

;with MyCTE(d)
as
(
    select d = convert(datetime,@selectedyear + '0101')
    union all
    select d = d + 1 from MyCTE where d < @selectedyear + '1231'
)
insert into @annualdate
    select d.d, DATEPART(dw, d.d), DAY(d.d), MONTH(d.d)
    from MyCTE d
    order by d.d
option (maxrecursion 366)

--SELECT * FROM @annualdate;
*/
/*
SELECT 
    DATENAME(m, [yeardate]) AS [Month], DAY([yeardate]) AS [Day],
    [1] AS Sunday, [2] AS Monday, [3] AS Tuesday, [4] AS Wednesday, 
    [5] AS Thursday, [6] AS Friday, [7] AS Saturday
FROM 
( 
    SELECT  yeardate, weekday, [day], [month]
    FROM    @annualdate
    WHERE   month(yeardate) = @selectedmonth
) p
PIVOT
( COUNT([weekday]) FOR [weekday] IN
    ( [1], [2], [3], [4], [5], [6], [7] )
) AS pvt
ORDER BY [month], [day];
*/
/*
declare @monthcalendar table (
    day1 varchar(2),
    day2 varchar(2),
    day3 varchar(2),
    day4 varchar(2),
    day5 varchar(2),
    day6 varchar(2),
    day7 varchar(2) )

insert into @monthcalendar
    SELECT 
        CASE WHEN [1] = 1 THEN DAY([yeardate]) ELSE '' END, 
        CASE WHEN [2] = 1 THEN DAY([yeardate]) ELSE '' END, 
        CASE WHEN [3] = 1 THEN DAY([yeardate]) ELSE '' END, 
        CASE WHEN [4] = 1 THEN DAY([yeardate]) ELSE '' END, 
        CASE WHEN [5] = 1 THEN DAY([yeardate]) ELSE '' END, 
        CASE WHEN [6] = 1 THEN DAY([yeardate]) ELSE '' END, 
        CASE WHEN [7] = 1 THEN DAY([yeardate]) ELSE '' END
    FROM 
    ( 
        SELECT  yeardate, weekday, [day], [month]
        FROM    @annualdate
        WHERE   month(yeardate) = @selectedmonth
    ) p
    PIVOT
    ( COUNT([weekday]) FOR [weekday] IN
        ( [1], [2], [3], [4], [5], [6], [7] )
    ) AS pvt
    ORDER BY [month], [day];    


select * from @monthcalendar
*/
/*

;with MyCTE(d)
as
(
    select d = convert(datetime,'20060101')
    union all
    select d = d + 1 from MyCTE where d < '20061231'
)
select [day] = d.d, [day of week] = DATENAME(dw, d.d)
from MyCTE d
order by d.d
option (maxrecursion 366)

*/
